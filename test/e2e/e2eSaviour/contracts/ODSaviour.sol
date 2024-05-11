// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {AccessControl} from '@openzeppelin/access/AccessControl.sol';
import {IERC20} from '@openzeppelin/token/ERC20/ERC20.sol';

import {ISAFEEngine} from '@contracts/SAFEEngine.sol';
import {ODSafeManager, IODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {ICollateralJoinFactory} from '@interfaces/factories/ICollateralJoinFactory.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {Math} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

import {IODSaviour} from '@test/e2e/e2eSaviour/interfaces/IODSaviour.sol';

/**
 * @notice Steps to save a safe using ODSaviour:
 *
 * 1. Protocol DAO => connect [this] saviour `LiquidationEngine.connectSAFESaviour`
 * 2. Treasury DAO => enable specific vaults `ODSaviour.setVaultStatus`
 * 3. Treasury DAO => approve `ERC20.approveTransferFrom` to the saviour
 * 4. Vault owner => protect thier safe with elected saviour `LiquidationEngine.protectSAFE` (only works if ARB DAO enable vaultId)
 * 5. Safe in liquidation => auto call `LiquidationEngine.attemptSave` gets saviour from chosenSAFESaviour mapping
 * 6. Saviour => increases collateral `ODSaviour.saveSAFE`
 */
contract ODSaviour is AccessControl, IODSaviour {
  using Math for uint256;
  using Assertions for address;

  // solhint-disable-next-line modifier-name-mixedcase
  bytes32 public constant SAVIOUR_TREASURY = keccak256(abi.encode('SAVIOUR_TREASURY'));
  bytes32 public constant PROTOCOL = keccak256(abi.encode('PROTOCOL'));

  uint256 public liquidatorReward;

  address public saviourTreasury;
  address public protocolGovernor;
  address public liquidationEngine;

  IVault721 public vault721;
  IOracleRelayer public oracleRelayer;
  IODSafeManager public safeManager;
  ISAFEEngine public safeEngine;
  ICollateralJoinFactory public collateralJoinFactory;

  mapping(uint256 _vaultId => bool _enabled) private _enabledVaults;
  mapping(bytes32 _cType => IERC20 _tokenAddress) private _saviourTokenAddresses;

  /**
   * @param _init The SaviourInit struct;
   */
  constructor(SaviourInit memory _init) {
    saviourTreasury = _init.saviourTreasury.assertNonNull();
    protocolGovernor = _init.protocolGovernor.assertNonNull();
    vault721 = IVault721(_init.vault721.assertNonNull());
    oracleRelayer = IOracleRelayer(_init.oracleRelayer.assertNonNull());
    safeManager = IODSafeManager(address(vault721.safeManager()));
    liquidationEngine = ODSafeManager(address(safeManager)).liquidationEngine(); // todo update @opendollar package to include `liquidationEngine` - PR #693
    collateralJoinFactory = ICollateralJoinFactory(_init.collateralJoinFactory.assertNonNull());
    safeEngine = ISAFEEngine(address(safeManager.safeEngine()));
    liquidatorReward = _init.liquidatorReward;

    if (_init.saviourTokens.length != _init.cTypes.length) revert LengthMismatch();

    // solhint-disable-next-line  defi-wonderland/non-state-vars-leading-underscore
    for (uint256 i; i < _init.cTypes.length; i++) {
      _saviourTokenAddresses[_init.cTypes[i]] = IERC20(_init.saviourTokens[i].assertNonNull());
    }
    _setupRole(SAVIOUR_TREASURY, saviourTreasury);
    _setupRole(PROTOCOL, protocolGovernor);
    _setupRole(PROTOCOL, liquidationEngine);
  }

  function isEnabled(uint256 _vaultId) external view returns (bool _enabled) {
    _enabled = _enabledVaults[_vaultId];
  }

  function addCType(bytes32 _cType, address _tokenAddress) external onlyRole(SAVIOUR_TREASURY) {
    _saviourTokenAddresses[_cType] = IERC20(_tokenAddress);
    emit CollateralTypeAdded(_cType, _tokenAddress);
  }

  function cType(bytes32 _cType) public view returns (address _tokenAddress) {
    return address(_saviourTokenAddresses[_cType]);
  }

  function setLiquidatorReward(uint256 _newReward) external onlyRole(PROTOCOL) {
    liquidatorReward = _newReward;
    emit LiquidatorRewardSet(_newReward);
  }

  /**
   * @dev
   */
  function setVaultStatus(uint256 _vaultId, bool _enabled) external onlyRole(SAVIOUR_TREASURY) {
    _enabledVaults[_vaultId] = _enabled;

    emit VaultStatusSet(_vaultId, _enabled);
  }

  /**
   * todo increase collateral to sufficient level
   * 1. find out how much collateral is required to effectively save the safe
   * 2. transfer the collateral to the vault, so the liquidation math will result in null liquidation
   * 3. write tests
   */
  function saveSAFE(
    address _liquidator,
    bytes32 _cType,
    address _safe
  ) external onlyRole(PROTOCOL) returns (bool _ok, uint256 _collateralAdded, uint256 _liquidatorReward) {
    if (liquidationEngine != _liquidator) revert OnlyLiquidationEngine();
    uint256 _vaultId = safeManager.safeHandlerToSafeId(_safe);
    if (_vaultId == 0) {
      _collateralAdded = type(uint256).max;
      _liquidatorReward = type(uint256).max;
      _ok = true;
      return (_ok, _collateralAdded, _liquidatorReward);
    }
    if (!_enabledVaults[_vaultId]) revert VaultNotAllowed(_vaultId);

    IOracleRelayer.OracleRelayerCollateralParams memory _oracleParams = oracleRelayer.cParams(_cType);
    IDelayedOracle _oracle = _oracleParams.oracle;

    uint256 _reqCollateral;
    {
      (uint256 _currCollateral, uint256 _currDebt) = getCurrentCollateralAndDebt(_cType, _safe);
      uint256 _accumulatedRate = safeEngine.cData(_cType).accumulatedRate;

      uint256 _currCRatio = ((_currCollateral.wmul(_oracle.read())).wdiv(_currDebt.wmul(_accumulatedRate)));
      uint256 _safetyCRatio = _oracleParams.safetyCRatio / 1e18;

      if (_safetyCRatio > _currCRatio) {
        uint256 _diffCRatio = _safetyCRatio.wdiv(_currCRatio);
        _reqCollateral = (_currCollateral.wmul(_diffCRatio)) - _currCollateral;
      } else {
        revert SafetyRatioMet();
      }
    }

    // transferFrom ARB Treasury amount of _reqCollateral
    _saviourTokenAddresses[_cType].transferFrom(saviourTreasury, address(this), _reqCollateral);

    if (_saviourTokenAddresses[_cType].balanceOf(address(this)) >= _reqCollateral) {
      address _collateralJoin = collateralJoinFactory.collateralJoins(_cType);
      ICollateralJoin(_collateralJoin).join(_safe, _reqCollateral);
      _collateralAdded = _reqCollateral;
      _liquidatorReward = liquidatorReward;

      emit SafeSaved(_vaultId, _reqCollateral);
      _ok = true;
    } else {
      _ok = false;
      revert CollateralTransferFailed();
    }
  }

  function getCurrentCollateralAndDebt(
    bytes32 _cType,
    address _safe
  ) public view returns (uint256 _currCollateral, uint256 _currDebt) {
    ISAFEEngine.SAFE memory _safeEngineData = safeEngine.safes(_cType, _safe);
    _currCollateral = _safeEngineData.lockedCollateral;
    _currDebt = _safeEngineData.generatedDebt;
  }
}

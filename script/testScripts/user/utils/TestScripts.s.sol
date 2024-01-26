  // SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Deployment} from '@script/testScripts/user/utils/Deployment.s.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {Math, WAD, RAY, RAD} from '@libraries/Math.sol';

// TODO update these scritps to work with the NFT-mods / new contracts

contract TestScripts is Deployment {
  using Math for uint256;
  /**
   * @dev this function calls the proxyFactory directly,
   * therefore it bypasses the proxyRegistry and proxy address
   * will not be saved in the proxyRegistry mapping
   */
  function deploy() public returns (address payable) {
    return vault721.build();
  }

  /**
   * @dev this function calls the proxyFactory via ProxyRegistry,
   * and it will only allow 1 proxy per wallet/EOA.
   * use the `deployProxy` script to bypass the ProxyRegistry
   */
  function deployOrFind(address owner) public returns (address payable) {
    address proxy = vault721.getProxy(owner);
    if (proxy == address(0)) {
      return vault721.build(owner);
    } else {
      return payable(address(proxy));
    }
  }

  /**
   * @dev open new saf
   */
  function openSafe(bytes32 _cType, address _proxy) public returns (uint256 _safeId) {
    _labelAddresses(_proxy);
    bytes memory payload = abi.encodeWithSelector(basicActions.openSAFE.selector, address(safeManager), _cType, _proxy);
    bytes memory safeData = ODProxy(_proxy).execute(address(basicActions), payload);
    _safeId = abi.decode(safeData, (uint256));
  }

  /**
   * @dev lock collateral and generate debt
   * deltaWad can be set to zero to only lock collateral and generate zero debt
   */
  function depositCollatAndGenDebt(
    bytes32 _cType,
    uint256 _safeId,
    uint256 _collatAmount,
    uint256 _deltaWad,
    address _proxy
  ) public {
    _labelAddresses(_cType, _proxy);
    bytes memory payload = abi.encodeWithSelector(
      basicActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(collateralJoin[_cType]),
      address(coinJoin),
      _safeId,
      _collatAmount,
      _deltaWad
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  /**
   * @dev this function has a bug
   * in order to lockCollateral, use the lockCollatAndGenDebt script, with deltaWad (debt to generate) set to zero
   */
  function depositCollat(bytes32 _cType, uint256 _safeId, uint256 _collatAmount, address _proxy) public {
    _labelAddresses(_cType, _proxy);
    bytes memory payload = abi.encodeWithSelector(
      basicActions.lockTokenCollateral.selector,
      address(safeManager),
      address(collateralJoin[_cType]),
      _safeId,
      _collatAmount
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  /**
   * @dev generate debt from safe that has sufficient collateral locked
   */
  function genDebt(uint256 _safeId, uint256 _deltaWad, address _proxy) public {
    _labelAddresses(_proxy);
    bytes memory payload = abi.encodeWithSelector(
      basicActions.generateDebt.selector, address(safeManager), address(coinJoin), _safeId, _deltaWad
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  /// @dev will repay as much debt as can be repaid with user's COIN balance
  function repayDebtAndFreeTokenCollateral(
    bytes32 _cType,
    uint256 _safeId,
    address _user,
    address _proxy,
    uint256 _debtWad
  ) public {
    _labelAddresses(_proxy);
    IODSafeManager.SAFEData memory _safeInfo = safeManager.safeData(_safeId);
    int256 _collateralWad = _getGeneratedDeltaDebt(address(safeEngine), _cType, _safeInfo.safeHandler, _debtWad);
    bytes memory payload = abi.encodeWithSelector(
      basicActions.repayDebtAndFreeTokenCollateral.selector,
      address(safeManager),
      collateralJoin[_cType],
      address(coinJoin),
      _safeId,
      _collateralWad,
      _debtWad
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function _labelAddresses(address _proxy) internal {
    vm.label(address(_proxy), 'ODProxy');
    _labelKnownAddresses();
  }

  function _labelAddresses(bytes32 _cType, address _proxy) internal {
    vm.label(address(collateralJoin[_cType]), 'Collateral Join');
    vm.label(address(_proxy), 'ODProxy');
    _labelKnownAddresses();
  }

  function _labelKnownAddresses() internal {
    vm.label(address(vault721), 'Vault721');
    vm.label(address(basicActions), 'BasicActions');
    vm.label(address(debtBidActions), 'DebtBidActions');
    vm.label(address(surplusBidActions), 'SurplusBidActions');
    vm.label(address(collateralBidActions), 'collateralBidActions');
    vm.label(address(rewardedActions), 'rewardedActions');
    vm.label(address(protocolToken), 'ProtocolToken');
    vm.label(address(systemCoin), 'SystemCoin');
    vm.label(address(taxCollector), 'TaxCollector');
    vm.label(address(safeEngine), 'SAFEEngine');
    vm.label(address(USER2), 'User');
    vm.label(address(safeManager), 'SAFE MANAGER');
    vm.label(address(coinJoin), 'COIN JOIN');
  }

  /**
   * @notice Gets repaid delta debt generated
   * @dev    The rate adjusted debt of the SAFE
   */
    function _getRepaidDeltaDebt(
    address _safeEngine,
    bytes32 _cType,
    address _safeHandler
  ) internal view returns (int256 _deltaDebt) {
    uint256 _rate = ISAFEEngine(_safeEngine).cData(_cType).accumulatedRate;
    uint256 _generatedDebt = ISAFEEngine(_safeEngine).safes(_cType, _safeHandler).generatedDebt;
    uint256 _coinAmount = ISAFEEngine(_safeEngine).coinBalance(_safeHandler);

    // Uses the whole coin balance in the safeEngine to reduce the debt
    _deltaDebt = (_coinAmount / _rate).toInt();
    // Checks the calculated deltaDebt is not higher than safe.generatedDebt (total debt), otherwise uses its value
    _deltaDebt = uint256(_deltaDebt) <= _generatedDebt ? -_deltaDebt : -_generatedDebt.toInt();
  }

  /**
   * @notice Gets repaid debt
   * @dev    The rate adjusted SAFE's debt minus COIN balance available in usr's address
   */
  function _getRepaidDebt(
    address _safeEngine,
    address _usr,
    bytes32 _cType,
    address _safeHandler
  ) internal view returns (uint256 _deltaWad) {
    uint256 _rate = ISAFEEngine(_safeEngine).cData(_cType).accumulatedRate;
    uint256 _generatedDebt = ISAFEEngine(_safeEngine).safes(_cType, _safeHandler).generatedDebt;
    uint256 _coinAmount = ISAFEEngine(_safeEngine).coinBalance(_usr);

    // Uses the whole coin balance in the safeEngine to reduce the debt
    uint256 _rad = _generatedDebt * _rate - _coinAmount;
    // Calculates the equivalent COIN amount
    _deltaWad = _rad / RAY;
    // If the rad precision has some dust, it will need to request for 1 extra wad wei
    _deltaWad = _deltaWad * RAY < _rad ? _deltaWad + 1 : _deltaWad;
  }
  
    function _getGeneratedDeltaDebt(
    address _safeEngine,
    bytes32 _cType,
    address _safeHandler,
    uint256 _deltaWad
  ) internal view returns (int256 _deltaDebt) {
    uint256 _rate = ISAFEEngine(_safeEngine).cData(_cType).accumulatedRate;
    uint256 _coinAmount = ISAFEEngine(_safeEngine).coinBalance(_safeHandler);

    // If there was already enough COIN in the safeEngine balance, just exits it without adding more debt
    if (_coinAmount < _deltaWad * RAY) {
      // Calculates the needed deltaDebt so together with the existing coins in the safeEngine is enough to exit wad amount of COIN tokens
      _deltaDebt = ((_deltaWad * RAY - _coinAmount) / _rate).toInt();
      // This is neeeded due lack of precision. It might need to sum an extra deltaDebt wei (for the given COIN wad amount)
      _deltaDebt = uint256(_deltaDebt) * _rate < _deltaWad * RAY ? _deltaDebt + 1 : _deltaDebt;
    }
  }
}

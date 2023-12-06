// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';
import {ITaxCollector} from '@interfaces/ITaxCollector.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IBasicActions} from '@interfaces/proxies/actions/IBasicActions.sol';

import {Math, WAD, RAY, RAD} from '@libraries/Math.sol';

import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';

contract FakeBasicActions {
  using Math for uint256;

  function lockTokenCollateralAndGenerateDebt(
    address _manager,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safeId,
    uint256 _collateralAmount,
    uint256 _deltaWad
  ) public {
    address _safeEngine = ODSafeManager(_manager).safeEngine();
    ODSafeManager.SAFEData memory _safeInfo = ODSafeManager(_manager).safeData(_safeId);

    // Takes token amount from user's wallet and joins into the safeEngine
    _joinCollateral(_collateralJoin, _safeInfo.safeHandler, _collateralAmount);

    // Locks token amount into the SAFE and generates debt
    _modifySAFECollateralization(
      _manager,
      _safeId,
      _collateralAmount.toInt(),
      _getGeneratedDeltaDebt(_safeEngine, _safeInfo.collateralType, _safeInfo.safeHandler, _deltaWad),
      true
    );

    // Exits and transfers COIN amount to the user's address
    _collectAndExitCoins(_manager, _coinJoin, _safeId, _deltaWad);
  }

  function generateDebt(address _manager, address _coinJoin, uint256 _safeId, uint256 _deltaWad) public {
    address _safeEngine = ODSafeManager(_manager).safeEngine();
    ODSafeManager.SAFEData memory _safeInfo = ODSafeManager(_manager).safeData(_safeId);

    // Generates debt in the SAFE
    _modifySAFECollateralization(
      _manager,
      _safeId,
      0,
      _getGeneratedDeltaDebt(_safeEngine, _safeInfo.collateralType, _safeInfo.safeHandler, _deltaWad),
      true
    );

    // Moves the COIN amount to user's address
    _collectAndExitCoins(_manager, _coinJoin, _safeId, _deltaWad);
  }

  function _modifySAFECollateralization(
    address _manager,
    uint256 _safeId,
    int256 _deltaCollateral,
    int256 _deltaDebt,
    bool _nonSafeHandlerAddress
  ) internal {
    ODSafeManager(_manager).modifySAFECollateralization(_safeId, _deltaCollateral, _deltaDebt, _nonSafeHandlerAddress);
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

  function _collectAndExitCoins(address _manager, address _coinJoin, uint256 _safeId, uint256 _deltaWad) internal {
    // Moves the COIN amount to proxy's address
    _transferInternalCoins(_manager, _safeId, address(this), _deltaWad * RAY);
    // Exits the COIN amount to the user's address
    _exitSystemCoins(_coinJoin, _deltaWad * RAY);
  }

  function _transferInternalCoins(address _manager, uint256 _safeId, address _dst, uint256 _rad) internal {
    ODSafeManager(_manager).transferInternalCoins(_safeId, _dst, _rad);
  }

  function _exitSystemCoins(address _coinJoin, uint256 _coinsToExit) internal virtual {
    if (_coinsToExit == 0) return;

    ICoinJoin __coinJoin = ICoinJoin(_coinJoin);
    ISAFEEngine __safeEngine = __coinJoin.safeEngine();

    if (!__safeEngine.canModifySAFE(address(this), _coinJoin)) {
      __safeEngine.approveSAFEModification(_coinJoin);
    }

    // transfer all coins to msg.sender (proxy shouldn't hold any system coins)
    __coinJoin.exit(msg.sender, _coinsToExit / RAY);
  }

  function _joinCollateral(address _collateralJoin, address _safe, uint256 _wad) internal {
    ICollateralJoin __collateralJoin = ICollateralJoin(_collateralJoin);
    IERC20Metadata _token = __collateralJoin.collateral();

    // Transforms the token amount into ERC20 native decimals
    uint256 _decimals = _token.decimals();
    uint256 _wei = _wad / 10 ** (18 - _decimals);
    if (_wei == 0) return;

    // Gets token from the user's wallet
    _token.transferFrom(msg.sender, address(this), _wei);
    // Approves adapter to take the token amount
    _token.approve(_collateralJoin, _wei);
    // Joins token collateral into the safeEngine
    __collateralJoin.join(_safe, _wei);
  }
}

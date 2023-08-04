// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';

import {RAY} from '@libraries/Math.sol';

contract CommonActions {
  error OnlyDelegateCalls();

  // solhint-disable-next-line var-name-mixedcase
  address internal immutable _THIS = address(this);

  // Public functions
  function joinSystemCoins(address _coinJoin, address _dst, uint256 _wad) external delegateCall {
    _joinSystemCoins(_coinJoin, _dst, _wad);
  }

  function exitSystemCoins(address _coinJoin, uint256 _coinsToExit) external delegateCall {
    _exitSystemCoins(_coinJoin, _coinsToExit);
  }

  function exitCollateral(address _collateralJoin, uint256 _wad) external delegateCall {
    _exitCollateral(_collateralJoin, _wad);
  }

  // --- Internal functions ---

  function _joinSystemCoins(address _coinJoin, address _dst, uint256 _wad) internal {
    if (_wad == 0) return;

    // NOTE: assumes systemCoin uses 18 decimals
    IERC20Metadata _systemCoin = ICoinJoin(_coinJoin).systemCoin();
    // Transfers coins from the user to the proxy
    _systemCoin.transferFrom(msg.sender, address(this), _wad);
    // Approves adapter to take the COIN amount
    _systemCoin.approve(_coinJoin, _wad);
    // Joins COIN into the safeEngine
    ICoinJoin(_coinJoin).join(_dst, _wad);
  }

  function _exitSystemCoins(address _coinJoin, uint256 _coinsToExit) internal {
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

  // NOTE: the exited tokens will be rounded down to collateral decimals
  function _exitCollateral(address _collateralJoin, uint256 _wad) internal {
    if (_wad == 0) return;

    ICollateralJoin __collateralJoin = ICollateralJoin(_collateralJoin);
    ISAFEEngine _safeEngine = __collateralJoin.safeEngine();

    if (!_safeEngine.canModifySAFE(address(this), _collateralJoin)) {
      _safeEngine.approveSAFEModification(_collateralJoin);
    }

    uint256 _decimals = __collateralJoin.decimals();
    uint256 _weiAmount = _wad / 10 ** (18 - _decimals);
    __collateralJoin.exit(msg.sender, _weiAmount);
  }

  modifier delegateCall() {
    if (address(this) == _THIS) revert OnlyDelegateCalls();
    _;
  }
}

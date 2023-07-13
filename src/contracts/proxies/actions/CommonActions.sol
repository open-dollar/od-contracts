// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';

import {RAY} from '@libraries/Math.sol';

contract CommonActions {
  error OnlyDelegateCalls();

  address internal immutable _THIS = address(this);

  // Public functions
  function joinSystemCoins(address _coinJoin, address _safeHandler, uint256 _wad) external delegateCall {
    _joinSystemCoins(_coinJoin, _safeHandler, _wad);
  }

  function exitSystemCoins(address _coinJoin, uint256 _coinsToExit) external delegateCall {
    ISAFEEngine _safeEngine = ICoinJoin(_coinJoin).safeEngine();

    _exitSystemCoins(address(_safeEngine), _coinJoin, _coinsToExit);
  }

  function exitAllSystemCoins(address _coinJoin) external delegateCall {
    ISAFEEngine _safeEngine = ICoinJoin(_coinJoin).safeEngine();
    // get the amount of system coins that the proxy has
    uint256 _coinsToExit = _safeEngine.coinBalance(address(this));

    _exitSystemCoins(address(_safeEngine), _coinJoin, _coinsToExit);
  }

  // --- Internal functions ---

  function _joinSystemCoins(address _coinJoin, address _safeHandler, uint256 _wad) internal {
    // NOTE: assumes systemCoin uses 18 decimals
    IERC20Metadata _systemCoin = ICoinJoin(_coinJoin).systemCoin();
    // Transfers coins from the user to the proxy
    _systemCoin.transferFrom(msg.sender, address(this), _wad);
    // Approves adapter to take the COIN amount
    _systemCoin.approve(_coinJoin, _wad);
    // Joins COIN into the safeEngine
    ICoinJoin(_coinJoin).join(_safeHandler, _wad);
  }

  function _exitSystemCoins(address _safeEngine, address _coinJoin, uint256 _coinsToExit) internal {
    ISAFEEngine __safeEngine = ISAFEEngine(_safeEngine);

    if (!__safeEngine.canModifySAFE(address(this), _coinJoin)) {
      __safeEngine.approveSAFEModification(_coinJoin);
    }

    // transfer all coins to msg.sender (proxy shouldn't hold any system coins)
    ICoinJoin(_coinJoin).exit(msg.sender, _coinsToExit / RAY);
  }

  function _joinCollateral(address _collateralJoin, address _safe, uint256 _wad, bool _transferFrom) internal {
    // Only executes for tokens that have approval/transferFrom implementation
    ICollateralJoin __collateralJoin = ICollateralJoin(_collateralJoin);
    IERC20Metadata _token = IERC20Metadata(__collateralJoin.collateral());
    uint256 _decimals = _token.decimals();
    // Transforms the token amount into ERC20 native decimals
    uint256 _wei = _wad / 10 ** (18 - _decimals);

    if (_transferFrom) {
      // Gets token from the user's wallet
      _token.transferFrom(msg.sender, address(this), _wei);
      // Approves adapter to take the token amount
      _token.approve(_collateralJoin, _wei);
    }

    // Joins token collateral into the safeEngine
    __collateralJoin.join(_safe, _wei);
  }

  function _collectCollateral(address _collateralJoin, uint256 _wad) internal {
    ISAFEEngine _safeEngine = ICollateralJoin(_collateralJoin).safeEngine();

    if (!_safeEngine.canModifySAFE(address(this), _collateralJoin)) {
      _safeEngine.approveSAFEModification(_collateralJoin);
    }

    uint256 _decimals = ICollateralJoin(_collateralJoin).decimals();
    uint256 _boughtWeiAmount = _wad / 10 ** (18 - _decimals);
    ICollateralJoin(_collateralJoin).exit(msg.sender, _boughtWeiAmount);
  }

  modifier delegateCall() {
    if (address(this) == _THIS) revert OnlyDelegateCalls();
    _;
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {ICommonActions} from '@interfaces/proxies/actions/ICommonActions.sol';

import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {RAY} from '@libraries/Math.sol';

/**
 * @title  CommonActions
 * @notice This abstract contract defines common actions to be used by the proxy actions contracts
 */
abstract contract CommonActions is ICommonActions {
  using SafeERC20 for IERC20Metadata;

  /// @notice Address of the inheriting contract, used to check if the call is being made through a delegate call
  // solhint-disable-next-line var-name-mixedcase
  address internal immutable _THIS = address(this);

  // --- Methods ---

  /// @inheritdoc ICommonActions
  function joinSystemCoins(address _coinJoin, address _dst, uint256 _wad) external onlyDelegateCall {
    _joinSystemCoins(_coinJoin, _dst, _wad);
  }

  /// @inheritdoc ICommonActions
  function exitSystemCoins(address _coinJoin, uint256 _coinsToExit) external onlyDelegateCall {
    _exitSystemCoins(_coinJoin, _coinsToExit);
  }

  /// @inheritdoc ICommonActions
  function exitAllSystemCoins(address _coinJoin) external onlyDelegateCall {
    uint256 _coinsToExit = ICoinJoin(_coinJoin).safeEngine().coinBalance(address(this));
    _exitSystemCoins(_coinJoin, _coinsToExit);
  }

  /// @inheritdoc ICommonActions
  function exitCollateral(address _collateralJoin, uint256 _wad) external onlyDelegateCall {
    _exitCollateral(_collateralJoin, _wad);
  }

  // --- Internal functions ---

  /**
   * @notice Joins system coins into the safeEngine
   * @dev    Transfers ERC20 coins from the user to the proxy, then joins them through the CoinJoin contract into the destination SAFE
   */
  function _joinSystemCoins(address _coinJoin, address _dst, uint256 _wad) internal {
    if (_wad == 0) return;

    // NOTE: assumes systemCoin uses 18 decimals
    IERC20Metadata _systemCoin = ICoinJoin(_coinJoin).systemCoin();
    // Transfers coins from the user to the proxy
    _systemCoin.safeTransferFrom(msg.sender, address(this), _wad);
    // Approves adapter to take the COIN amount
    _systemCoin.forceApprove(_coinJoin, _wad);
    // Joins COIN into the safeEngine
    ICoinJoin(_coinJoin).join(_dst, _wad);
  }

  /**
   * @notice Exits system coins from the safeEngine
   * @dev    Exits system coins through the CoinJoin contract, transferring the ERC20 coins to the user
   */
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

  /**
   * @notice Joins collateral tokens into the safeEngine
   * @dev    Transfers ERC20 tokens from the user to the proxy, then joins them through the CollateralJoin contract into the destination SAFE
   */
  function _joinCollateral(address _collateralJoin, address _safe, uint256 _wad) internal {
    ICollateralJoin __collateralJoin = ICollateralJoin(_collateralJoin);
    IERC20Metadata _token = __collateralJoin.collateral();

    // Transforms the token amount into ERC20 native decimals
    uint256 _decimals = _token.decimals();
    uint256 _wei = _wad / 10 ** (18 - _decimals);
    if (_wei == 0) return;

    // Gets token from the user's wallet
    _token.safeTransferFrom(msg.sender, address(this), _wei);
    // Approves adapter to take the token amount
    _token.forceApprove(_collateralJoin, _wei);
    // Joins token collateral into the safeEngine
    __collateralJoin.join(_safe, _wei);
  }

  /**
   * @notice Exits collateral tokens from the safeEngine
   * @dev    Exits collateral tokens through the CollateralJoin contract, transferring the ERC20 tokens to the user
   * @dev    The exited tokens will be rounded down to collateral decimals precision
   */
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

  // --- Modifiers ---

  /// @notice Checks if the call is being made through a delegate call
  modifier onlyDelegateCall() {
    if (address(this) == _THIS) revert OnlyDelegateCalls();
    _;
  }
}

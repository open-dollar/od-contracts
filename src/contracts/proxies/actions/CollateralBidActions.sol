// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';
import {ICollateralBidActions} from '@interfaces/proxies/actions/ICollateralBidActions.sol';

import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';

import {RAY} from '@libraries/Math.sol';

/**
 * @title  CollateralBidActions
 * @notice All methods here are executed as delegatecalls from the user's proxy
 */
contract CollateralBidActions is CommonActions, ICollateralBidActions {
  // --- Methods ---

  /// @inheritdoc ICollateralBidActions
  function buyCollateral(
    address _coinJoin,
    address _collateralJoin,
    address _collateralAuctionHouse,
    uint256 _auctionId,
    uint256 _minCollateralAmount,
    uint256 _bidAmount
  ) external onlyDelegateCall {
    ISAFEEngine _safeEngine = ICoinJoin(_coinJoin).safeEngine();
    // checks coin balance and joins more if needed
    uint256 _coinBalance = _safeEngine.coinBalance(address(this)) / RAY;
    if (_coinBalance < _bidAmount) {
      _joinSystemCoins(_coinJoin, address(this), _bidAmount - _coinBalance);
    }

    // collateralAuctionHouse needs to be approved for system coin spending
    if (!_safeEngine.canModifySAFE(address(this), address(_collateralAuctionHouse))) {
      _safeEngine.approveSAFEModification(address(_collateralAuctionHouse));
    }

    (uint256 _boughtAmount, uint256 _adjustedBid) =
      ICollateralAuctionHouse(_collateralAuctionHouse).buyCollateral(_auctionId, _bidAmount);

    if (_adjustedBid > _bidAmount) {
      revert ColActions_InvalidAdjustedBid();
    }

    if (_boughtAmount < _minCollateralAmount) {
      revert ColActions_InsufficientCollateralReceived(_minCollateralAmount, _boughtAmount);
    }

    // exit collateral
    _exitCollateral(_collateralJoin, _boughtAmount);
  }
}

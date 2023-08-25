// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';

import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';

import {RAY} from '@libraries/Math.sol';

/**
 * @title  CollateralBidActions
 * @notice All methods here are executed as delegatecalls from the user's proxy
 */
contract CollateralBidActions is CommonActions {
  // --- Methods ---

  /**
   * @notice Buys collateral tokens from a collateral auction
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _collateralJoin Address of the CollateralJoin contract
   * @param  _collateralAuctionHouse Address of the CollateralAuctionHouse contract
   * @param  _auctionId Id of the auction to bid on
   * @param  _minCollateralAmount Minimum amount of collateral tokens to buy [wad]
   * @param  _bidAmount Amount of system coins to bid [wad]
   * @dev    This method will fail if the purchased amount is lower than the minimum, or the bid higher than the specified amount
   */
  function buyCollateral(
    address _coinJoin,
    address _collateralJoin,
    address _collateralAuctionHouse,
    uint256 _auctionId,
    uint256 _minCollateralAmount,
    uint256 _bidAmount
  ) external delegateCall {
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

    require(_adjustedBid <= _bidAmount, 'Invalid adjusted bid');
    require(_boughtAmount >= _minCollateralAmount, 'Invalid bought amount');

    // exit collateral
    _exitCollateral(_collateralJoin, _boughtAmount);
  }
}

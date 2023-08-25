// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {IDebtAuctionHouse} from '@interfaces/IDebtAuctionHouse.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';

import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';

import {RAY} from '@libraries/Math.sol';

/**
 * @title  DebtBidActions
 * @notice All methods here are executed as delegatecalls from the user's proxy
 */
contract DebtBidActions is CommonActions {
  // --- Methods ---

  /**
   * @notice Place a bid offering to receive a lesser amount of protocol tokens for covering the auctioned debt amount
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _debtAuctionHouse Address of the DebtAuctionHouse contract
   * @param  _auctionId Id of the auction to bid on
   * @param  _soldAmount Amount of protocol tokens to receive [wad]
   */
  function decreaseSoldAmount(
    address _coinJoin,
    address _debtAuctionHouse,
    uint256 _auctionId,
    uint256 _soldAmount
  ) external delegateCall {
    uint256 _bidAmount = IDebtAuctionHouse(_debtAuctionHouse).auctions(_auctionId).bidAmount;

    ISAFEEngine _safeEngine = ICoinJoin(_coinJoin).safeEngine();
    // checks coin balance and joins more if needed
    uint256 _coinBalance = _safeEngine.coinBalance(address(this));
    if (_coinBalance < _bidAmount) {
      _joinSystemCoins(_coinJoin, address(this), (_bidAmount - _coinBalance) / RAY);
    }

    // debtAuctionHouse needs to be approved for system coin spending
    if (!_safeEngine.canModifySAFE(address(this), address(_debtAuctionHouse))) {
      _safeEngine.approveSAFEModification(address(_debtAuctionHouse));
    }

    IDebtAuctionHouse(_debtAuctionHouse).decreaseSoldAmount(_auctionId, _soldAmount, _bidAmount);
  }

  /**
   * @notice Settles an auction, collecting the protocol tokens if the user is the highest bidder
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _debtAuctionHouse Address of the DebtAuctionHouse contract
   * @param  _auctionId Id of the auction to settle
   * @dev    This method will fail if the auction is not finished
   */
  function settleAuction(address _coinJoin, address _debtAuctionHouse, uint256 _auctionId) external delegateCall {
    IDebtAuctionHouse.Auction memory _auction = IDebtAuctionHouse(_debtAuctionHouse).auctions(_auctionId);
    IDebtAuctionHouse(_debtAuctionHouse).settleAuction(_auctionId);

    if (_auction.highBidder == address(this)) {
      // get the amount of protocol tokens that were sold
      IERC20Metadata _protocolToken = IDebtAuctionHouse(_debtAuctionHouse).protocolToken();
      _protocolToken.transfer(msg.sender, _auction.amountToSell);
    }

    // exit all system coins from the coinJoin
    ISAFEEngine _safeEngine = ICoinJoin(_coinJoin).safeEngine();
    uint256 _coinsToExit = _safeEngine.coinBalance(address(this));
    if (_coinsToExit > 0) {
      _exitSystemCoins(_coinJoin, _coinsToExit);
    }
  }

  /**
   * @notice Collects the protocol tokens that the proxy has
   * @param  _protocolToken Address of the protocol token
   * @dev    This method is used to collect protocol tokens from an auction that was settled by another user
   */
  function collectProtocolTokens(address _protocolToken) external delegateCall {
    // get the amount of protocol tokens that the proxy has
    uint256 _coinsToCollect = IERC20Metadata(_protocolToken).balanceOf(address(this));
    IERC20Metadata(_protocolToken).transfer(msg.sender, _coinsToCollect);
  }
}

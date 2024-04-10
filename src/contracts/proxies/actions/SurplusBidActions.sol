// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IERC20MetadataUpgradeable} from '@openzeppelin-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';
import {ISurplusBidActions} from '@interfaces/proxies/actions/ISurplusBidActions.sol';

import {CommonActions, SafeERC20, IERC20} from '@contracts/proxies/actions/CommonActions.sol';

import {RAY} from '@libraries/Math.sol';

/**
 * @title  SurplusBidActions
 * @notice All methods here are executed as delegatecalls from the user's proxy
 */
contract SurplusBidActions is ISurplusBidActions, CommonActions {
  using SafeERC20 for IERC20;
  // --- Methods ---

  /// @inheritdoc ISurplusBidActions
  function increaseBidSize(address _surplusAuctionHouse, uint256 _auctionId, uint256 _bidAmount) external delegateCall {
    uint256 _spendAmount = _bidAmount;
    ISurplusAuctionHouse.Auction memory _auction = ISurplusAuctionHouse(_surplusAuctionHouse).auctions(_auctionId);

    // If this proxy is already the highest bidder we only need to spend the increment
    if (_auction.highBidder == address(this)) {
      _spendAmount -= _auction.bidAmount;
    }

    // prepare protocol token spending
    address _protocolToken = address(ISurplusAuctionHouse(_surplusAuctionHouse).protocolToken());
    IERC20(_protocolToken).safeTransferFrom(msg.sender, address(this), _bidAmount);
    IERC20(_protocolToken).safeIncreaseAllowance(address(_surplusAuctionHouse), _bidAmount);

    // proxy needs to be approved for protocol token spending
    ISurplusAuctionHouse(_surplusAuctionHouse).increaseBidSize(_auctionId, _bidAmount);
  }

  /// @inheritdoc ISurplusBidActions
    function settleAuction(address _coinJoin, address _surplusAuctionHouse, uint256 _auctionId) external delegateCall {
    uint256 _amountToSell = ISurplusAuctionHouse(_surplusAuctionHouse).auctions(_auctionId).amountToSell;
    ISurplusAuctionHouse(_surplusAuctionHouse).settleAuction(_auctionId);

    _exitSystemCoins(_coinJoin, _amountToSell);
  }
}

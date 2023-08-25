// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';

import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';

import {RAY} from '@libraries/Math.sol';

/**
 * @title  SurplusBidActions
 * @notice All methods here are executed as delegatecalls from the user's proxy
 */
contract SurplusBidActions is CommonActions {
  // --- Methods ---

  /**
   * @notice Place a bid offering to provide a higher amount of coins for receiving the auctioned protocol tokens
   * @param  _surplusAuctionHouse Address of the SurplusAuctionHouse contract
   * @param  _auctionId Id of the auction to bid on
   * @param  _bidAmount Amount of system coins to bid [wad]
   */
  function increaseBidSize(address _surplusAuctionHouse, uint256 _auctionId, uint256 _bidAmount) external delegateCall {
    uint256 _amountToSell = ISurplusAuctionHouse(_surplusAuctionHouse).auctions(_auctionId).amountToSell;

    // prepare protocol token spending
    IERC20Metadata _protocolToken = ISurplusAuctionHouse(_surplusAuctionHouse).protocolToken();
    _protocolToken.transferFrom(msg.sender, address(this), _bidAmount);
    _protocolToken.approve(address(_surplusAuctionHouse), _bidAmount);

    // proxy needs to be approved for protocol token spending
    ISurplusAuctionHouse(_surplusAuctionHouse).increaseBidSize(_auctionId, _amountToSell, _bidAmount);
  }

  /**
   * @notice Settles an auction, collecting the system coins if the user is the highest bidder
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _surplusAuctionHouse Address of the SurplusAuctionHouse contract
   * @param  _auctionId Id of the auction to settle
   * @dev    This method will fail if the auction is not finished
   */
  function settleAuction(address _coinJoin, address _surplusAuctionHouse, uint256 _auctionId) external delegateCall {
    uint256 _amountToSell = ISurplusAuctionHouse(_surplusAuctionHouse).auctions(_auctionId).amountToSell;
    ISurplusAuctionHouse(_surplusAuctionHouse).settleAuction(_auctionId);

    _exitSystemCoins(_coinJoin, _amountToSell);
  }
}

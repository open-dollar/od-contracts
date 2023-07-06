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
 * @title SurplusBidActions
 * @notice All methods here are executed as delegatecalls from the user's proxy
 */
contract SurplusBidActions is CommonActions {
  function startAndIncreaseBidSize(address _accountingEngine, uint256 _bidAmount) external delegateCall {
    uint256 _auctionId = IAccountingEngine(_accountingEngine).auctionSurplus();
    ISurplusAuctionHouse _surplusAuctionHouse = IAccountingEngine(_accountingEngine).surplusAuctionHouse();
    uint256 _amountToSell = ISurplusAuctionHouse(_surplusAuctionHouse).auctions(_auctionId).amountToSell;

    // prepare protocol token spending
    IERC20Metadata _protocolToken = _surplusAuctionHouse.protocolToken();
    _protocolToken.transferFrom(msg.sender, address(this), _bidAmount);
    _protocolToken.approve(address(_surplusAuctionHouse), _bidAmount);

    ISurplusAuctionHouse(_surplusAuctionHouse).increaseBidSize(_auctionId, _amountToSell, _bidAmount);
  }

  function increaseBidSize(address _surplusAuctionHouse, uint256 _auctionId, uint256 _bidAmount) external delegateCall {
    uint256 _amountToSell = ISurplusAuctionHouse(_surplusAuctionHouse).auctions(_auctionId).amountToSell;

    // prepare protocol token spending
    IERC20Metadata _protocolToken = ISurplusAuctionHouse(_surplusAuctionHouse).protocolToken();
    _protocolToken.transferFrom(msg.sender, address(this), _bidAmount);
    _protocolToken.approve(address(_surplusAuctionHouse), _bidAmount);

    // proxy needs to be approved for protocol token spending
    ISurplusAuctionHouse(_surplusAuctionHouse).increaseBidSize(_auctionId, _amountToSell, _bidAmount);
  }

  function settleAuction(address _coinJoin, address _surplusAuctionHouse, uint256 _auctionId) external delegateCall {
    uint256 _amountToSell = ISurplusAuctionHouse(_surplusAuctionHouse).auctions(_auctionId).amountToSell;
    ISurplusAuctionHouse(_surplusAuctionHouse).settleAuction(_auctionId);

    ISAFEEngine _safeEngine = ISurplusAuctionHouse(_surplusAuctionHouse).safeEngine();
    if (!_safeEngine.canModifySAFE(address(this), _coinJoin)) {
      _safeEngine.approveSAFEModification(_coinJoin);
    }

    // get the amount of system coins that were sold
    ICoinJoin(_coinJoin).exit(msg.sender, _amountToSell / RAY);
  }

  function collectSystemCoins(address _coinJoin) external delegateCall {
    ISAFEEngine _safeEngine = ICoinJoin(_coinJoin).safeEngine();

    // get the amount of system coins that the proxy has
    uint256 _coinsToCollect = _safeEngine.coinBalance(address(this));

    if (!_safeEngine.canModifySAFE(address(this), _coinJoin)) {
      _safeEngine.approveSAFEModification(_coinJoin);
    }

    // transfer all coins to msg.sender (proxy shouldn't hold any system coins)
    ICoinJoin(_coinJoin).exit(msg.sender, _coinsToCollect / RAY);
  }
}

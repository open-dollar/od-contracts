// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {WAD, HUNDRED} from '@libraries/Math.sol';

// This thing lets you auction surplus for protocol tokens. 50% of the protocol tokens are sent to another address and the rest are burned
contract SurplusAuctionHouse is Authorizable, Modifiable, Disableable, ISurplusAuctionHouse {
  using Encoding for bytes;
  using Assertions for address;
  using SafeERC20 for IProtocolToken;

  bytes32 public constant AUCTION_HOUSE_TYPE = bytes32('SURPLUS');
  bytes32 public constant SURPLUS_AUCTION_TYPE = bytes32('MIXED-STRAT');

  // --- Data ---
  // Bid data for each separate auction
  mapping(uint256 => Bid) public bids;
  // Number of auctions started up until now
  uint256 public auctionsStarted;

  // --- Registry ---
  // SAFE database
  ISAFEEngine public safeEngine;
  // Protocol token address
  IProtocolToken public protocolToken;
  // Receiver of protocol tokens
  address public protocolTokenBidReceiver;

  // --- Params ---
  SurplusAuctionHouseParams internal _params;

  function params() external view returns (SurplusAuctionHouseParams memory _sahParams) {
    return _params;
  }

  // --- Init ---
  constructor(
    address _safeEngine,
    address _protocolToken,
    SurplusAuctionHouseParams memory _sahParams
  ) Authorizable(msg.sender) validParams {
    safeEngine = ISAFEEngine(_safeEngine);
    protocolToken = IProtocolToken(_protocolToken);

    _params = _sahParams;
  }

  // --- Shutdown ---

  /**
   * @notice Disable the auction house (usually called by AccountingEngine)
   */
  function _onContractDisable() internal override {
    uint256 _coinBalance = safeEngine.coinBalance(address(this));
    safeEngine.transferInternalCoins(address(this), msg.sender, _coinBalance);
  }

  // --- Auction ---
  /**
   * @notice Start a new surplus auction
   * @param _amountToSell Total amount of system coins to sell (rad)
   * @param _initialBid Initial protocol token bid (wad)
   */
  function startAuction(
    uint256 _amountToSell,
    uint256 _initialBid
  ) external isAuthorized whenEnabled returns (uint256 _id) {
    if (protocolTokenBidReceiver == address(0) && _params.recyclingPercentage != 0) revert SAH_NullProtTokenReceiver();
    _id = ++auctionsStarted;

    bids[_id].bidAmount = _initialBid;
    bids[_id].amountToSell = _amountToSell;
    bids[_id].highBidder = msg.sender;
    bids[_id].auctionDeadline = uint48(block.timestamp) + _params.totalAuctionLength;

    safeEngine.transferInternalCoins(msg.sender, address(this), _amountToSell);

    emit StartAuction(_id, auctionsStarted, _amountToSell, _initialBid, bids[_id].auctionDeadline);
  }

  /**
   * @notice Restart an auction if no bids were submitted for it
   * @param _id ID of the auction to restart
   */
  function restartAuction(uint256 _id) external {
    if (_id == 0 || _id > auctionsStarted) revert SAH_AuctionNeverStarted();
    if (bids[_id].auctionDeadline > block.timestamp) revert SAH_AuctionNotFinished();
    if (bids[_id].bidExpiry != 0) revert SAH_BidAlreadyPlaced();
    bids[_id].auctionDeadline = uint48(block.timestamp) + _params.totalAuctionLength;
    emit RestartAuction(_id, bids[_id].auctionDeadline);
  }

  /**
   * @notice Submit a higher protocol token bid for the same amount of system coins
   * @param _id ID of the auction you want to submit the bid for
   * @param _amountToBuy Amount of system coins to buy (rad)
   * @param _bid New bid submitted (wad)
   */
  function increaseBidSize(uint256 _id, uint256 _amountToBuy, uint256 _bid) external whenEnabled {
    if (bids[_id].highBidder == address(0)) revert SAH_HighBidderNotSet();
    if (bids[_id].bidExpiry <= block.timestamp && bids[_id].bidExpiry != 0) revert SAH_BidAlreadyExpired();
    if (bids[_id].auctionDeadline <= block.timestamp) revert SAH_AuctionAlreadyExpired();

    if (_amountToBuy != bids[_id].amountToSell) revert SAH_AmountsNotMatching();
    if (_bid <= bids[_id].bidAmount) revert SAH_BidNotHigher();
    if (_bid * WAD < _params.bidIncrease * bids[_id].bidAmount) revert SAH_InsufficientIncrease();

    if (msg.sender != bids[_id].highBidder) {
      protocolToken.safeTransferFrom(msg.sender, bids[_id].highBidder, bids[_id].bidAmount);
      bids[_id].highBidder = msg.sender;
    }
    protocolToken.safeTransferFrom(msg.sender, address(this), _bid - bids[_id].bidAmount);

    bids[_id].bidAmount = _bid;
    bids[_id].bidExpiry = uint48(block.timestamp) + _params.bidDuration;

    emit IncreaseBidSize(_id, msg.sender, _amountToBuy, _bid, bids[_id].bidExpiry);
  }

  /**
   * @notice Settle/finish an auction
   * @param _id ID of the auction to settle
   */
  function settleAuction(uint256 _id) external whenEnabled {
    if (
      bids[_id].bidExpiry == 0 || (bids[_id].bidExpiry > block.timestamp && bids[_id].auctionDeadline > block.timestamp)
    ) revert SAH_AuctionNotFinished();
    safeEngine.transferInternalCoins(address(this), bids[_id].highBidder, bids[_id].amountToSell);

    uint256 _amountToSend = bids[_id].bidAmount * _params.recyclingPercentage / HUNDRED;
    if (_amountToSend > 0) {
      protocolToken.safeTransfer(protocolTokenBidReceiver, _amountToSend);
    }

    uint256 _amountToBurn = bids[_id].bidAmount - _amountToSend;
    if (_amountToBurn > 0) {
      protocolToken.burn(_amountToBurn);
    }

    delete bids[_id];
    emit SettleAuction(_id);
  }

  /**
   * @notice Terminate an auction prematurely.
   * @param _id ID of the auction to settle/terminate
   */
  function terminateAuctionPrematurely(uint256 _id) external whenDisabled {
    if (bids[_id].highBidder == address(0)) revert SAH_HighBidderNotSet();
    protocolToken.safeTransfer(bids[_id].highBidder, bids[_id].bidAmount);
    emit TerminateAuctionPrematurely(_id, msg.sender, bids[_id].highBidder, bids[_id].bidAmount);
    delete bids[_id];
  }

  // --- Administration ---

  function _modifyParameters(bytes32 _param, bytes memory _data) internal override validParams {
    uint256 _uint256 = _data.toUint256();

    // TODO: incorporate protocolTokenBidReceiver to _params
    if (_param == 'protocolTokenBidReceiver') protocolTokenBidReceiver = _data.toAddress().assertNonNull();
    else if (_param == 'bidIncrease') _params.bidIncrease = _uint256;
    else if (_param == 'bidDuration') _params.bidDuration = uint48(_uint256);
    else if (_param == 'totalAuctionLength') _params.totalAuctionLength = uint48(_uint256);
    else if (_param == 'recyclingPercentage') _params.recyclingPercentage = _uint256;
    else revert UnrecognizedParam();
  }
}

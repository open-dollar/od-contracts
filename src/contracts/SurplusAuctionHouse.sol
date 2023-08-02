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
import {Math, WAD} from '@libraries/Math.sol';

// This thing lets you auction surplus for protocol tokens. 50% of the protocol tokens are sent to another address and the rest are burned
contract SurplusAuctionHouse is Authorizable, Modifiable, Disableable, ISurplusAuctionHouse {
  using Math for uint256;
  using Encoding for bytes;
  using Assertions for address;
  using SafeERC20 for IProtocolToken;

  bytes32 public constant AUCTION_HOUSE_TYPE = bytes32('SURPLUS');
  bytes32 public constant SURPLUS_AUCTION_TYPE = bytes32('MIXED-STRAT');

  // --- Data ---
  // Data for each separate auction
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(uint256 => Auction) public _auctions;

  function auctions(uint256 _id) external view returns (Auction memory _auction) {
    return _auctions[_id];
  }

  // Number of auctions started up until now
  uint256 public auctionsStarted;

  // --- Registry ---
  // SAFE database
  ISAFEEngine public safeEngine;
  // Protocol token address
  IProtocolToken public protocolToken;

  // --- Params ---
  // solhint-disable-next-line private-vars-leading-underscore
  SurplusAuctionHouseParams public _params;

  function params() external view returns (SurplusAuctionHouseParams memory _sahParams) {
    return _params;
  }

  // --- Init ---
  constructor(
    address _safeEngine,
    address _protocolToken,
    SurplusAuctionHouseParams memory _sahParams
  ) Authorizable(msg.sender) validParams {
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
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
    if (_params.bidReceiver == address(0) && _params.recyclingPercentage != 0) revert SAH_NullProtTokenReceiver();
    _id = ++auctionsStarted;

    _auctions[_id] = Auction({
      bidAmount: _initialBid,
      amountToSell: _amountToSell,
      highBidder: msg.sender,
      bidExpiry: 0,
      auctionDeadline: block.timestamp + _params.totalAuctionLength
    });

    safeEngine.transferInternalCoins(msg.sender, address(this), _amountToSell);

    emit StartAuction({
      _id: _id,
      _blockTimestamp: block.timestamp,
      _amountToSell: _amountToSell,
      _amountToRaise: _initialBid,
      _auctionDeadline: _auctions[_id].auctionDeadline
    });
  }

  /**
   * @notice Restart an auction if no bids were submitted for it
   * @param _id ID of the auction to restart
   */
  function restartAuction(uint256 _id) external {
    if (_id == 0 || _id > auctionsStarted) revert SAH_AuctionNeverStarted();
    Auction storage _auction = _auctions[_id];
    if (_auction.auctionDeadline > block.timestamp) revert SAH_AuctionNotFinished();
    if (_auction.bidExpiry != 0) revert SAH_BidAlreadyPlaced();
    _auction.auctionDeadline = block.timestamp + _params.totalAuctionLength;

    emit RestartAuction({_id: _id, _blockTimestamp: block.timestamp, _auctionDeadline: _auction.auctionDeadline});
  }

  /**
   * @notice Submit a higher protocol token bid for the same amount of system coins
   * @param _id ID of the auction you want to submit the bid for
   * @param _amountToBuy Amount of system coins to buy (rad)
   * @param _bid New bid submitted (wad)
   */
  function increaseBidSize(uint256 _id, uint256 _amountToBuy, uint256 _bid) external whenEnabled {
    Auction storage _auction = _auctions[_id];
    if (_auction.highBidder == address(0)) revert SAH_HighBidderNotSet();
    if (_auction.bidExpiry <= block.timestamp && _auction.bidExpiry != 0) revert SAH_BidAlreadyExpired();
    if (_auction.auctionDeadline <= block.timestamp) revert SAH_AuctionAlreadyExpired();
    if (_amountToBuy != _auction.amountToSell) revert SAH_AmountsNotMatching();
    if (_bid <= _auction.bidAmount) revert SAH_BidNotHigher();
    if (_bid * WAD < _params.bidIncrease * _auction.bidAmount) revert SAH_InsufficientIncrease();

    if (msg.sender != _auction.highBidder) {
      protocolToken.safeTransferFrom(msg.sender, _auction.highBidder, _auction.bidAmount);
      _auction.highBidder = msg.sender;
    }
    protocolToken.safeTransferFrom(msg.sender, address(this), _bid - _auction.bidAmount);

    _auction.bidAmount = _bid;
    _auction.bidExpiry = block.timestamp + _params.bidDuration;

    emit IncreaseBidSize({
      _id: _id,
      _bidder: msg.sender,
      _blockTimestamp: block.timestamp,
      _raisedAmount: _bid,
      _soldAmount: _amountToBuy,
      _bidExpiry: _auction.bidExpiry
    });
  }

  /**
   * @notice Settle/finish an auction
   * @param _id ID of the auction to settle
   */
  function settleAuction(uint256 _id) external whenEnabled {
    Auction memory _auction = _auctions[_id];
    if (_auction.bidExpiry == 0 || (_auction.bidExpiry > block.timestamp && _auction.auctionDeadline > block.timestamp))
    {
      revert SAH_AuctionNotFinished();
    }

    safeEngine.transferInternalCoins(address(this), _auction.highBidder, _auction.amountToSell);

    uint256 _amountToSend = _auction.bidAmount.wmul(_params.recyclingPercentage);
    if (_amountToSend > 0) {
      protocolToken.safeTransfer(_params.bidReceiver, _amountToSend);
    }

    uint256 _amountToBurn = _auction.bidAmount - _amountToSend;
    if (_amountToBurn > 0) {
      protocolToken.burn(_amountToBurn);
    }

    emit SettleAuction({
      _id: _id,
      _blockTimestamp: block.timestamp,
      _highBidder: _auction.highBidder,
      _raisedAmount: _auction.bidAmount
    });

    delete _auctions[_id];
  }

  /**
   * @notice Terminate an auction prematurely.
   * @param _id ID of the auction to settle/terminate
   */
  function terminateAuctionPrematurely(uint256 _id) external whenDisabled {
    Auction memory _auction = _auctions[_id];
    if (_auction.highBidder == address(0)) revert SAH_HighBidderNotSet();

    protocolToken.safeTransfer(_auction.highBidder, _auction.bidAmount);

    emit TerminateAuctionPrematurely({
      _id: _id,
      _blockTimestamp: block.timestamp,
      _highBidder: _auction.highBidder,
      _raisedAmount: _auction.bidAmount
    });

    delete _auctions[_id];
  }

  // --- Administration ---

  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    address _address = _data.toAddress();
    uint256 _uint256 = _data.toUint256();

    if (_param == 'protocolToken') protocolToken = IProtocolToken(_address);
    else if (_param == 'bidIncrease') _params.bidIncrease = _uint256;
    else if (_param == 'bidDuration') _params.bidDuration = _uint256;
    else if (_param == 'totalAuctionLength') _params.totalAuctionLength = _uint256;
    else if (_param == 'bidReceiver') _params.bidReceiver = _address;
    else if (_param == 'recyclingPercentage') _params.recyclingPercentage = _uint256;
    else revert UnrecognizedParam();
  }

  function _validateParameters() internal view override {
    address(protocolToken).assertNonNull();
    _params.bidReceiver.assertNonNull();
  }
}

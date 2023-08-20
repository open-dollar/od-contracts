// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IDebtAuctionHouse} from '@interfaces/IDebtAuctionHouse.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {Math, WAD} from '@libraries/Math.sol';
import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';

// This thing creates protocol tokens on demand in return for system coins
contract DebtAuctionHouse is Authorizable, Modifiable, Disableable, IDebtAuctionHouse {
  using Encoding for bytes;
  using Assertions for address;

  bytes32 public constant AUCTION_HOUSE_TYPE = bytes32('DEBT');

  // --- Data ---
  // Data for each separate auction
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(uint256 => Auction) public _auctions;

  function auctions(uint256 _id) external view returns (Auction memory _auction) {
    return _auctions[_id];
  }

  // Number of auctions started up until now
  uint256 public auctionsStarted;
  // Accumulator for all debt auctions currently not settled
  uint256 public activeDebtAuctions;

  // --- Registry ---
  // SAFE database
  ISAFEEngine public safeEngine;
  // Protocol token address
  IProtocolToken public protocolToken;
  // Accounting engine
  address public accountingEngine;

  // --- Params ---
  // solhint-disable-next-line private-vars-leading-underscore
  DebtAuctionHouseParams public _params;

  function params() external view returns (DebtAuctionHouseParams memory _dahParams) {
    return _params;
  }

  // --- Init ---
  constructor(
    address _safeEngine,
    address _protocolToken,
    DebtAuctionHouseParams memory _dahParams
  ) Authorizable(msg.sender) validParams {
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
    protocolToken = IProtocolToken(_protocolToken);

    _params = _dahParams;
  }

  // --- Shutdown ---

  /**
   * @notice Disable the auction house (usually called by the AccountingEngine)
   */
  function _onContractDisable() internal override {
    accountingEngine = msg.sender;
    delete activeDebtAuctions;
  }

  // --- Auction ---
  /**
   * @notice Start a new debt auction
   * @param _incomeReceiver Who receives the auction proceeds
   * @param _amountToSell Amount of protocol tokens to sell (wad)
   * @param _initialBid Initial bid size (rad)
   */
  function startAuction(
    address _incomeReceiver,
    uint256 _amountToSell,
    uint256 _initialBid
  ) external isAuthorized whenEnabled returns (uint256 _id) {
    _id = ++auctionsStarted;

    _auctions[_id] = Auction({
      bidAmount: _initialBid,
      amountToSell: _amountToSell,
      highBidder: _incomeReceiver,
      bidExpiry: 0, // no bid yet
      auctionDeadline: block.timestamp + _params.totalAuctionLength
    });
    ++activeDebtAuctions;

    emit StartAuction({
      _id: _id,
      _auctioneer: msg.sender,
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
    Auction storage _auction = _auctions[_id];
    if (_id == 0 || _id > auctionsStarted) revert DAH_AuctionNeverStarted();
    if (_auction.auctionDeadline > block.timestamp) revert DAH_AuctionNotFinished();
    if (_auction.bidExpiry != 0) revert DAH_BidAlreadyPlaced();
    _auction.amountToSell = (_params.amountSoldIncrease * _auction.amountToSell) / WAD;
    _auction.auctionDeadline = block.timestamp + _params.totalAuctionLength;

    emit RestartAuction({_id: _id, _blockTimestamp: block.timestamp, _auctionDeadline: _auction.auctionDeadline});
  }

  /**
   * @notice Decrease the protocol token amount you're willing to receive in
   *         exchange for providing the same amount of system coins being raised by the auction
   * @param _id ID of the auction for which you want to submit a new bid
   * @param _amountToBuy Amount of protocol tokens to buy (must be smaller than the previous proposed amount) (wad)
   * @param _bid New system coin bid (must always equal the total amount raised by the auction) (rad)
   */
  function decreaseSoldAmount(uint256 _id, uint256 _amountToBuy, uint256 _bid) external whenEnabled {
    Auction storage _auction = _auctions[_id];
    if (_auction.highBidder == address(0)) revert DAH_HighBidderNotSet();
    if (_auction.bidExpiry <= block.timestamp && _auction.bidExpiry != 0) revert DAH_BidAlreadyExpired();
    if (_auction.auctionDeadline <= block.timestamp) revert DAH_AuctionAlreadyExpired();

    if (_bid != _auction.bidAmount) revert DAH_NotMatchingBid();
    if (_amountToBuy >= _auction.amountToSell) revert DAH_AmountBoughtNotLower();
    if (_params.bidDecrease * _amountToBuy > _auction.amountToSell * WAD) revert DAH_InsufficientDecrease();

    safeEngine.transferInternalCoins(msg.sender, _auction.highBidder, _bid);

    // on first bid submitted, clear as much totalOnAuctionDebt as possible
    if (_auction.bidExpiry == 0) {
      uint256 _totalOnAuctionDebt = IAccountingEngine(_auction.highBidder).totalOnAuctionDebt();
      IAccountingEngine(_auction.highBidder).cancelAuctionedDebtWithSurplus(Math.min(_bid, _totalOnAuctionDebt));
    }

    _auction.highBidder = msg.sender;
    _auction.amountToSell = _amountToBuy;
    _auction.bidExpiry = block.timestamp + _params.bidDuration;

    emit DecreaseSoldAmount({
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
      revert DAH_AuctionNotFinished();
    }

    protocolToken.mint(_auction.highBidder, _auction.amountToSell);
    --activeDebtAuctions;

    emit SettleAuction({
      _id: _id,
      _blockTimestamp: block.timestamp,
      _highBidder: _auction.highBidder,
      _raisedAmount: _auction.bidAmount
    });

    delete _auctions[_id];
  }

  /**
   * @notice Terminate an auction prematurely
   * @param _id ID of the auction to terminate
   */
  function terminateAuctionPrematurely(uint256 _id) external whenDisabled {
    Auction memory _auction = _auctions[_id];
    if (_auction.highBidder == address(0)) revert DAH_HighBidderNotSet();

    safeEngine.createUnbackedDebt({
      _debtDestination: accountingEngine,
      _coinDestination: _auction.highBidder,
      _rad: _auction.bidAmount
    });

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
    else if (_param == 'bidDecrease') _params.bidDecrease = _uint256;
    else if (_param == 'amountSoldIncrease') _params.amountSoldIncrease = _uint256;
    else if (_param == 'bidDuration') _params.bidDuration = _uint256;
    else if (_param == 'totalAuctionLength') _params.totalAuctionLength = _uint256;
    else revert UnrecognizedParam();
  }

  function _validateParameters() internal view override {
    address(protocolToken).assertNonNull();
  }
}

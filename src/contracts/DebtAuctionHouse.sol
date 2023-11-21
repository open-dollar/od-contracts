// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

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

/**
 * @title  DebtAuctionHouse
 * @notice This contract enables the sell of newly minted protocol tokens in exchange for system coins to cover a protocol debt
 */
contract DebtAuctionHouse is Authorizable, Modifiable, Disableable, IDebtAuctionHouse {
  using Encoding for bytes;
  using Assertions for address;

  /// @inheritdoc IDebtAuctionHouse
  bytes32 public constant AUCTION_HOUSE_TYPE = bytes32('DEBT');

  // --- Data ---

  /// @inheritdoc IDebtAuctionHouse
  // solhint-disable-next-line private-vars-leading-underscore
  mapping(uint256 _auctionId => Auction) public _auctions;

  /// @inheritdoc IDebtAuctionHouse
  function auctions(uint256 _id) external view returns (Auction memory _auction) {
    return _auctions[_id];
  }

  /// @inheritdoc IDebtAuctionHouse
  uint256 public auctionsStarted;
  /// @inheritdoc IDebtAuctionHouse
  uint256 public activeDebtAuctions;

  // --- Registry ---

  /// @inheritdoc IDebtAuctionHouse
  ISAFEEngine public safeEngine;
  /// @inheritdoc IDebtAuctionHouse
  IProtocolToken public protocolToken;
  /// @inheritdoc IDebtAuctionHouse
  address public accountingEngine;

  // --- Params ---

  /// @inheritdoc IDebtAuctionHouse
  // solhint-disable-next-line private-vars-leading-underscore
  DebtAuctionHouseParams public _params;

  /// @inheritdoc IDebtAuctionHouse
  function params() external view returns (DebtAuctionHouseParams memory _dahParams) {
    return _params;
  }

  // --- Init ---

  /**
   * @param  _safeEngine Address of the SAFEEngine contract
   * @param  _protocolToken Address of the protocol governance token
   * @param  _dahParams Initial valid DebtAuctionHouse parameters struct
   */
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
   * @dev Sets the accountingEngine state var to the caller's address
   * @inheritdoc Disableable
   */
  function _onContractDisable() internal override {
    accountingEngine = msg.sender;
    delete activeDebtAuctions;
  }

  // --- Auction ---

  /// @inheritdoc IDebtAuctionHouse
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

  /// @inheritdoc IDebtAuctionHouse
  function restartAuction(uint256 _id) external {
    Auction storage _auction = _auctions[_id];
    if (_id == 0 || _id > auctionsStarted) revert DAH_AuctionNeverStarted();
    if (_auction.auctionDeadline > block.timestamp) revert DAH_AuctionNotFinished();
    if (_auction.bidExpiry != 0) revert DAH_BidAlreadyPlaced();
    _auction.amountToSell = (_params.amountSoldIncrease * _auction.amountToSell) / WAD;
    _auction.auctionDeadline = block.timestamp + _params.totalAuctionLength;

    emit RestartAuction({_id: _id, _blockTimestamp: block.timestamp, _auctionDeadline: _auction.auctionDeadline});
  }

  /// @inheritdoc IDebtAuctionHouse
  function decreaseSoldAmount(uint256 _id, uint256 _amountToBuy) external whenEnabled {
    Auction storage _auction = _auctions[_id];
    if (_auction.highBidder == address(0)) revert DAH_HighBidderNotSet();
    if (_auction.bidExpiry <= block.timestamp && _auction.bidExpiry != 0) revert DAH_BidAlreadyExpired();
    if (_auction.auctionDeadline <= block.timestamp) revert DAH_AuctionAlreadyExpired();

    if (_amountToBuy >= _auction.amountToSell) revert DAH_AmountBoughtNotLower();
    if (_params.bidDecrease * _amountToBuy > _auction.amountToSell * WAD) revert DAH_InsufficientDecrease();

    uint256 _bid = _auction.bidAmount;
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

  /// @inheritdoc IDebtAuctionHouse
  function settleAuction(uint256 _id) external whenEnabled {
    Auction memory _auction = _auctions[_id];

    if (_auction.bidExpiry == 0 || (_auction.bidExpiry > block.timestamp && _auction.auctionDeadline > block.timestamp))
    {
      revert DAH_AuctionNotFinished();
    }

    delete _auctions[_id];
    --activeDebtAuctions;

    protocolToken.mint(_auction.highBidder, _auction.amountToSell);

    emit SettleAuction({
      _id: _id,
      _blockTimestamp: block.timestamp,
      _highBidder: _auction.highBidder,
      _raisedAmount: _auction.bidAmount
    });
  }

  /// @inheritdoc IDebtAuctionHouse
  function terminateAuctionPrematurely(uint256 _id) external whenDisabled {
    Auction memory _auction = _auctions[_id];
    delete _auctions[_id];

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
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
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

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    address(protocolToken).assertHasCode();
  }
}

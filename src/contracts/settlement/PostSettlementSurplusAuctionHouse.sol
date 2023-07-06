// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IPostSettlementSurplusAuctionHouse} from '@interfaces/settlement/IPostSettlementSurplusAuctionHouse.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';

import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {Encoding} from '@libraries/Encoding.sol';
import {WAD} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

contract PostSettlementSurplusAuctionHouse is Authorizable, Modifiable, IPostSettlementSurplusAuctionHouse {
  using Encoding for bytes;
  using SafeERC20 for IProtocolToken;
  using Assertions for address;

  bytes32 public constant AUCTION_HOUSE_TYPE = bytes32('SURPLUS');
  bytes32 public constant SURPLUS_AUCTION_TYPE = bytes32('POST-SETTLEMENT');

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
  PostSettlementSAHParams public _params;

  function params() external view returns (PostSettlementSAHParams memory _pssahParams) {
    return _params;
  }

  // --- Init ---
  constructor(
    address _safeEngine,
    address _protocolToken,
    PostSettlementSAHParams memory _pssahParams
  ) Authorizable(msg.sender) validParams {
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
    protocolToken = IProtocolToken(_protocolToken.assertNonNull());

    _params = _pssahParams;
  }

  // --- Auction ---
  /**
   * @notice Start a new surplus auction
   * @param _amountToSell Total amount of system coins to sell (wad)
   * @param _initialBid Initial protocol token bid (rad)
   */
  function startAuction(uint256 _amountToSell, uint256 _initialBid) external isAuthorized returns (uint256 _id) {
    _id = ++auctionsStarted;

    _auctions[_id].bidAmount = _initialBid;
    _auctions[_id].amountToSell = _amountToSell;
    _auctions[_id].highBidder = msg.sender;
    _auctions[_id].auctionDeadline = block.timestamp + _params.totalAuctionLength;

    safeEngine.transferInternalCoins(msg.sender, address(this), _amountToSell);

    emit StartAuction(_id, auctionsStarted, _amountToSell, _initialBid, _auctions[_id].auctionDeadline);
  }

  /**
   * @notice Restart an auction if no bids were submitted for it
   * @param _id ID of the auction to restart
   */
  function restartAuction(uint256 _id) external {
    if (_id == 0 || _id > auctionsStarted) revert PSSAH_AuctionNeverStarted();
    if (_auctions[_id].auctionDeadline > block.timestamp) revert PSSAH_AuctionNotFinished();
    if (_auctions[_id].bidExpiry != 0) revert PSSAH_BidAlreadyPlaced();
    _auctions[_id].auctionDeadline = block.timestamp + _params.totalAuctionLength;
    emit RestartAuction(_id, _auctions[_id].auctionDeadline);
  }

  /**
   * @notice Submit a higher protocol token bid for the same amount of system coins
   * @param _id ID of the auction you want to submit the bid for
   * @param _amountToBuy Amount of system coins to buy (wad)
   * @param _bid New bid submitted (rad)
   */
  function increaseBidSize(uint256 _id, uint256 _amountToBuy, uint256 _bid) external {
    if (_auctions[_id].highBidder == address(0)) revert PSSAH_HighBidderNotSet();
    if (_auctions[_id].bidExpiry <= block.timestamp && _auctions[_id].bidExpiry != 0) revert PSSAH_BidAlreadyExpired();
    if (_auctions[_id].auctionDeadline <= block.timestamp) revert PSSAH_AuctionAlreadyExpired();

    if (_amountToBuy != _auctions[_id].amountToSell) revert PSSAH_AmountsNotMatching();
    if (_bid <= _auctions[_id].bidAmount) revert PSSAH_BidNotHigher();
    if (_bid * WAD < _params.bidIncrease * _auctions[_id].bidAmount) revert PSSAH_InsufficientIncrease();

    if (msg.sender != _auctions[_id].highBidder) {
      protocolToken.safeTransferFrom(msg.sender, _auctions[_id].highBidder, _auctions[_id].bidAmount);
      _auctions[_id].highBidder = msg.sender;
    }
    protocolToken.safeTransferFrom(msg.sender, address(this), _bid - _auctions[_id].bidAmount);

    _auctions[_id].bidAmount = _bid;
    _auctions[_id].bidExpiry = block.timestamp + _params.bidDuration;

    emit IncreaseBidSize(_id, msg.sender, _amountToBuy, _bid, _auctions[_id].bidExpiry);
  }

  /**
   * @notice Settle/finish an auction
   * @param _id ID of the auction to settle
   */
  function settleAuction(uint256 _id) external {
    if (
      _auctions[_id].bidExpiry == 0
        || (_auctions[_id].bidExpiry > block.timestamp && _auctions[_id].auctionDeadline > block.timestamp)
    ) revert PSSAH_AuctionNotFinished();
    safeEngine.transferInternalCoins(address(this), _auctions[_id].highBidder, _auctions[_id].amountToSell);
    protocolToken.burn(_auctions[_id].bidAmount);
    delete _auctions[_id];
    emit SettleAuction(_id);
  }

  // --- Administration ---

  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();

    if (_param == 'bidIncrease') _params.bidIncrease = _uint256;
    else if (_param == 'bidDuration') _params.bidDuration = _uint256;
    else if (_param == 'totalAuctionLength') _params.totalAuctionLength = _uint256;
    else revert UnrecognizedParam();
  }
}

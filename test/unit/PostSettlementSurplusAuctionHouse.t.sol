// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {
  PostSettlementSurplusAuctionHouseForTest,
  IPostSettlementSurplusAuctionHouse
} from '@test/mocks/PostSettlementSurplusAuctionHouseForTest.sol';
import {ICommonSurplusAuctionHouse} from '@interfaces/ICommonSurplusAuctionHouse.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

import {WAD} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  struct SurplusAuction {
    uint256 id;
    uint256 bidAmount;
    uint256 amountToSell;
    address highBidder;
    uint256 bidExpiry;
    uint256 auctionDeadline;
  }

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SafeEngine'));
  IProtocolToken mockProtocolToken = IProtocolToken(mockContract('ProtocolToken'));

  PostSettlementSurplusAuctionHouseForTest postSettlementSurplusAuctionHouse;

  IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams pssahParams = IPostSettlementSurplusAuctionHouse
    .PostSettlementSAHParams({bidIncrease: 1.05e18, bidDuration: 3 hours, totalAuctionLength: 2 days});

  function setUp() public virtual {
    vm.startPrank(deployer);

    postSettlementSurplusAuctionHouse =
      new PostSettlementSurplusAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken), pssahParams);
    label(address(postSettlementSurplusAuctionHouse), 'PostSettlementSurplusAuctionHouse');

    postSettlementSurplusAuctionHouse.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockAuction(SurplusAuction memory _auction) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    postSettlementSurplusAuctionHouse.addAuction(
      _auction.id,
      _auction.bidAmount,
      _auction.amountToSell,
      _auction.highBidder,
      _auction.bidExpiry,
      _auction.auctionDeadline
    );
  }

  function _mockAuctionsStarted(uint256 _auctionsStarted) internal {
    stdstore.target(address(postSettlementSurplusAuctionHouse)).sig(ICommonSurplusAuctionHouse.auctionsStarted.selector)
      .checked_write(_auctionsStarted);
  }

  // params
  function _mockBidIncrease(uint256 _bidIncrease) internal {
    stdstore.target(address(postSettlementSurplusAuctionHouse)).sig(IPostSettlementSurplusAuctionHouse.params.selector)
      .depth(0).checked_write(_bidIncrease);
  }

  function _mockBidDuration(uint256 _bidDuration) internal {
    stdstore.target(address(postSettlementSurplusAuctionHouse)).sig(IPostSettlementSurplusAuctionHouse.params.selector)
      .depth(1).checked_write(_bidDuration);
  }

  function _mockTotalAuctionLength(uint256 _totalAuctionLength) internal {
    stdstore.target(address(postSettlementSurplusAuctionHouse)).sig(IPostSettlementSurplusAuctionHouse.params.selector)
      .depth(2).checked_write(_totalAuctionLength);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_Constants is Base {
  function test_Set_AUCTION_HOUSE_TYPE() public {
    assertEq(postSettlementSurplusAuctionHouse.AUCTION_HOUSE_TYPE(), bytes32('SURPLUS'));
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new PostSettlementSurplusAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken), pssahParams);
  }

  function test_Set_SafeEngine(address _safeEngine) public happyPath {
    vm.assume(_safeEngine != address(0));
    postSettlementSurplusAuctionHouse =
      new PostSettlementSurplusAuctionHouseForTest(_safeEngine, address(mockProtocolToken), pssahParams);

    assertEq(address(postSettlementSurplusAuctionHouse.safeEngine()), _safeEngine);
  }

  function test_Set_ProtocolToken(address _protocolToken) public happyPath mockAsContract(_protocolToken) {
    postSettlementSurplusAuctionHouse =
      new PostSettlementSurplusAuctionHouseForTest(address(mockSafeEngine), _protocolToken, pssahParams);

    assertEq(address(postSettlementSurplusAuctionHouse.protocolToken()), _protocolToken);
  }

  function test_Set_PSSAH_Params(IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams memory _pssahParams)
    public
    happyPath
  {
    postSettlementSurplusAuctionHouse =
      new PostSettlementSurplusAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken), _pssahParams);

    assertEq(abi.encode(postSettlementSurplusAuctionHouse.params()), abi.encode(_pssahParams));
  }

  function test_Revert_Null_SafeEngine() public {
    vm.expectRevert(Assertions.NullAddress.selector);

    new PostSettlementSurplusAuctionHouseForTest(address(0), address(mockProtocolToken), pssahParams);
  }

  function test_Revert_Null_ProtocolToken() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new PostSettlementSurplusAuctionHouseForTest(address(mockSafeEngine), address(0), pssahParams);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_StartAuction is Base {
  event StartAuction(
    uint256 indexed _id,
    address indexed _auctioneer,
    uint256 _blockTimestamp,
    uint256 _amountToSell,
    uint256 _amountToRaise,
    uint256 _auctionDeadline
  );

  modifier happyPath(uint256 _auctionsStarted, uint256 _totalAuctionLength) {
    vm.startPrank(authorizedAccount);

    _assumeHappyPath(_auctionsStarted, _totalAuctionLength);
    _mockValues(_auctionsStarted, _totalAuctionLength);
    _;
  }

  function _assumeHappyPath(uint256 _auctionsStarted, uint256 _totalAuctionLength) internal view {
    vm.assume(_auctionsStarted < type(uint256).max);
    vm.assume(notOverflowAdd(block.timestamp, _totalAuctionLength));
  }

  function _mockValues(uint256 _auctionsStarted, uint256 _totalAuctionLength) internal {
    _mockAuctionsStarted(_auctionsStarted);
    _mockTotalAuctionLength(_totalAuctionLength);
  }

  function test_Revert_Unauthorized(uint256 _amountToSell, uint256 _initialBid) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Revert_Overflow(uint256 _amountToSell, uint256 _initialBid) public {
    vm.startPrank(authorizedAccount);

    _mockValues(type(uint256).max, 0);

    vm.expectRevert();

    postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Set_AuctionsStarted(
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint256 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _totalAuctionLength) {
    postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid);

    assertEq(postSettlementSurplusAuctionHouse.auctionsStarted(), _auctionsStarted + 1);
  }

  function test_Set_Auctions(
    uint256 _amountToSellFuzzed,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint256 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _totalAuctionLength) {
    postSettlementSurplusAuctionHouse.startAuction(_amountToSellFuzzed, _initialBid);

    IPostSettlementSurplusAuctionHouse.Auction memory _auction =
      postSettlementSurplusAuctionHouse.auctions(_auctionsStarted + 1);
    assertEq(_auction.bidAmount, _initialBid);
    assertEq(_auction.amountToSell, _amountToSellFuzzed);
    assertEq(_auction.highBidder, authorizedAccount);
    assertEq(_auction.bidExpiry, 0);
    assertEq(_auction.auctionDeadline, block.timestamp + _totalAuctionLength);
  }

  function test_Call_SafeEngine_TransferInternalCoins(
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint256 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _totalAuctionLength) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.transferInternalCoins,
        (authorizedAccount, address(postSettlementSurplusAuctionHouse), _amountToSell)
      ),
      1
    );

    postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Emit_StartAuction(
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint256 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _totalAuctionLength) {
    vm.expectEmit();
    emit StartAuction(
      _auctionsStarted + 1,
      authorizedAccount,
      block.timestamp,
      _amountToSell,
      _initialBid,
      block.timestamp + _totalAuctionLength
    );

    postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Return_Id(
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint256 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _totalAuctionLength) {
    assertEq(postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid), _auctionsStarted + 1);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_RestartAuction is Base {
  event RestartAuction(uint256 indexed _id, uint256 _blockTimestamp, uint256 _auctionDeadline);

  modifier happyPath(SurplusAuction memory _auction, uint256 _auctionsStarted, uint256 _totalAuctionLength) {
    _assumeHappyPath(_auction, _auctionsStarted, _totalAuctionLength);
    _mockValues(_auction, _auctionsStarted, _totalAuctionLength);
    _;
  }

  function _assumeHappyPath(
    SurplusAuction memory _auction,
    uint256 _auctionsStarted,
    uint256 _totalAuctionLength
  ) internal view {
    vm.assume(_auction.id > 0 && _auction.id <= _auctionsStarted);
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(_auction.bidExpiry == 0);
    vm.assume(notOverflowAdd(block.timestamp, _totalAuctionLength));
  }

  function _mockValues(SurplusAuction memory _auction, uint256 _auctionsStarted, uint256 _totalAuctionLength) internal {
    _mockAuction(_auction);
    _mockAuctionsStarted(_auctionsStarted);
    _mockTotalAuctionLength(_totalAuctionLength);
  }

  function test_Revert_AuctionNeverStarted_0(SurplusAuction memory _auction) public {
    vm.assume(_auction.id == 0);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(ICommonSurplusAuctionHouse.SAH_AuctionNeverStarted.selector);

    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_AuctionNeverStarted_1(SurplusAuction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id > _auctionsStarted);

    _mockValues(_auction, _auctionsStarted, 0);

    vm.expectRevert(ICommonSurplusAuctionHouse.SAH_AuctionNeverStarted.selector);

    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_NotFinished(SurplusAuction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id > 0 && _auction.id <= _auctionsStarted);
    vm.assume(_auction.auctionDeadline > block.timestamp);

    _mockValues(_auction, _auctionsStarted, 0);

    vm.expectRevert(ICommonSurplusAuctionHouse.SAH_AuctionNotFinished.selector);

    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_BidAlreadyPlaced(SurplusAuction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id > 0 && _auction.id <= _auctionsStarted);
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(_auction.bidExpiry != 0);

    _mockValues(_auction, _auctionsStarted, 0);

    vm.expectRevert(ICommonSurplusAuctionHouse.SAH_BidAlreadyPlaced.selector);

    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Set_Auctions_AuctionDeadline(
    SurplusAuction memory _auction,
    uint256 _auctionsStarted,
    uint256 _totalAuctionLength
  ) public happyPath(_auction, _auctionsStarted, _totalAuctionLength) {
    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);

    assertEq(
      postSettlementSurplusAuctionHouse.auctions(_auction.id).auctionDeadline, block.timestamp + _totalAuctionLength
    );
  }

  function test_Emit_RestartAuction(
    SurplusAuction memory _auction,
    uint256 _auctionsStarted,
    uint256 _totalAuctionLength
  ) public happyPath(_auction, _auctionsStarted, _totalAuctionLength) {
    vm.expectEmit();
    emit RestartAuction(_auction.id, block.timestamp, block.timestamp + _totalAuctionLength);

    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_IncreaseBidSize is Base {
  event IncreaseBidSize(
    uint256 indexed _id,
    address _bidder,
    uint256 _blockTimestamp,
    uint256 _raisedAmount,
    uint256 _soldAmount,
    uint256 _bidExpiry
  );

  modifier happyPath(SurplusAuction memory _auction, uint256 _bid, uint256 _bidIncrease, uint256 _bidDuration) {
    vm.startPrank(user);

    _assumeHappyPath(_auction, _bid, _bidIncrease, _bidDuration);
    _mockValues(_auction, _bidIncrease, _bidDuration);
    _;
  }

  function _assumeHappyPath(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint256 _bidDuration
  ) internal view {
    vm.assume(_auction.highBidder != address(0) && _auction.highBidder != user);
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_bid > _auction.bidAmount);
    vm.assume(notOverflowMul(_bid, WAD));
    vm.assume(notOverflowMul(_bidIncrease, _auction.bidAmount));
    vm.assume(_bid * WAD >= _bidIncrease * _auction.bidAmount);
    vm.assume(notOverflowAdd(block.timestamp, _bidDuration));
  }

  function _mockValues(SurplusAuction memory _auction, uint256 _bidIncrease, uint256 _bidDuration) internal {
    _mockAuction(_auction);
    _mockBidIncrease(_bidIncrease);
    _mockBidDuration(_bidDuration);
  }

  function test_Revert_HighBidderNotSet(SurplusAuction memory _auction, uint256 _bid) public {
    _auction.highBidder = address(0);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(ICommonSurplusAuctionHouse.SAH_HighBidderNotSet.selector);

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _bid);
  }

  function test_Revert_BidAlreadyExpired(SurplusAuction memory _auction, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry != 0 && _auction.bidExpiry <= block.timestamp);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(ICommonSurplusAuctionHouse.SAH_BidAlreadyExpired.selector);

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _bid);
  }

  function test_Revert_AuctionAlreadyExpired(SurplusAuction memory _auction, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline <= block.timestamp);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(ICommonSurplusAuctionHouse.SAH_AuctionAlreadyExpired.selector);

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _bid);
  }

  function test_Revert_BidNotHigher(SurplusAuction memory _auction, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_bid <= _auction.bidAmount);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(ICommonSurplusAuctionHouse.SAH_BidNotHigher.selector);

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _bid);
  }

  function test_Revert_InsufficientIncrease(SurplusAuction memory _auction, uint256 _bid, uint256 _bidIncrease) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_bid > _auction.bidAmount);
    vm.assume(notOverflowMul(_bid, WAD));
    vm.assume(notOverflowMul(_bidIncrease, _auction.bidAmount));
    vm.assume(_bid * WAD < _bidIncrease * _auction.bidAmount);

    _mockValues(_auction, _bidIncrease, 0);

    vm.expectRevert(ICommonSurplusAuctionHouse.SAH_InsufficientIncrease.selector);

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _bid);
  }

  function test_Call_ProtocolToken_Move_HighBidder(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint256 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    uint256 _payment = _bid;

    // if the user was the previous high bidder they only need to pay the increment
    if (_auction.bidExpiry != 0) {
      _payment = _bid - _auction.bidAmount;
    }

    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeCall(mockProtocolToken.transferFrom, (_auction.highBidder, _auction.highBidder, _auction.bidAmount)),
      0
    );
    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeCall(
        mockProtocolToken.transferFrom, (_auction.highBidder, address(postSettlementSurplusAuctionHouse), _payment)
      ),
      1
    );

    changePrank(_auction.highBidder);
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _bid);
  }

  function test_Call_ProtocolToken_Move_NotHighBidder(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint256 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    uint256 _payment = _bid;
    uint256 _refund;

    // if the user was not the previous high bidder we refund the previous high bidder
    if (_auction.bidExpiry != 0) {
      _refund = _auction.bidAmount;
      _payment = _bid - _auction.bidAmount;
    }

    // If there was no initial bidAmount then this would transfer 0 tokens, so it's not called
    if (_refund != 0) {
      vm.expectCall(
        address(mockProtocolToken),
        abi.encodeCall(mockProtocolToken.transferFrom, (user, _auction.highBidder, _refund)),
        1
      );
    }
    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeCall(mockProtocolToken.transferFrom, (user, address(postSettlementSurplusAuctionHouse), _payment)),
      1
    );

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _bid);
  }

  function test_Set_Auctions_HighBidder_0(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint256 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    changePrank(_auction.highBidder);
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _bid);

    assertEq(postSettlementSurplusAuctionHouse.auctions(_auction.id).highBidder, _auction.highBidder);
  }

  function test_Set_Auctions_HighBidder_1(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint256 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _bid);

    assertEq(postSettlementSurplusAuctionHouse.auctions(_auction.id).highBidder, user);
  }

  function test_Set_Auctions_BidAmount(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint256 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _bid);

    assertEq(postSettlementSurplusAuctionHouse.auctions(_auction.id).bidAmount, _bid);
  }

  function test_Set_Auctions_BidExpiry(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint256 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _bid);

    assertEq(postSettlementSurplusAuctionHouse.auctions(_auction.id).bidExpiry, block.timestamp + _bidDuration);
  }

  function test_Emit_IncreaseBidSize(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint256 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    vm.expectEmit();
    emit IncreaseBidSize(
      _auction.id, user, block.timestamp, _bid, _auction.amountToSell, block.timestamp + _bidDuration
    );

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _bid);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_SettleAuction is Base {
  event SettleAuction(uint256 indexed _id, uint256 _blockTimestamp, address _highBidder, uint256 _raisedAmount);

  modifier happyPath(SurplusAuction memory _auction) {
    _assumeHappyPath(_auction);
    _mockValues(_auction);
    _;
  }

  function _assumeHappyPath(SurplusAuction memory _auction) internal view {
    vm.assume(
      _auction.bidExpiry != 0 && (_auction.bidExpiry < block.timestamp || _auction.auctionDeadline < block.timestamp)
    );
  }

  function _mockValues(SurplusAuction memory _auction) internal {
    _mockAuction(_auction);
  }

  function test_Revert_NotFinished_0(SurplusAuction memory _auction) public {
    vm.assume(_auction.bidExpiry == 0);

    _mockValues(_auction);

    vm.expectRevert(ICommonSurplusAuctionHouse.SAH_AuctionNotFinished.selector);

    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Revert_NotFinished_1(SurplusAuction memory _auction) public {
    vm.assume(_auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);

    _mockValues(_auction);

    vm.expectRevert(ICommonSurplusAuctionHouse.SAH_AuctionNotFinished.selector);

    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Call_SafeEngine_TransferInternalCoins(SurplusAuction memory _auction) public happyPath(_auction) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.transferInternalCoins,
        (address(postSettlementSurplusAuctionHouse), _auction.highBidder, _auction.amountToSell)
      ),
      1
    );

    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Call_ProtocolToken_Burn(SurplusAuction memory _auction) public happyPath(_auction) {
    vm.expectCall(address(mockProtocolToken), abi.encodeWithSignature('burn(uint256)', _auction.bidAmount), 1);

    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Set_Auctions(SurplusAuction memory _auction) public happyPath(_auction) {
    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);

    IPostSettlementSurplusAuctionHouse.Auction memory __auction =
      postSettlementSurplusAuctionHouse.auctions(_auction.id);
    assertEq(__auction.bidAmount, 0);
    assertEq(__auction.amountToSell, 0);
    assertEq(__auction.highBidder, address(0));
    assertEq(__auction.bidExpiry, 0);
    assertEq(__auction.auctionDeadline, 0);
  }

  function test_Emit_SettleAuction(SurplusAuction memory _auction) public happyPath(_auction) {
    vm.expectEmit();
    emit SettleAuction(_auction.id, block.timestamp, _auction.highBidder, _auction.bidAmount);

    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_ModifyParameters is Base {
  event ModifyParameters(bytes32 indexed _param, bytes32 indexed _cType, bytes _data);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_Parameters(IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams memory _fuzz)
    public
    happyPath
  {
    postSettlementSurplusAuctionHouse.modifyParameters('bidIncrease', abi.encode(_fuzz.bidIncrease));
    postSettlementSurplusAuctionHouse.modifyParameters('bidDuration', abi.encode(_fuzz.bidDuration));
    postSettlementSurplusAuctionHouse.modifyParameters('totalAuctionLength', abi.encode(_fuzz.totalAuctionLength));

    IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams memory _params =
      postSettlementSurplusAuctionHouse.params();

    assertEq(abi.encode(_params), abi.encode(_fuzz));
  }

  function test_Set_ProtocolToken(address _protocolToken) public happyPath mockAsContract(_protocolToken) {
    postSettlementSurplusAuctionHouse.modifyParameters('protocolToken', abi.encode(_protocolToken));

    assertEq(address(postSettlementSurplusAuctionHouse.protocolToken()), _protocolToken);
  }

  function test_Revert_ProtocolToken_NullAddress() public {
    vm.startPrank(authorizedAccount);
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    postSettlementSurplusAuctionHouse.modifyParameters('protocolToken', abi.encode(0));
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);
    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    postSettlementSurplusAuctionHouse.modifyParameters('unrecognizedParam', _data);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {
  PostSettlementSurplusAuctionHouseForTest,
  IPostSettlementSurplusAuctionHouse
} from '@contracts/for-test/PostSettlementSurplusAuctionHouseForTest.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IToken} from '@interfaces/external/IToken.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable, GLOBAL_PARAM} from '@interfaces/utils/IModifiable.sol';
import {WAD} from '@libraries/Math.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  struct SurplusAuction {
    uint256 id;
    uint256 bidAmount;
    uint256 amountToSell;
    address highBidder;
    uint48 bidExpiry;
    uint48 auctionDeadline;
  }

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SafeEngine'));
  IToken mockProtocolToken = IToken(mockContract('ProtocolToken'));

  PostSettlementSurplusAuctionHouseForTest postSettlementSurplusAuctionHouse;

  function setUp() public virtual {
    vm.startPrank(deployer);

    postSettlementSurplusAuctionHouse =
      new PostSettlementSurplusAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken));
    label(address(postSettlementSurplusAuctionHouse), 'PostSettlementSurplusAuctionHouse');

    postSettlementSurplusAuctionHouse.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockAuction(SurplusAuction memory _auction) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    postSettlementSurplusAuctionHouse.addBid(
      _auction.id,
      _auction.bidAmount,
      _auction.amountToSell,
      _auction.highBidder,
      _auction.bidExpiry,
      _auction.auctionDeadline
    );
  }

  function _mockAuctionsStarted(uint256 _auctionsStarted) internal {
    stdstore.target(address(postSettlementSurplusAuctionHouse)).sig(
      IPostSettlementSurplusAuctionHouse.auctionsStarted.selector
    ).checked_write(_auctionsStarted);
  }

  // params
  function _mockBidIncrease(uint256 _bidIncrease) internal {
    stdstore.target(address(postSettlementSurplusAuctionHouse)).sig(IPostSettlementSurplusAuctionHouse.params.selector)
      .depth(0).checked_write(_bidIncrease);
  }

  function _mockBidDuration(uint48 _bidDuration) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    postSettlementSurplusAuctionHouse.setBidDuration(_bidDuration);
  }

  function _mockTotalAuctionLength(uint48 _totalAuctionLength) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    postSettlementSurplusAuctionHouse.setTotalAuctionLength(_totalAuctionLength);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_Constants is Base {
  function test_Set_AUCTION_HOUSE_TYPE() public {
    assertEq(postSettlementSurplusAuctionHouse.AUCTION_HOUSE_TYPE(), bytes32('SURPLUS'));
  }

  function test_Set_SURPLUS_AUCTION_TYPE() public {
    assertEq(postSettlementSurplusAuctionHouse.SURPLUS_AUCTION_TYPE(), bytes32('POST-SETTLEMENT'));
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    expectEmitNoIndex();
    emit AddAuthorization(user);

    postSettlementSurplusAuctionHouse =
      new PostSettlementSurplusAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken));
  }

  function test_Set_SafeEngine(address _safeEngine) public happyPath {
    postSettlementSurplusAuctionHouse =
      new PostSettlementSurplusAuctionHouseForTest(_safeEngine, address(mockProtocolToken));

    assertEq(address(postSettlementSurplusAuctionHouse.safeEngine()), _safeEngine);
  }

  function test_Set_ProtocolToken(address _protocolToken) public happyPath {
    postSettlementSurplusAuctionHouse =
      new PostSettlementSurplusAuctionHouseForTest(address(mockSafeEngine), _protocolToken);

    assertEq(address(postSettlementSurplusAuctionHouse.protocolToken()), _protocolToken);
  }

  function test_Set_BidIncrease() public happyPath {
    assertEq(postSettlementSurplusAuctionHouse.params().bidIncrease, 1.05e18);
  }

  function test_Set_BidDuration() public happyPath {
    assertEq(postSettlementSurplusAuctionHouse.params().bidDuration, 3 hours);
  }

  function test_Set_TotalAuctionLength() public happyPath {
    assertEq(postSettlementSurplusAuctionHouse.params().totalAuctionLength, 2 days);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_StartAuction is Base {
  event StartAuction(
    uint256 indexed _id, uint256 _auctionsStarted, uint256 _amountToSell, uint256 _initialBid, uint256 _auctionDeadline
  );

  modifier happyPath(uint256 _auctionsStarted, uint48 _totalAuctionLength) {
    vm.startPrank(authorizedAccount);

    _assumeHappyPath(_auctionsStarted, _totalAuctionLength);
    _mockValues(_auctionsStarted, _totalAuctionLength);
    _;
  }

  function _assumeHappyPath(uint256 _auctionsStarted, uint48 _totalAuctionLength) internal view {
    vm.assume(_auctionsStarted < type(uint256).max);
    vm.assume(notOverflowAddUint48(uint48(block.timestamp), _totalAuctionLength));
  }

  function _mockValues(uint256 _auctionsStarted, uint48 _totalAuctionLength) internal {
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
    uint48 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _totalAuctionLength) {
    postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid);

    assertEq(postSettlementSurplusAuctionHouse.auctionsStarted(), _auctionsStarted + 1);
  }

  function test_Set_Bids(
    uint256 _amountToSellFuzzed,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint48 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _totalAuctionLength) {
    postSettlementSurplusAuctionHouse.startAuction(_amountToSellFuzzed, _initialBid);

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline) =
      postSettlementSurplusAuctionHouse.bids(_auctionsStarted + 1);

    assertEq(_bidAmount, _initialBid);
    assertEq(_amountToSell, _amountToSellFuzzed);
    assertEq(_highBidder, authorizedAccount);
    assertEq(_bidExpiry, 0);
    assertEq(_auctionDeadline, block.timestamp + _totalAuctionLength);
  }

  function test_Call_SafeEngine_TransferInternalCoins(
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint48 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _totalAuctionLength) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.transferInternalCoins,
        (authorizedAccount, address(postSettlementSurplusAuctionHouse), _amountToSell)
      )
    );

    postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Emit_StartAuction(
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint48 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _totalAuctionLength) {
    expectEmitNoIndex();
    emit StartAuction(
      _auctionsStarted + 1, _auctionsStarted + 1, _amountToSell, _initialBid, block.timestamp + _totalAuctionLength
    );

    postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Return_Id(
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint48 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _totalAuctionLength) {
    assertEq(postSettlementSurplusAuctionHouse.startAuction(_amountToSell, _initialBid), _auctionsStarted + 1);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_RestartAuction is Base {
  event RestartAuction(uint256 indexed _id, uint256 _auctionDeadline);

  modifier happyPath(SurplusAuction memory _auction, uint256 _auctionsStarted, uint48 _totalAuctionLength) {
    _assumeHappyPath(_auction, _auctionsStarted, _totalAuctionLength);
    _mockValues(_auction, _auctionsStarted, _totalAuctionLength);
    _;
  }

  function _assumeHappyPath(
    SurplusAuction memory _auction,
    uint256 _auctionsStarted,
    uint48 _totalAuctionLength
  ) internal view {
    vm.assume(_auction.id > 0 && _auction.id <= _auctionsStarted);
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(_auction.bidExpiry == 0);
    vm.assume(notOverflowAddUint48(uint48(block.timestamp), _totalAuctionLength));
  }

  function _mockValues(SurplusAuction memory _auction, uint256 _auctionsStarted, uint48 _totalAuctionLength) internal {
    _mockAuction(_auction);
    _mockAuctionsStarted(_auctionsStarted);
    _mockTotalAuctionLength(_totalAuctionLength);
  }

  function test_Revert_AuctionNeverStarted_0(SurplusAuction memory _auction) public {
    vm.assume(_auction.id == 0);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(IPostSettlementSurplusAuctionHouse.PSSAH_AuctionNeverStarted.selector);

    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_AuctionNeverStarted_1(SurplusAuction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id > _auctionsStarted);

    _mockValues(_auction, _auctionsStarted, 0);

    vm.expectRevert(IPostSettlementSurplusAuctionHouse.PSSAH_AuctionNeverStarted.selector);

    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_NotFinished(SurplusAuction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id > 0 && _auction.id <= _auctionsStarted);
    vm.assume(_auction.auctionDeadline > block.timestamp);

    _mockValues(_auction, _auctionsStarted, 0);

    vm.expectRevert(IPostSettlementSurplusAuctionHouse.PSSAH_AuctionNotFinished.selector);

    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_BidAlreadyPlaced(SurplusAuction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id > 0 && _auction.id <= _auctionsStarted);
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(_auction.bidExpiry != 0);

    _mockValues(_auction, _auctionsStarted, 0);

    vm.expectRevert(IPostSettlementSurplusAuctionHouse.PSSAH_BidAlreadyPlaced.selector);

    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Set_Bids_AuctionDeadline(
    SurplusAuction memory _auction,
    uint256 _auctionsStarted,
    uint48 _totalAuctionLength
  ) public happyPath(_auction, _auctionsStarted, _totalAuctionLength) {
    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);

    (,,,, uint48 _auctionDeadline) = postSettlementSurplusAuctionHouse.bids(_auction.id);

    assertEq(_auctionDeadline, block.timestamp + _totalAuctionLength);
  }

  function test_Emit_RestartAuction(
    SurplusAuction memory _auction,
    uint256 _auctionsStarted,
    uint48 _totalAuctionLength
  ) public happyPath(_auction, _auctionsStarted, _totalAuctionLength) {
    expectEmitNoIndex();
    emit RestartAuction(_auction.id, block.timestamp + _totalAuctionLength);

    postSettlementSurplusAuctionHouse.restartAuction(_auction.id);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_IncreaseBidSize is Base {
  event IncreaseBidSize(
    uint256 indexed _id, address _highBidder, uint256 _amountToBuy, uint256 _bid, uint256 _bidExpiry
  );

  modifier happyPath(SurplusAuction memory _auction, uint256 _bid, uint256 _bidIncrease, uint48 _bidDuration) {
    vm.startPrank(user);

    _assumeHappyPath(_auction, _bid, _bidIncrease, _bidDuration);
    _mockValues(_auction, _bidIncrease, _bidDuration);
    _;
  }

  function _assumeHappyPath(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint48 _bidDuration
  ) internal view {
    vm.assume(_auction.highBidder != address(0) && _auction.highBidder != user);
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_bid > _auction.bidAmount);
    vm.assume(notOverflowMul(_bid, WAD));
    vm.assume(notOverflowMul(_bidIncrease, _auction.bidAmount));
    vm.assume(_bid * WAD >= _bidIncrease * _auction.bidAmount);
    vm.assume(notOverflowAddUint48(uint48(block.timestamp), _bidDuration));
  }

  function _mockValues(SurplusAuction memory _auction, uint256 _bidIncrease, uint48 _bidDuration) internal {
    _mockAuction(_auction);
    _mockBidIncrease(_bidIncrease);
    _mockBidDuration(_bidDuration);
  }

  function test_Revert_HighBidderNotSet(SurplusAuction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    _auction.highBidder = address(0);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(IPostSettlementSurplusAuctionHouse.PSSAH_HighBidderNotSet.selector);

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_BidAlreadyExpired(SurplusAuction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry != 0 && _auction.bidExpiry <= block.timestamp);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(IPostSettlementSurplusAuctionHouse.PSSAH_BidAlreadyExpired.selector);

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_AuctionAlreadyExpired(SurplusAuction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline <= block.timestamp);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(IPostSettlementSurplusAuctionHouse.PSSAH_AuctionAlreadyExpired.selector);

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_AmountsNotMatching(SurplusAuction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_auction.amountToSell != _amountToBuy);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(IPostSettlementSurplusAuctionHouse.PSSAH_AmountsNotMatching.selector);

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_BidNotHigher(SurplusAuction memory _auction, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_bid <= _auction.bidAmount);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(IPostSettlementSurplusAuctionHouse.PSSAH_BidNotHigher.selector);

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
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

    vm.expectRevert(IPostSettlementSurplusAuctionHouse.PSSAH_InsufficientIncrease.selector);

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }

  function test_Call_ProtocolToken_Move_0(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint48 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeCall(
        mockProtocolToken.move,
        (_auction.highBidder, address(postSettlementSurplusAuctionHouse), _bid - _auction.bidAmount)
      )
    );

    changePrank(_auction.highBidder);
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }

  function testFail_Call_ProtocolToken_Move_0(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint48 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeCall(mockProtocolToken.move, (_auction.highBidder, _auction.highBidder, _auction.bidAmount))
    );

    changePrank(_auction.highBidder);
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }

  function test_Call_ProtocolToken_Move_1(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint48 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeCall(mockProtocolToken.move, (user, _auction.highBidder, _auction.bidAmount))
    );
    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeCall(
        mockProtocolToken.move, (user, address(postSettlementSurplusAuctionHouse), _bid - _auction.bidAmount)
      )
    );

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }

  function test_Set_Bids_HighBidder_0(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint48 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    changePrank(_auction.highBidder);
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (,, address _highBidder,,) = postSettlementSurplusAuctionHouse.bids(_auction.id);

    assertEq(_highBidder, _auction.highBidder);
  }

  function test_Set_Bids_HighBidder_1(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint48 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (,, address _highBidder,,) = postSettlementSurplusAuctionHouse.bids(_auction.id);

    assertEq(_highBidder, user);
  }

  function test_Set_Bids_BidAmount(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint48 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (uint256 _bidAmount,,,,) = postSettlementSurplusAuctionHouse.bids(_auction.id);

    assertEq(_bidAmount, _bid);
  }

  function test_Set_Bids_BidExpiry(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint48 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (,,, uint48 _bidExpiry,) = postSettlementSurplusAuctionHouse.bids(_auction.id);

    assertEq(_bidExpiry, block.timestamp + _bidDuration);
  }

  function test_Emit_IncreaseBidSize(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint48 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    expectEmitNoIndex();
    emit IncreaseBidSize(_auction.id, user, _auction.amountToSell, _bid, block.timestamp + _bidDuration);

    postSettlementSurplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_SettleAuction is Base {
  event SettleAuction(uint256 indexed _id);

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

    vm.expectRevert(IPostSettlementSurplusAuctionHouse.PSSAH_AuctionNotFinished.selector);

    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Revert_NotFinished_1(SurplusAuction memory _auction) public {
    vm.assume(_auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);

    _mockValues(_auction);

    vm.expectRevert(IPostSettlementSurplusAuctionHouse.PSSAH_AuctionNotFinished.selector);

    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Call_SafeEngine_TransferInternalCoins(SurplusAuction memory _auction) public happyPath(_auction) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.transferInternalCoins,
        (address(postSettlementSurplusAuctionHouse), _auction.highBidder, _auction.amountToSell)
      )
    );

    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Call_ProtocolToken_Burn(SurplusAuction memory _auction) public happyPath(_auction) {
    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeWithSignature('burn(address,uint256)', address(postSettlementSurplusAuctionHouse), _auction.bidAmount)
    );

    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Set_Bids(SurplusAuction memory _auction) public happyPath(_auction) {
    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline) =
      postSettlementSurplusAuctionHouse.bids(_auction.id);

    assertEq(_bidAmount, 0);
    assertEq(_amountToSell, 0);
    assertEq(_highBidder, address(0));
    assertEq(_bidExpiry, 0);
    assertEq(_auctionDeadline, 0);
  }

  function test_Emit_SettleAuction(SurplusAuction memory _auction) public happyPath(_auction) {
    expectEmitNoIndex();
    emit SettleAuction(_auction.id);

    postSettlementSurplusAuctionHouse.settleAuction(_auction.id);
  }
}

contract Unit_PostSettlementSurplusAuctionHouse_ModifyParameters is Base {
  event ModifyParameters(bytes32 indexed _param, bytes32 indexed _cType, bytes _data);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized(bytes32 _param, bytes memory _data) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    postSettlementSurplusAuctionHouse.modifyParameters(_param, _data);
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

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    postSettlementSurplusAuctionHouse.modifyParameters('unrecognizedParam', _data);
  }

  function test_Emit_ModifyParameters(uint256 _bidIncrease) public happyPath {
    expectEmitNoIndex();
    emit ModifyParameters('bidIncrease', GLOBAL_PARAM, abi.encode(_bidIncrease));

    postSettlementSurplusAuctionHouse.modifyParameters('bidIncrease', abi.encode(_bidIncrease));
  }
}

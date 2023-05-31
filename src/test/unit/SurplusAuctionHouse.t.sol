// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {SurplusAuctionHouseForTest, ISurplusAuctionHouse} from '@contracts/for-test/SurplusAuctionHouseForTest.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IToken} from '@interfaces/external/IToken.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable, GLOBAL_PARAM} from '@interfaces/utils/IModifiable.sol';
import {Math, WAD, HUNDRED} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';
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

  SurplusAuctionHouseForTest surplusAuctionHouse;

  uint256 constant RECYCLING_PERCENTAGE = 50;

  // SurplusAuctionHouse storage
  address protocolTokenBidReceiver = newAddress();

  function setUp() public virtual {
    vm.startPrank(deployer);

    surplusAuctionHouse =
      new SurplusAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken), RECYCLING_PERCENTAGE);
    label(address(surplusAuctionHouse), 'SurplusAuctionHouse');

    surplusAuctionHouse.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockCoinBalance(address _coinAddress, uint256 _coinBalance) internal {
    vm.mockCall(
      address(mockSafeEngine), abi.encodeCall(mockSafeEngine.coinBalance, (_coinAddress)), abi.encode(_coinBalance)
    );
  }

  function _mockContractEnabled(uint256 _contractEnabled) internal {
    stdstore.target(address(surplusAuctionHouse)).sig(IDisableable.contractEnabled.selector).checked_write(
      _contractEnabled
    );
  }

  function _mockAuction(SurplusAuction memory _auction) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    surplusAuctionHouse.addBid(
      _auction.id,
      _auction.bidAmount,
      _auction.amountToSell,
      _auction.highBidder,
      _auction.bidExpiry,
      _auction.auctionDeadline
    );
  }

  function _mockAuctionsStarted(uint256 _auctionsStarted) internal {
    stdstore.target(address(surplusAuctionHouse)).sig(ISurplusAuctionHouse.auctionsStarted.selector).checked_write(
      _auctionsStarted
    );
  }

  function _mockProtocolTokenBidReceiver(address _protocolTokenBidReceiver) internal {
    stdstore.target(address(surplusAuctionHouse)).sig(ISurplusAuctionHouse.protocolTokenBidReceiver.selector)
      .checked_write(_protocolTokenBidReceiver);
  }

  // params
  function _mockBidIncrease(uint256 _bidIncrease) internal {
    stdstore.target(address(surplusAuctionHouse)).sig(ISurplusAuctionHouse.params.selector).depth(0).checked_write(
      _bidIncrease
    );
  }

  function _mockBidDuration(uint48 _bidDuration) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    surplusAuctionHouse.setBidDuration(_bidDuration);
  }

  function _mockTotalAuctionLength(uint48 _totalAuctionLength) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    surplusAuctionHouse.setTotalAuctionLength(_totalAuctionLength);
  }

  function _mockRecyclingPercentage(uint256 _recyclingPercentage) internal {
    stdstore.target(address(surplusAuctionHouse)).sig(ISurplusAuctionHouse.params.selector).depth(3).checked_write(
      _recyclingPercentage
    );
  }
}

contract Unit_SurplusAuctionHouse_Constants is Base {
  function test_Set_AUCTION_HOUSE_TYPE() public {
    assertEq(surplusAuctionHouse.AUCTION_HOUSE_TYPE(), bytes32('SURPLUS'));
  }

  function test_Set_SURPLUS_AUCTION_TYPE() public {
    assertEq(surplusAuctionHouse.SURPLUS_AUCTION_TYPE(), bytes32('MIXED-STRAT'));
  }
}

contract Unit_SurplusAuctionHouse_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    expectEmitNoIndex();
    emit AddAuthorization(user);

    surplusAuctionHouse =
      new SurplusAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken), RECYCLING_PERCENTAGE);
  }

  function test_Set_ContractEnabled() public happyPath {
    assertEq(surplusAuctionHouse.contractEnabled(), 1);
  }

  function test_Set_SafeEngine(address _safeEngine) public happyPath {
    surplusAuctionHouse = new SurplusAuctionHouseForTest(_safeEngine, address(mockProtocolToken), RECYCLING_PERCENTAGE);

    assertEq(address(surplusAuctionHouse.safeEngine()), _safeEngine);
  }

  function test_Set_ProtocolToken(address _protocolToken) public happyPath {
    surplusAuctionHouse = new SurplusAuctionHouseForTest(address(mockSafeEngine), _protocolToken, RECYCLING_PERCENTAGE);

    assertEq(address(surplusAuctionHouse.protocolToken()), _protocolToken);
  }

  function test_Set_BidIncrease() public happyPath {
    assertEq(surplusAuctionHouse.params().bidIncrease, 1.05e18);
  }

  function test_Set_BidDuration() public happyPath {
    assertEq(surplusAuctionHouse.params().bidDuration, 3 hours);
  }

  function test_Set_TotalAuctionLength() public happyPath {
    assertEq(surplusAuctionHouse.params().totalAuctionLength, 2 days);
  }

  function test_Set_RecyclingPercentage(uint256 _recyclingPercentage) public happyPath {
    surplusAuctionHouse =
      new SurplusAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken), _recyclingPercentage);

    assertEq(surplusAuctionHouse.params().recyclingPercentage, _recyclingPercentage);
  }
}

contract Unit_SurplusAuctionHouse_DisableContract is Base {
  event DisableContract();

  modifier happyPath(uint256 _coinBalance) {
    vm.startPrank(authorizedAccount);

    _mockValues(_coinBalance);
    _;
  }

  function _mockValues(uint256 _coinBalance) internal {
    _mockCoinBalance(address(surplusAuctionHouse), _coinBalance);
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    surplusAuctionHouse.disableContract();
  }

  function test_Revert_ContractIsDisabled() public {
    vm.startPrank(authorizedAccount);

    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    surplusAuctionHouse.disableContract();
  }

  function test_Emit_DisableContract(uint256 _coinBalance) public happyPath(_coinBalance) {
    expectEmitNoIndex();
    emit DisableContract();

    surplusAuctionHouse.disableContract();
  }

  function test_Call_SafeEngine_TransferInternalCoins(uint256 _coinBalance) public happyPath(_coinBalance) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.transferInternalCoins, (address(surplusAuctionHouse), authorizedAccount, _coinBalance)
      )
    );

    surplusAuctionHouse.disableContract();
  }
}

contract Unit_SurplusAuctionHouse_StartAuction is Base {
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
    _mockProtocolTokenBidReceiver(protocolTokenBidReceiver);
    _mockTotalAuctionLength(_totalAuctionLength);
  }

  function test_Revert_Unauthorized(uint256 _amountToSell, uint256 _initialBid) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    surplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Revert_ContractIsDisabled(uint256 _amountToSell, uint256 _initialBid) public {
    vm.startPrank(authorizedAccount);

    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    surplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Revert_NullProtTokenReceiver(uint256 _amountToSell, uint256 _initialBid) public {
    vm.startPrank(authorizedAccount);

    _mockProtocolTokenBidReceiver(address(0));

    vm.expectRevert(ISurplusAuctionHouse.SAH_NullProtTokenReceiver.selector);

    surplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function testFail_Revert_NullProtTokenReceiver_Burning(uint256 _amountToSell, uint256 _initialBid) public {
    vm.startPrank(authorizedAccount);

    _mockProtocolTokenBidReceiver(address(0));
    _mockRecyclingPercentage(0);

    vm.expectRevert(ISurplusAuctionHouse.SAH_NullProtTokenReceiver.selector);

    surplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Revert_Overflow(uint256 _amountToSell, uint256 _initialBid) public {
    vm.startPrank(authorizedAccount);

    _mockValues(type(uint256).max, 0);

    vm.expectRevert();

    surplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Set_AuctionsStarted(
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint48 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _totalAuctionLength) {
    surplusAuctionHouse.startAuction(_amountToSell, _initialBid);

    assertEq(surplusAuctionHouse.auctionsStarted(), _auctionsStarted + 1);
  }

  function test_Set_Bids(
    uint256 _amountToSellFuzzed,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint48 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _totalAuctionLength) {
    surplusAuctionHouse.startAuction(_amountToSellFuzzed, _initialBid);

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline) =
      surplusAuctionHouse.bids(_auctionsStarted + 1);

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
        mockSafeEngine.transferInternalCoins, (authorizedAccount, address(surplusAuctionHouse), _amountToSell)
      )
    );

    surplusAuctionHouse.startAuction(_amountToSell, _initialBid);
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

    surplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Return_Id(
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint48 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _totalAuctionLength) {
    assertEq(surplusAuctionHouse.startAuction(_amountToSell, _initialBid), _auctionsStarted + 1);
  }
}

contract Unit_SurplusAuctionHouse_RestartAuction is Base {
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

    vm.expectRevert(ISurplusAuctionHouse.SAH_AuctionNeverStarted.selector);

    surplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_AuctionNeverStarted_1(SurplusAuction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id > _auctionsStarted);

    _mockValues(_auction, _auctionsStarted, 0);

    vm.expectRevert(ISurplusAuctionHouse.SAH_AuctionNeverStarted.selector);

    surplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_NotFinished(SurplusAuction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id > 0 && _auction.id <= _auctionsStarted);
    vm.assume(_auction.auctionDeadline > block.timestamp);

    _mockValues(_auction, _auctionsStarted, 0);

    vm.expectRevert(ISurplusAuctionHouse.SAH_AuctionNotFinished.selector);

    surplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_BidAlreadyPlaced(SurplusAuction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id > 0 && _auction.id <= _auctionsStarted);
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(_auction.bidExpiry != 0);

    _mockValues(_auction, _auctionsStarted, 0);

    vm.expectRevert(ISurplusAuctionHouse.SAH_BidAlreadyPlaced.selector);

    surplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Set_Bids_AuctionDeadline(
    SurplusAuction memory _auction,
    uint256 _auctionsStarted,
    uint48 _totalAuctionLength
  ) public happyPath(_auction, _auctionsStarted, _totalAuctionLength) {
    surplusAuctionHouse.restartAuction(_auction.id);

    (,,,, uint48 _auctionDeadline) = surplusAuctionHouse.bids(_auction.id);

    assertEq(_auctionDeadline, block.timestamp + _totalAuctionLength);
  }

  function test_Emit_RestartAuction(
    SurplusAuction memory _auction,
    uint256 _auctionsStarted,
    uint48 _totalAuctionLength
  ) public happyPath(_auction, _auctionsStarted, _totalAuctionLength) {
    expectEmitNoIndex();
    emit RestartAuction(_auction.id, block.timestamp + _totalAuctionLength);

    surplusAuctionHouse.restartAuction(_auction.id);
  }
}

contract Unit_SurplusAuctionHouse_IncreaseBidSize is Base {
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

  function test_Revert_ContractIsDisabled(SurplusAuction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    surplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_HighBidderNotSet(SurplusAuction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    _auction.highBidder = address(0);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(ISurplusAuctionHouse.SAH_HighBidderNotSet.selector);

    surplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_BidAlreadyExpired(SurplusAuction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry != 0 && _auction.bidExpiry <= block.timestamp);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(ISurplusAuctionHouse.SAH_BidAlreadyExpired.selector);

    surplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_AuctionAlreadyExpired(SurplusAuction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline <= block.timestamp);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(ISurplusAuctionHouse.SAH_AuctionAlreadyExpired.selector);

    surplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_AmountsNotMatching(SurplusAuction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_amountToBuy != _auction.amountToSell);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(ISurplusAuctionHouse.SAH_AmountsNotMatching.selector);

    surplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_BidNotHigher(SurplusAuction memory _auction, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_bid <= _auction.bidAmount);

    _mockValues(_auction, 0, 0);

    vm.expectRevert(ISurplusAuctionHouse.SAH_BidNotHigher.selector);

    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
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

    vm.expectRevert(ISurplusAuctionHouse.SAH_InsufficientIncrease.selector);

    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
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
        mockProtocolToken.move, (_auction.highBidder, address(surplusAuctionHouse), _bid - _auction.bidAmount)
      )
    );

    changePrank(_auction.highBidder);
    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
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
    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
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
      abi.encodeCall(mockProtocolToken.move, (user, address(surplusAuctionHouse), _bid - _auction.bidAmount))
    );

    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }

  function test_Set_Bids_HighBidder_0(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint48 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    changePrank(_auction.highBidder);
    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (,, address _highBidder,,) = surplusAuctionHouse.bids(_auction.id);

    assertEq(_highBidder, _auction.highBidder);
  }

  function test_Set_Bids_HighBidder_1(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint48 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (,, address _highBidder,,) = surplusAuctionHouse.bids(_auction.id);

    assertEq(_highBidder, user);
  }

  function test_Set_Bids_BidAmount(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint48 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (uint256 _bidAmount,,,,) = surplusAuctionHouse.bids(_auction.id);

    assertEq(_bidAmount, _bid);
  }

  function test_Set_Bids_BidExpiry(
    SurplusAuction memory _auction,
    uint256 _bid,
    uint256 _bidIncrease,
    uint48 _bidDuration
  ) public happyPath(_auction, _bid, _bidIncrease, _bidDuration) {
    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (,,, uint48 _bidExpiry,) = surplusAuctionHouse.bids(_auction.id);

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

    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }
}

contract Unit_SurplusAuctionHouse_SettleAuction is Base {
  event SettleAuction(uint256 indexed _id);

  modifier happyPath(SurplusAuction memory _auction, uint256 _recyclingPercentage) {
    _assumeHappyPath(_auction, _recyclingPercentage);
    _mockValues(_auction, _recyclingPercentage);
    _;
  }

  function _assumeHappyPath(
    SurplusAuction memory _auction,
    uint256 _recyclingPercentage
  ) internal view returns (uint256 _amountToSend, uint256 _amountToBurn) {
    vm.assume(
      _auction.bidExpiry != 0 && (_auction.bidExpiry < block.timestamp || _auction.auctionDeadline < block.timestamp)
    );

    vm.assume(notOverflowMul(_auction.bidAmount, _recyclingPercentage));
    _amountToSend = _auction.bidAmount * _recyclingPercentage / HUNDRED;

    vm.assume(notUnderflow(_auction.bidAmount, _amountToSend));
    _amountToBurn = _auction.bidAmount - _amountToSend;
  }

  function _mockValues(SurplusAuction memory _auction, uint256 _recyclingPercentage) internal {
    _mockAuction(_auction);
    _mockProtocolTokenBidReceiver(protocolTokenBidReceiver);
    _mockRecyclingPercentage(_recyclingPercentage);
  }

  function test_Revert_ContractIsDisabled(SurplusAuction memory _auction) public {
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Revert_NotFinished_0(SurplusAuction memory _auction) public {
    vm.assume(_auction.bidExpiry == 0);

    _mockValues(_auction, 0);

    vm.expectRevert(ISurplusAuctionHouse.SAH_AuctionNotFinished.selector);

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Revert_NotFinished_1(SurplusAuction memory _auction) public {
    vm.assume(_auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);

    _mockValues(_auction, 0);

    vm.expectRevert(ISurplusAuctionHouse.SAH_AuctionNotFinished.selector);

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Call_SafeEngine_TransferInternalCoins(
    SurplusAuction memory _auction,
    uint256 _recyclingPercentage
  ) public happyPath(_auction, _recyclingPercentage) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.transferInternalCoins, (address(surplusAuctionHouse), _auction.highBidder, _auction.amountToSell)
      )
    );

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Call_ProtocolToken_Push(SurplusAuction memory _auction, uint256 _recyclingPercentage) public {
    (uint256 _amountToSend,) = _assumeHappyPath(_auction, _recyclingPercentage);
    vm.assume(_amountToSend > 0);

    _mockValues(_auction, _recyclingPercentage);

    vm.expectCall(
      address(mockProtocolToken), abi.encodeCall(mockProtocolToken.push, (protocolTokenBidReceiver, _amountToSend))
    );

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function testFail_Call_ProtocolToken_Push(SurplusAuction memory _auction) public {
    uint256 _recyclingPercentage = 0;

    (uint256 _amountToSend,) = _assumeHappyPath(_auction, _recyclingPercentage);
    _mockValues(_auction, _recyclingPercentage);

    vm.expectCall(
      address(mockProtocolToken), abi.encodeCall(mockProtocolToken.push, (protocolTokenBidReceiver, _amountToSend))
    );

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Call_ProtocolToken_Burn(SurplusAuction memory _auction, uint256 _recyclingPercentage) public {
    (, uint256 _amountToBurn) = _assumeHappyPath(_auction, _recyclingPercentage);
    vm.assume(_amountToBurn > 0);

    _mockValues(_auction, _recyclingPercentage);

    vm.expectCall(address(mockProtocolToken), abi.encodeWithSignature('burn(uint256)', _amountToBurn));

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function testFail_Call_ProtocolToken_Burn(SurplusAuction memory _auction) public {
    uint256 _recyclingPercentage = 100;

    (, uint256 _amountToBurn) = _assumeHappyPath(_auction, _recyclingPercentage);
    _mockValues(_auction, _recyclingPercentage);

    vm.expectCall(address(mockProtocolToken), abi.encodeWithSignature('burn(uint256)', _amountToBurn));

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Set_Bids(
    SurplusAuction memory _auction,
    uint256 _recyclingPercentage
  ) public happyPath(_auction, _recyclingPercentage) {
    surplusAuctionHouse.settleAuction(_auction.id);

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline) =
      surplusAuctionHouse.bids(_auction.id);

    assertEq(_bidAmount, 0);
    assertEq(_amountToSell, 0);
    assertEq(_highBidder, address(0));
    assertEq(_bidExpiry, 0);
    assertEq(_auctionDeadline, 0);
  }

  function test_Emit_SettleAuction(
    SurplusAuction memory _auction,
    uint256 _recyclingPercentage
  ) public happyPath(_auction, _recyclingPercentage) {
    expectEmitNoIndex();
    emit SettleAuction(_auction.id);

    surplusAuctionHouse.settleAuction(_auction.id);
  }
}

contract Unit_SurplusAuctionHouse_TerminateAuctionPrematurely is Base {
  event TerminateAuctionPrematurely(uint256 indexed _id, address _sender, address _highBidder, uint256 _bidAmount);

  modifier happyPath(SurplusAuction memory _auction) {
    vm.startPrank(user);

    _assumeHappyPath(_auction);
    _mockValues(_auction);
    _;
  }

  function _assumeHappyPath(SurplusAuction memory _auction) internal pure {
    vm.assume(_auction.highBidder != address(0));
  }

  function _mockValues(SurplusAuction memory _auction) internal {
    _mockContractEnabled(0);
    _mockAuction(_auction);
  }

  function test_Revert_ContractIsEnabled(SurplusAuction memory _auction) public {
    vm.expectRevert(IDisableable.ContractIsEnabled.selector);

    surplusAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Revert_HighBidderNotSet(SurplusAuction memory _auction) public {
    _auction.highBidder = address(0);

    _mockValues(_auction);

    vm.expectRevert(ISurplusAuctionHouse.SAH_HighBidderNotSet.selector);

    surplusAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Call_ProtocolToken_Push(SurplusAuction memory _auction) public happyPath(_auction) {
    vm.expectCall(
      address(mockProtocolToken), abi.encodeCall(mockProtocolToken.push, (_auction.highBidder, _auction.bidAmount))
    );

    surplusAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Emit_TerminateAuctionPrematurely(SurplusAuction memory _auction) public happyPath(_auction) {
    expectEmitNoIndex();
    emit TerminateAuctionPrematurely(_auction.id, user, _auction.highBidder, _auction.bidAmount);

    surplusAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Set_Bids(SurplusAuction memory _auction) public happyPath(_auction) {
    surplusAuctionHouse.terminateAuctionPrematurely(_auction.id);

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline) =
      surplusAuctionHouse.bids(_auction.id);

    assertEq(_bidAmount, 0);
    assertEq(_amountToSell, 0);
    assertEq(_highBidder, address(0));
    assertEq(_bidExpiry, 0);
    assertEq(_auctionDeadline, 0);
  }
}

contract Unit_SurplusAuctionHouse_ModifyParameters is Base {
  event ModifyParameters(bytes32 indexed _param, bytes32 indexed _cType, bytes _data);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized(bytes32 _param, bytes memory _data) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    surplusAuctionHouse.modifyParameters(_param, _data);
  }

  function test_Set_Parameters(ISurplusAuctionHouse.SurplusAuctionHouseParams memory _fuzz) public happyPath {
    surplusAuctionHouse.modifyParameters('bidIncrease', abi.encode(_fuzz.bidIncrease));
    surplusAuctionHouse.modifyParameters('bidDuration', abi.encode(_fuzz.bidDuration));
    surplusAuctionHouse.modifyParameters('totalAuctionLength', abi.encode(_fuzz.totalAuctionLength));
    surplusAuctionHouse.modifyParameters('recyclingPercentage', abi.encode(_fuzz.recyclingPercentage));

    ISurplusAuctionHouse.SurplusAuctionHouseParams memory _params = surplusAuctionHouse.params();

    assertEq(abi.encode(_params), abi.encode(_fuzz));
  }

  function test_Set_ProtocolTokenBidReceiver(address _protocolTokenBidReceiver) public happyPath {
    vm.assume(_protocolTokenBidReceiver != address(0));

    surplusAuctionHouse.modifyParameters('protocolTokenBidReceiver', abi.encode(_protocolTokenBidReceiver));

    assertEq(surplusAuctionHouse.protocolTokenBidReceiver(), _protocolTokenBidReceiver);
  }

  function test_Revert_ProtocolTokenBidReceiver_NullAddress() public happyPath {
    vm.expectRevert(Assertions.NullAddress.selector);

    surplusAuctionHouse.modifyParameters('protocolTokenBidReceiver', abi.encode(0));
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    surplusAuctionHouse.modifyParameters('unrecognizedParam', _data);
  }

  function test_Emit_ModifyParameters(address _protocolTokenBidReceiver) public happyPath {
    vm.assume(_protocolTokenBidReceiver != address(0));

    expectEmitNoIndex();
    emit ModifyParameters('protocolTokenBidReceiver', GLOBAL_PARAM, abi.encode(_protocolTokenBidReceiver));

    surplusAuctionHouse.modifyParameters('protocolTokenBidReceiver', abi.encode(_protocolTokenBidReceiver));
  }
}

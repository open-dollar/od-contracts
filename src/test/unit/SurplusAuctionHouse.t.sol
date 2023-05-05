// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {SurplusAuctionHouseForTest, ISurplusAuctionHouse} from '@contracts/for-test/SurplusAuctionHouseForTest.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IToken} from '@interfaces/external/IToken.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {WAD, HUNDRED} from '@libraries/Math.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  struct Auction {
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

  modifier authorized() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function _mockCoinBalance(address _coinAddress, uint256 _coinBalance) internal {
    vm.mockCall(
      address(mockSafeEngine), abi.encodeCall(mockSafeEngine.coinBalance, (_coinAddress)), abi.encode(_coinBalance)
    );
  }

  function _mockAuction(Auction memory _auction) internal {
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

  function _mockProtocolTokenBidReceiver(address _protocolTokenBidReceiver) internal {
    stdstore.target(address(surplusAuctionHouse)).sig(ISurplusAuctionHouse.protocolTokenBidReceiver.selector)
      .checked_write(_protocolTokenBidReceiver);
  }

  function _mockAuctionsStarted(uint256 _auctionsStarted) internal {
    stdstore.target(address(surplusAuctionHouse)).sig(ISurplusAuctionHouse.auctionsStarted.selector).checked_write(
      _auctionsStarted
    );
  }

  function _mockContractEnabled(uint256 _contractEnabled) internal {
    stdstore.target(address(surplusAuctionHouse)).sig(IDisableable.contractEnabled.selector).checked_write(
      _contractEnabled
    );
  }

  // params
  function _mockBidIncrease(uint256 _bidIncrease) internal {
    stdstore.target(address(surplusAuctionHouse)).sig(ISurplusAuctionHouse.params.selector).depth(0).checked_write(
      _bidIncrease
    );
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

  function setUp() public override {
    Base.setUp();

    vm.startPrank(user);
  }

  function test_Set_ContractEnabled() public {
    assertEq(surplusAuctionHouse.contractEnabled(), 1);
  }

  function test_Set_BidIncrease() public {
    assertEq(surplusAuctionHouse.params().bidIncrease, 1.05e18);
  }

  function test_Set_BidDuration() public {
    assertEq(surplusAuctionHouse.params().bidDuration, 3 hours);
  }

  function test_Set_TotalAuctionLength() public {
    assertEq(surplusAuctionHouse.params().totalAuctionLength, 2 days);
  }

  function test_Emit_AddAuthorization() public {
    expectEmitNoIndex();
    emit AddAuthorization(user);

    surplusAuctionHouse =
      new SurplusAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken), RECYCLING_PERCENTAGE);
  }

  function test_Set_SafeEngine(address _safeEngine) public {
    surplusAuctionHouse = new SurplusAuctionHouseForTest(_safeEngine, address(mockProtocolToken), RECYCLING_PERCENTAGE);

    assertEq(address(surplusAuctionHouse.safeEngine()), _safeEngine);
  }

  function test_Set_ProtocolToken(address _protocolToken) public {
    surplusAuctionHouse = new SurplusAuctionHouseForTest(address(mockSafeEngine), _protocolToken, RECYCLING_PERCENTAGE);

    assertEq(address(surplusAuctionHouse.protocolToken()), _protocolToken);
  }

  function test_Set_RecyclingPercentage(uint256 _recyclingPercentage) public {
    surplusAuctionHouse =
      new SurplusAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken), _recyclingPercentage);

    assertEq(surplusAuctionHouse.params().recyclingPercentage, _recyclingPercentage);
  }
}

contract Unit_SurplusAuctionHouse_ModifyParameters is Base {
  function test_ModifyParameters(ISurplusAuctionHouse.SurplusAuctionHouseParams memory _fuzz) public authorized {
    surplusAuctionHouse.modifyParameters('bidIncrease', abi.encode(_fuzz.bidIncrease));
    surplusAuctionHouse.modifyParameters('bidDuration', abi.encode(_fuzz.bidDuration));
    surplusAuctionHouse.modifyParameters('totalAuctionLength', abi.encode(_fuzz.totalAuctionLength));
    surplusAuctionHouse.modifyParameters('recyclingPercentage', abi.encode(_fuzz.recyclingPercentage));

    (bool _success, bytes memory _data) = address(surplusAuctionHouse).staticcall(abi.encodeWithSignature('params()'));

    assert(_success);
    assertEq(keccak256(abi.encode(_fuzz)), keccak256(_data));
  }

  function test_ModifyParameters_ProtocolTokenBidReceiver(address _protocolTokenBidReceiver) public authorized {
    vm.assume(_protocolTokenBidReceiver != address(0));
    surplusAuctionHouse.modifyParameters('protocolTokenBidReceiver', abi.encode(_protocolTokenBidReceiver));

    assertEq(_protocolTokenBidReceiver, surplusAuctionHouse.protocolTokenBidReceiver());
  }

  function test_Revert_ModifiyParameters_UnrecognizedParam() public authorized {
    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    surplusAuctionHouse.modifyParameters('unrecognizedParam', abi.encode(0));
  }

  function test_Revert_ModifiyParameters_ProtocolTokenBidReceiver() public authorized {
    vm.expectRevert('SurplusAuctionHouse/null-address');

    surplusAuctionHouse.modifyParameters('protocolTokenBidReceiver', abi.encode(0));
  }
}

contract Unit_SurplusAuctionHouse_DisableContract is Base {
  event DisableContract();

  modifier happyPath(uint256 _coinBalance) {
    _mockCoinBalance(address(surplusAuctionHouse), _coinBalance);
    _;
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    surplusAuctionHouse.disableContract();
  }

  function test_Revert_ContractIsDisabled() public authorized {
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    surplusAuctionHouse.disableContract();
  }

  function test_Emit_DisableContract(uint256 _coinBalance) public authorized happyPath(_coinBalance) {
    expectEmitNoIndex();
    emit DisableContract();

    surplusAuctionHouse.disableContract();
  }

  function test_Call_SafeEngine_TransferInternalCoins(uint256 _coinBalance) public authorized happyPath(_coinBalance) {
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

  function setUp() public override {
    Base.setUp();

    _mockProtocolTokenBidReceiver(protocolTokenBidReceiver);
  }

  function test_Revert_Unauthorized(uint256 _amountToSell, uint256 _initialBid) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    surplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Revert_ContractIsDisabled(uint256 _amountToSell, uint256 _initialBid) public authorized {
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    surplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Revert_NullProtTokenReceiver(uint256 _amountToSell, uint256 _initialBid) public authorized {
    _mockProtocolTokenBidReceiver(address(0));

    vm.expectRevert('SurplusAuctionHouse/null-prot-token-receiver');

    surplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function testFail_Revert_NullProtTokenReceiver_Burning(uint256 _amountToSell, uint256 _initialBid) public authorized {
    _mockProtocolTokenBidReceiver(address(0));
    _mockRecyclingPercentage(0);

    vm.expectRevert('SurplusAuctionHouse/null-prot-token-receiver');

    surplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Revert_Overflow(uint256 _amountToSell, uint256 _initialBid) public authorized {
    _mockAuctionsStarted(type(uint256).max);

    vm.expectRevert();

    surplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Set_AuctionsStarted(uint256 _amountToSell, uint256 _initialBid) public authorized {
    for (uint256 _i = 1; _i <= 3; ++_i) {
      surplusAuctionHouse.startAuction(_amountToSell, _initialBid);
      assertEq(surplusAuctionHouse.auctionsStarted(), _i);
    }
  }

  function test_Set_Bids(uint256 _amountToSellFuzzed, uint256 _initialBid) public authorized {
    surplusAuctionHouse.startAuction(_amountToSellFuzzed, _initialBid);

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline) =
      surplusAuctionHouse.bids(1);

    assertEq(_bidAmount, _initialBid);
    assertEq(_amountToSell, _amountToSellFuzzed);
    assertEq(_highBidder, authorizedAccount);
    assertEq(_bidExpiry, 0);
    assertEq(_auctionDeadline, block.timestamp + surplusAuctionHouse.params().totalAuctionLength);
  }

  function test_Call_SafeEngine_TransferInternalCoins(uint256 _amountToSell, uint256 _initialBid) public authorized {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.transferInternalCoins, (authorizedAccount, address(surplusAuctionHouse), _amountToSell)
      )
    );

    surplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Emit_StartAuction(uint256 _amountToSell, uint256 _initialBid) public authorized {
    expectEmitNoIndex();
    emit StartAuction(
      1, 1, _amountToSell, _initialBid, block.timestamp + surplusAuctionHouse.params().totalAuctionLength
    );

    surplusAuctionHouse.startAuction(_amountToSell, _initialBid);
  }

  function test_Return_Id(uint256 _amountToSell, uint256 _initialBid) public authorized {
    uint256 _auctionsStarted = surplusAuctionHouse.auctionsStarted();

    assertEq(surplusAuctionHouse.startAuction(_amountToSell, _initialBid), _auctionsStarted + 1);
  }
}

contract Unit_SurplusAuctionHouse_RestartAuction is Base {
  event RestartAuction(uint256 _id, uint256 _auctionDeadline);

  modifier happyPath(Auction memory _auction) {
    _assumeHappyPath(_auction);
    _mockAuction(_auction);
    _;
  }

  function _assumeHappyPath(Auction memory _auction) internal view {
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(_auction.bidExpiry == 0);
  }

  function test_Revert_NotFinished(Auction memory _auction) public {
    vm.assume(_auction.auctionDeadline >= block.timestamp);

    _mockAuction(_auction);

    vm.expectRevert('SurplusAuctionHouse/not-finished');

    surplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_BidAlreadyPlaced(Auction memory _auction) public {
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(_auction.bidExpiry != 0);

    _mockAuction(_auction);

    vm.expectRevert('SurplusAuctionHouse/bid-already-placed');

    surplusAuctionHouse.restartAuction(_auction.id);
  }

  function test_Set_Bids_AuctionDeadline(Auction memory _auction) public happyPath(_auction) {
    surplusAuctionHouse.restartAuction(_auction.id);

    (,,,, uint48 _auctionDeadline) = surplusAuctionHouse.bids(_auction.id);

    assertEq(_auctionDeadline, block.timestamp + surplusAuctionHouse.params().totalAuctionLength);
  }

  function test_Emit_RestartAuction(Auction memory _auction) public happyPath(_auction) {
    expectEmitNoIndex();
    emit RestartAuction(_auction.id, block.timestamp + surplusAuctionHouse.params().totalAuctionLength);

    surplusAuctionHouse.restartAuction(_auction.id);
  }
}

contract Unit_SurplusAuctionHouse_IncreaseBidSize is Base {
  event IncreaseBidSize(uint256 _id, address _highBidder, uint256 _amountToBuy, uint256 _bid, uint256 _bidExpiry);

  function setUp() public override {
    Base.setUp();

    vm.startPrank(user);
  }

  modifier happyPath(Auction memory _auction, uint256 _bid) {
    _assumeHappyPath(_auction, _bid);
    _mockAuction(_auction);
    _;
  }

  function _assumeHappyPath(Auction memory _auction, uint256 _bid) internal view {
    vm.assume(_auction.highBidder != address(0) && _auction.highBidder != user);
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_bid > _auction.bidAmount);
    vm.assume(notOverflowMul(_bid, WAD));
    vm.assume(notOverflowMul(surplusAuctionHouse.params().bidIncrease, _auction.bidAmount));
    vm.assume(_bid * WAD >= surplusAuctionHouse.params().bidIncrease * _auction.bidAmount);
  }

  function test_Revert_ContractIsDisabled(Auction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    surplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_HighBidderNotSet(Auction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    _auction.highBidder = address(0);

    _mockAuction(_auction);

    vm.expectRevert('SurplusAuctionHouse/high-bidder-not-set');

    surplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_BidAlreadyExpired(Auction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry != 0 && _auction.bidExpiry <= block.timestamp);

    _mockAuction(_auction);

    vm.expectRevert('SurplusAuctionHouse/bid-already-expired');

    surplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_AuctionAlreadyExpired(Auction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline <= block.timestamp);

    _mockAuction(_auction);

    vm.expectRevert('SurplusAuctionHouse/auction-already-expired');

    surplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_AmountsNotMatching(Auction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_auction.amountToSell != _amountToBuy);

    _mockAuction(_auction);

    vm.expectRevert('SurplusAuctionHouse/amounts-not-matching');

    surplusAuctionHouse.increaseBidSize(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_BidNotHigher(Auction memory _auction, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_bid <= _auction.bidAmount);

    _mockAuction(_auction);

    vm.expectRevert('SurplusAuctionHouse/bid-not-higher');

    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }

  function test_Revert_InsufficientIncrease(Auction memory _auction, uint256 _bid, uint256 _bidIncrease) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_bid > _auction.bidAmount);
    vm.assume(notOverflowMul(_bid, WAD));
    vm.assume(notOverflowMul(_bidIncrease, _auction.bidAmount));
    vm.assume(_bid * WAD < _bidIncrease * _auction.bidAmount);

    _mockAuction(_auction);
    _mockBidIncrease(_bidIncrease);

    vm.expectRevert('SurplusAuctionHouse/insufficient-increase');

    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }

  function test_Call_ProtocolToken_Move_0(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeCall(
        mockProtocolToken.move, (_auction.highBidder, address(surplusAuctionHouse), _bid - _auction.bidAmount)
      )
    );

    changePrank(_auction.highBidder);
    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }

  function testFail_Call_ProtocolToken_Move_0(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeCall(mockProtocolToken.move, (_auction.highBidder, _auction.highBidder, _auction.bidAmount))
    );

    changePrank(_auction.highBidder);
    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }

  function test_Call_ProtocolToken_Move_1(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
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

  function test_Set_Bids_HighBidder_0(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
    changePrank(_auction.highBidder);
    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (,, address _highBidder,,) = surplusAuctionHouse.bids(_auction.id);

    assertEq(_highBidder, _auction.highBidder);
  }

  function test_Set_Bids_HighBidder_1(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (,, address _highBidder,,) = surplusAuctionHouse.bids(_auction.id);

    assertEq(_highBidder, user);
  }

  function test_Set_Bids_BidAmount(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (uint256 _bidAmount,,,,) = surplusAuctionHouse.bids(_auction.id);

    assertEq(_bidAmount, _bid);
  }

  function test_Set_Bids_BidExpiry(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);

    (,,, uint48 _bidExpiry,) = surplusAuctionHouse.bids(_auction.id);

    assertEq(_bidExpiry, block.timestamp + surplusAuctionHouse.params().bidDuration);
  }

  function test_Emit_IncreaseBidSize(Auction memory _auction, uint256 _bid) public happyPath(_auction, _bid) {
    expectEmitNoIndex();
    emit IncreaseBidSize(
      _auction.id, user, _auction.amountToSell, _bid, block.timestamp + surplusAuctionHouse.params().bidDuration
    );

    surplusAuctionHouse.increaseBidSize(_auction.id, _auction.amountToSell, _bid);
  }
}

contract Unit_SurplusAuctionHouse_SettleAuction is Base {
  event SettleAuction(uint256 indexed _id);

  function setUp() public override {
    Base.setUp();

    _mockProtocolTokenBidReceiver(protocolTokenBidReceiver);
  }

  modifier happyPath(Auction memory _auction) {
    _assumeHappyPath(_auction);
    _mockAuction(_auction);
    _;
  }

  function _assumeHappyPath(Auction memory _auction)
    internal
    view
    returns (uint256 _amountToSend, uint256 _amountToBurn)
  {
    vm.assume(notOverflowMul(_auction.bidAmount, RECYCLING_PERCENTAGE));
    _amountToSend = _auction.bidAmount * RECYCLING_PERCENTAGE / HUNDRED;
    _amountToBurn = _auction.bidAmount - _amountToSend;

    vm.assume(_auction.bidExpiry != 0);
    vm.assume(_auction.bidExpiry < block.timestamp);
    vm.assume(_amountToSend > 0);
    vm.assume(_amountToBurn > 0);
  }

  function test_Revert_ContractIsDisabled(Auction memory _auction) public {
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Revert_NotFinished_0(Auction memory _auction) public {
    vm.assume(_auction.bidExpiry == 0);

    _mockAuction(_auction);

    vm.expectRevert('SurplusAuctionHouse/not-finished');

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Revert_NotFinished_1(Auction memory _auction) public {
    vm.assume(_auction.bidExpiry >= block.timestamp);
    vm.assume(_auction.auctionDeadline >= block.timestamp);

    _mockAuction(_auction);

    vm.expectRevert('SurplusAuctionHouse/not-finished');

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Call_SafeEngine_TransferInternalCoins(Auction memory _auction) public {
    vm.assume(_auction.bidExpiry >= block.timestamp);
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(notOverflowMul(_auction.bidAmount, RECYCLING_PERCENTAGE));

    _mockAuction(_auction);

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.transferInternalCoins, (address(surplusAuctionHouse), _auction.highBidder, _auction.amountToSell)
      )
    );

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Call_ProtocolToken_Push(Auction memory _auction) public {
    (uint256 _amountToSend,) = _assumeHappyPath(_auction);

    _mockAuction(_auction);

    vm.expectCall(
      address(mockProtocolToken), abi.encodeCall(mockProtocolToken.push, (protocolTokenBidReceiver, _amountToSend))
    );

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function testFail_Call_ProtocolToken_Push(Auction memory _auction) public {
    (uint256 _amountToSend,) = _assumeHappyPath(_auction);

    _mockAuction(_auction);
    _mockRecyclingPercentage(0);

    vm.expectCall(
      address(mockProtocolToken), abi.encodeCall(mockProtocolToken.push, (protocolTokenBidReceiver, _amountToSend))
    );

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Call_ProtocolToken_Burn(Auction memory _auction) public {
    (, uint256 _amountToBurn) = _assumeHappyPath(_auction);

    _mockAuction(_auction);

    vm.expectCall(
      address(mockProtocolToken), abi.encodeCall(mockProtocolToken.burn, (address(surplusAuctionHouse), _amountToBurn))
    );

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function testFail_Call_ProtocolToken_Burn(Auction memory _auction) public {
    (, uint256 _amountToBurn) = _assumeHappyPath(_auction);

    _mockAuction(_auction);
    _mockRecyclingPercentage(100);

    vm.expectCall(
      address(mockProtocolToken), abi.encodeCall(mockProtocolToken.burn, (address(surplusAuctionHouse), _amountToBurn))
    );

    surplusAuctionHouse.settleAuction(_auction.id);
  }

  function test_Set_Bids(Auction memory _auction) public happyPath(_auction) {
    surplusAuctionHouse.settleAuction(_auction.id);

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline) =
      surplusAuctionHouse.bids(_auction.id);

    assertEq(_bidAmount, 0);
    assertEq(_amountToSell, 0);
    assertEq(_highBidder, address(0));
    assertEq(_bidExpiry, 0);
    assertEq(_auctionDeadline, 0);
  }

  function test_Emit_SettleAuction(Auction memory _auction) public happyPath(_auction) {
    expectEmitNoIndex();
    emit SettleAuction(_auction.id);

    surplusAuctionHouse.settleAuction(_auction.id);
  }
}

contract Unit_SurplusAuctionHouse_TerminateAuctionPrematurely is Base {
  event TerminateAuctionPrematurely(uint256 indexed _id, address _sender, address _highBidder, uint256 _bidAmount);

  function setUp() public override {
    Base.setUp();

    vm.startPrank(user);
  }

  modifier happyPath(Auction memory _auction) {
    _assumeHappyPath(_auction);
    _mockAuction(_auction);
    _mockContractEnabled(0);
    _;
  }

  function _assumeHappyPath(Auction memory _auction) internal pure {
    vm.assume(_auction.highBidder != address(0));
  }

  function test_Revert_ContractIsEnabled(Auction memory _auction) public {
    _mockContractEnabled(1);

    vm.expectRevert(IDisableable.ContractIsEnabled.selector);

    surplusAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Revert_HighBidderNotSet(Auction memory _auction) public {
    _auction.highBidder = address(0);

    _mockContractEnabled(0);
    _mockAuction(_auction);

    vm.expectRevert('SurplusAuctionHouse/high-bidder-not-set');

    surplusAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Call_ProtocolToken_Push(Auction memory _auction) public happyPath(_auction) {
    vm.expectCall(
      address(mockProtocolToken), abi.encodeCall(mockProtocolToken.push, (_auction.highBidder, _auction.bidAmount))
    );

    surplusAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Emit_TerminateAuctionPrematurely(Auction memory _auction) public happyPath(_auction) {
    expectEmitNoIndex();
    emit TerminateAuctionPrematurely(_auction.id, user, _auction.highBidder, _auction.bidAmount);

    surplusAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Set_Bids(Auction memory _auction) public happyPath(_auction) {
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

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {DebtAuctionHouseForTest, IDebtAuctionHouse} from '@contracts/for-test/DebtAuctionHouseForTest.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IToken} from '@interfaces/external/IToken.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable, GLOBAL_PARAM} from '@interfaces/utils/IModifiable.sol';
import {Math, WAD} from '@libraries/Math.sol';
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
  IAccountingEngine mockAccountingEngine = IAccountingEngine(mockContract('AccountingEngine'));

  DebtAuctionHouseForTest debtAuctionHouse;

  function setUp() public virtual {
    vm.startPrank(deployer);

    debtAuctionHouse = new DebtAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken));
    label(address(debtAuctionHouse), 'DebtAuctionHouse');

    debtAuctionHouse.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  modifier authorized() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function _mockTotalOnAuctionDebt(uint256 _totalOnAuctionDebt) internal {
    vm.mockCall(
      address(mockAccountingEngine),
      abi.encodeCall(mockAccountingEngine.totalOnAuctionDebt, ()),
      abi.encode(_totalOnAuctionDebt)
    );
  }

  function _mockContractEnabled(uint256 _contractEnabled) internal {
    stdstore.target(address(debtAuctionHouse)).sig(IDisableable.contractEnabled.selector).checked_write(
      _contractEnabled
    );
  }

  function _mockAuction(Auction memory _auction) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    debtAuctionHouse.addBid(
      _auction.id,
      _auction.bidAmount,
      _auction.amountToSell,
      _auction.highBidder,
      _auction.bidExpiry,
      _auction.auctionDeadline
    );
  }

  function _mockAuctionsStarted(uint256 _auctionsStarted) internal {
    stdstore.target(address(debtAuctionHouse)).sig(IDebtAuctionHouse.auctionsStarted.selector).checked_write(
      _auctionsStarted
    );
  }

  function _mockActiveDebtAuctions(uint256 _activeDebtAuctions) internal {
    stdstore.target(address(debtAuctionHouse)).sig(IDebtAuctionHouse.activeDebtAuctions.selector).checked_write(
      _activeDebtAuctions
    );
  }

  function _mockAccountingEngine(address _accountingEngine) internal {
    stdstore.target(address(debtAuctionHouse)).sig(IDebtAuctionHouse.accountingEngine.selector).checked_write(
      _accountingEngine
    );
  }

  // params
  function _mockBidDecrease(uint256 _bidDecrease) internal {
    stdstore.target(address(debtAuctionHouse)).sig(IDebtAuctionHouse.params.selector).depth(0).checked_write(
      _bidDecrease
    );
  }
}

contract Unit_DebtAuctionHouse_Constants is Base {
  function test_Set_AUCTION_HOUSE_TYPE() public {
    assertEq(debtAuctionHouse.AUCTION_HOUSE_TYPE(), bytes32('DEBT'));
  }
}

contract Unit_DebtAuctionHouse_Constructor is Base {
  event AddAuthorization(address _account);

  function setUp() public override {
    Base.setUp();

    vm.startPrank(user);
  }

  function test_Emit_AddAuthorization() public {
    expectEmitNoIndex();
    emit AddAuthorization(user);

    debtAuctionHouse = new DebtAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken));
  }

  function test_Set_ContractEnabled() public {
    assertEq(debtAuctionHouse.contractEnabled(), 1);
  }

  function test_Set_SafeEngine(address _safeEngine) public {
    debtAuctionHouse = new DebtAuctionHouseForTest(_safeEngine, address(mockProtocolToken));

    assertEq(address(debtAuctionHouse.safeEngine()), _safeEngine);
  }

  function test_Set_ProtocolToken(address _protocolToken) public {
    debtAuctionHouse = new DebtAuctionHouseForTest(address(mockSafeEngine), _protocolToken);

    assertEq(address(debtAuctionHouse.protocolToken()), _protocolToken);
  }

  function test_Set_BidDecrease() public {
    assertEq(debtAuctionHouse.params().bidDecrease, 1.05e18);
  }

  function test_Set_AmountSoldIncrease() public {
    assertEq(debtAuctionHouse.params().amountSoldIncrease, 1.5e18);
  }

  function test_Set_BidDuration() public {
    assertEq(debtAuctionHouse.params().bidDuration, 3 hours);
  }

  function test_Set_TotalAuctionLength() public {
    assertEq(debtAuctionHouse.params().totalAuctionLength, 2 days);
  }
}

contract Unit_DebtAuctionHouse_DisableContract is Base {
  event DisableContract();

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    debtAuctionHouse.disableContract();
  }

  function test_Emit_DisableContract() public authorized {
    expectEmitNoIndex();
    emit DisableContract();

    debtAuctionHouse.disableContract();
  }

  function test_Set_AccountingEngine() public authorized {
    debtAuctionHouse.disableContract();

    assertEq(debtAuctionHouse.accountingEngine(), authorizedAccount);
  }

  function test_Set_ActiveDebtAuctions(uint256 _activeDebtAuctions) public authorized {
    vm.assume(_activeDebtAuctions != 0);

    _mockActiveDebtAuctions(_activeDebtAuctions);

    debtAuctionHouse.disableContract();

    assertEq(debtAuctionHouse.activeDebtAuctions(), 0);
  }
}

contract Unit_DebtAuctionHouse_StartAuction is Base {
  event StartAuction(
    uint256 indexed _id,
    uint256 _auctionsStarted,
    uint256 _amountToSell,
    uint256 _initialBid,
    address indexed _incomeReceiver,
    uint256 indexed _auctionDeadline,
    uint256 _activeDebtAuctions
  );

  function test_Revert_Unauthorized(address _incomeReceiver, uint256 _amountToSell, uint256 _initialBid) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid);
  }

  function test_Revert_ContractIsDisabled(
    address _incomeReceiver,
    uint256 _amountToSell,
    uint256 _initialBid
  ) public authorized {
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid);
  }

  function test_Revert_Overflow(address _incomeReceiver, uint256 _amountToSell, uint256 _initialBid) public authorized {
    _mockAuctionsStarted(type(uint256).max);

    vm.expectRevert();

    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid);
  }

  function test_Set_AuctionsStarted(
    address _incomeReceiver,
    uint256 _amountToSell,
    uint256 _initialBid
  ) public authorized {
    for (uint256 _i = 1; _i <= 3; ++_i) {
      debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid);
      assertEq(debtAuctionHouse.auctionsStarted(), _i);
    }
  }

  function test_Set_Bids(address _incomeReceiver, uint256 _amountToSellFuzzed, uint256 _initialBid) public authorized {
    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSellFuzzed, _initialBid);

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline) =
      debtAuctionHouse.bids(1);

    assertEq(_bidAmount, _initialBid);
    assertEq(_amountToSell, _amountToSellFuzzed);
    assertEq(_highBidder, _incomeReceiver);
    assertEq(_bidExpiry, 0);
    assertEq(_auctionDeadline, block.timestamp + debtAuctionHouse.params().totalAuctionLength);
  }

  function test_Set_ActiveDebtAuctions(
    address _incomeReceiver,
    uint256 _amountToSell,
    uint256 _initialBid
  ) public authorized {
    for (uint256 _i = 1; _i <= 3; ++_i) {
      debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid);
      assertEq(debtAuctionHouse.activeDebtAuctions(), _i);
    }
  }

  function test_Emit_StartAuction(
    address _incomeReceiver,
    uint256 _amountToSell,
    uint256 _initialBid
  ) public authorized {
    expectEmitNoIndex();
    emit StartAuction(
      1,
      1,
      _amountToSell,
      _initialBid,
      _incomeReceiver,
      block.timestamp + debtAuctionHouse.params().totalAuctionLength,
      1
    );

    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid);
  }

  function test_Return_Id(address _incomeReceiver, uint256 _amountToSell, uint256 _initialBid) public authorized {
    uint256 _auctionsStarted = debtAuctionHouse.auctionsStarted();

    assertEq(debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid), _auctionsStarted + 1);
  }
}

contract Unit_DebtAuctionHouse_RestartAuction is Base {
  event RestartAuction(uint256 indexed _id, uint256 _auctionDeadline);

  modifier happyPath(Auction memory _auction, uint256 _auctionsStarted) {
    _assumeHappyPath(_auction, _auctionsStarted);
    _mockAuction(_auction);
    _mockAuctionsStarted(_auctionsStarted);
    _;
  }

  function _assumeHappyPath(Auction memory _auction, uint256 _auctionsStarted) internal view {
    vm.assume(_auction.id > 0 && _auction.id <= _auctionsStarted);
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(_auction.bidExpiry == 0);
    vm.assume(notOverflowMul(debtAuctionHouse.params().amountSoldIncrease, _auction.amountToSell));
  }

  function test_Revert_AuctionNeverStarted_0(Auction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id == 0);

    _mockAuction(_auction);
    _mockAuctionsStarted(_auctionsStarted);

    vm.expectRevert('DebtAuctionHouse/auction-never-started');

    debtAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_AuctionNeverStarted_1(Auction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id > _auctionsStarted);

    _mockAuction(_auction);
    _mockAuctionsStarted(_auctionsStarted);

    vm.expectRevert('DebtAuctionHouse/auction-never-started');

    debtAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_NotFinished(Auction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id > 0 && _auction.id <= _auctionsStarted);
    vm.assume(_auction.auctionDeadline >= block.timestamp);

    _mockAuction(_auction);
    _mockAuctionsStarted(_auctionsStarted);

    vm.expectRevert('DebtAuctionHouse/not-finished');

    debtAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_BidAlreadyPlaced(Auction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id > 0 && _auction.id <= _auctionsStarted);
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(_auction.bidExpiry != 0);

    _mockAuction(_auction);
    _mockAuctionsStarted(_auctionsStarted);

    vm.expectRevert('DebtAuctionHouse/bid-already-placed');

    debtAuctionHouse.restartAuction(_auction.id);
  }

  function test_Set_Bids_AmountToSell(
    Auction memory _auction,
    uint256 _auctionsStarted
  ) public happyPath(_auction, _auctionsStarted) {
    debtAuctionHouse.restartAuction(_auction.id);

    (, uint256 _amountToSell,,,) = debtAuctionHouse.bids(_auction.id);

    assertEq(_amountToSell, (debtAuctionHouse.params().amountSoldIncrease * _auction.amountToSell) / WAD);
  }

  function test_Set_Bids_AuctionDeadline(
    Auction memory _auction,
    uint256 _auctionsStarted
  ) public happyPath(_auction, _auctionsStarted) {
    debtAuctionHouse.restartAuction(_auction.id);

    (,,,, uint48 _auctionDeadline) = debtAuctionHouse.bids(_auction.id);

    assertEq(_auctionDeadline, block.timestamp + debtAuctionHouse.params().totalAuctionLength);
  }

  function test_Emit_RestartAuction(
    Auction memory _auction,
    uint256 _auctionsStarted
  ) public happyPath(_auction, _auctionsStarted) {
    expectEmitNoIndex();
    emit RestartAuction(_auction.id, block.timestamp + debtAuctionHouse.params().totalAuctionLength);

    debtAuctionHouse.restartAuction(_auction.id);
  }
}

contract Unit_DebtAuctionHouse_DecreaseSoldAmount is Base {
  event DecreaseSoldAmount(
    uint256 indexed _id, address _highBidder, uint256 _amountToBuy, uint256 _bid, uint256 _bidExpiry
  );

  function setUp() public override {
    Base.setUp();

    vm.startPrank(user);
  }

  modifier happyPath(Auction memory _auction, uint256 _amountToBuy, uint256 _totalOnAuctionDebt) {
    _auction = _assumeHappyPath(_auction, _amountToBuy);
    _mockAuction(_auction);
    _mockTotalOnAuctionDebt(_totalOnAuctionDebt);
    _;
  }

  function _assumeHappyPath(Auction memory _auction, uint256 _amountToBuy) internal view returns (Auction memory) {
    _auction.highBidder = address(mockAccountingEngine);
    _auction.bidExpiry = 0;
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_amountToBuy < _auction.amountToSell);
    vm.assume(notOverflowMul(debtAuctionHouse.params().bidDecrease, _amountToBuy));
    vm.assume(notOverflowMul(_auction.amountToSell, WAD));
    vm.assume(debtAuctionHouse.params().bidDecrease * _amountToBuy <= _auction.amountToSell * WAD);
    return _auction;
  }

  function test_Revert_ContractIsDisabled(Auction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_HighBidderNotSet(Auction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    _auction.highBidder = address(0);

    _mockAuction(_auction);

    vm.expectRevert('DebtAuctionHouse/high-bidder-not-set');

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_BidAlreadyExpired(Auction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry != 0 && _auction.bidExpiry <= block.timestamp);

    _mockAuction(_auction);

    vm.expectRevert('DebtAuctionHouse/bid-already-expired');

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_AuctionAlreadyExpired(Auction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline <= block.timestamp);

    _mockAuction(_auction);

    vm.expectRevert('DebtAuctionHouse/auction-already-expired');

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_NotMatchingBid(Auction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_bid != _auction.bidAmount);

    _mockAuction(_auction);

    vm.expectRevert('DebtAuctionHouse/not-matching-bid');

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_AmountBoughtNotLower(Auction memory _auction, uint256 _amountToBuy) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_amountToBuy >= _auction.amountToSell);

    _mockAuction(_auction);

    vm.expectRevert('DebtAuctionHouse/amount-bought-not-lower');

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);
  }

  function test_Revert_InsufficientDecrease(Auction memory _auction, uint256 _amountToBuy, uint256 _bidDecrease) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_amountToBuy < _auction.amountToSell);
    vm.assume(notOverflowMul(_bidDecrease, _amountToBuy));
    vm.assume(notOverflowMul(_auction.amountToSell, WAD));
    vm.assume(_bidDecrease * _amountToBuy > _auction.amountToSell * WAD);

    _mockAuction(_auction);
    _mockBidDecrease(_bidDecrease);

    vm.expectRevert('DebtAuctionHouse/insufficient-decrease');

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);
  }

  function test_Call_SafeEngine_TransferInternalCoins(
    Auction memory _auction,
    uint256 _amountToBuy,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _totalOnAuctionDebt) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.transferInternalCoins, (user, _auction.highBidder, _auction.bidAmount))
    );

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);
  }

  function test_Call_HighBidder_CancelAuctionedDebtWithSurplus(
    Auction memory _auction,
    uint256 _amountToBuy,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _totalOnAuctionDebt) {
    vm.expectCall(
      address(mockAccountingEngine),
      abi.encodeCall(
        mockAccountingEngine.cancelAuctionedDebtWithSurplus, (Math.min(_auction.bidAmount, _totalOnAuctionDebt))
      )
    );

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);
  }

  function testFail_Call_HighBidder_CancelAuctionedDebtWithSurplus(
    Auction memory _auction,
    uint256 _amountToBuy,
    uint256 _totalOnAuctionDebt
  ) public {
    uint48 _bidExpiry = _auction.bidExpiry;
    vm.assume(_bidExpiry > block.timestamp);

    _auction = _assumeHappyPath(_auction, _amountToBuy);
    _auction.bidExpiry = _bidExpiry;

    _mockAuction(_auction);
    _mockTotalOnAuctionDebt(_totalOnAuctionDebt);

    vm.expectCall(
      address(mockAccountingEngine),
      abi.encodeCall(
        mockAccountingEngine.cancelAuctionedDebtWithSurplus, (Math.min(_auction.bidAmount, _totalOnAuctionDebt))
      )
    );

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);
  }

  function test_Set_Bids_HighBidder(
    Auction memory _auction,
    uint256 _amountToBuy,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _totalOnAuctionDebt) {
    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);

    (,, address _highBidder,,) = debtAuctionHouse.bids(_auction.id);

    assertEq(_highBidder, user);
  }

  function test_Set_Bids_AmountToSell(
    Auction memory _auction,
    uint256 _amountToBuy,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _totalOnAuctionDebt) {
    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);

    (, uint256 _amountToSell,,,) = debtAuctionHouse.bids(_auction.id);

    assertEq(_amountToSell, _amountToBuy);
  }

  function test_Set_Bids_BidExpiry(
    Auction memory _auction,
    uint256 _amountToBuy,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _totalOnAuctionDebt) {
    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);

    (,,, uint48 _bidExpiry,) = debtAuctionHouse.bids(_auction.id);

    assertEq(_bidExpiry, block.timestamp + debtAuctionHouse.params().bidDuration);
  }

  function test_Emit_DecreaseSoldAmount(
    Auction memory _auction,
    uint256 _amountToBuy,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _totalOnAuctionDebt) {
    expectEmitNoIndex();
    emit DecreaseSoldAmount(
      _auction.id, user, _amountToBuy, _auction.bidAmount, block.timestamp + debtAuctionHouse.params().bidDuration
    );

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);
  }
}

contract Unit_DebtAuctionHouse_SettleAuction is Base {
  event SettleAuction(uint256 indexed _id, uint256 _activeDebtAuctions);

  modifier happyPath(Auction memory _auction, uint256 _activeDebtAuctions) {
    _assumeHappyPath(_auction, _activeDebtAuctions);
    _mockAuction(_auction);
    _mockActiveDebtAuctions(_activeDebtAuctions);
    _;
  }

  function _assumeHappyPath(Auction memory _auction, uint256 _activeDebtAuctions) internal view {
    vm.assume(_auction.bidExpiry != 0);
    vm.assume(_auction.bidExpiry < block.timestamp);
    vm.assume(_activeDebtAuctions > 0);
  }

  function test_Revert_ContractIsDisabled(Auction memory _auction) public {
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    debtAuctionHouse.settleAuction(_auction.id);
  }

  function test_Revert_NotFinished_0(Auction memory _auction) public {
    vm.assume(_auction.bidExpiry == 0);

    _mockAuction(_auction);

    vm.expectRevert('DebtAuctionHouse/not-finished');

    debtAuctionHouse.settleAuction(_auction.id);
  }

  function test_Revert_NotFinished_1(Auction memory _auction) public {
    vm.assume(_auction.bidExpiry >= block.timestamp);
    vm.assume(_auction.auctionDeadline >= block.timestamp);

    _mockAuction(_auction);

    vm.expectRevert('DebtAuctionHouse/not-finished');

    debtAuctionHouse.settleAuction(_auction.id);
  }

  function test_Call_ProtocolToken_Mint(Auction memory _auction, uint256 _activeDebtAuctions) public {
    vm.assume(_auction.bidExpiry >= block.timestamp);
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(_activeDebtAuctions > 0);

    _mockAuction(_auction);
    _mockActiveDebtAuctions(_activeDebtAuctions);

    vm.expectCall(
      address(mockProtocolToken), abi.encodeCall(mockProtocolToken.mint, (_auction.highBidder, _auction.amountToSell))
    );

    debtAuctionHouse.settleAuction(_auction.id);
  }

  function test_Set_ActiveDebtAuctions(
    Auction memory _auction,
    uint256 _activeDebtAuctions
  ) public happyPath(_auction, _activeDebtAuctions) {
    debtAuctionHouse.settleAuction(_auction.id);

    assertEq(debtAuctionHouse.activeDebtAuctions(), _activeDebtAuctions - 1);
  }

  function test_Set_Bids(
    Auction memory _auction,
    uint256 _activeDebtAuctions
  ) public happyPath(_auction, _activeDebtAuctions) {
    debtAuctionHouse.settleAuction(_auction.id);

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline) =
      debtAuctionHouse.bids(_auction.id);

    assertEq(_bidAmount, 0);
    assertEq(_amountToSell, 0);
    assertEq(_highBidder, address(0));
    assertEq(_bidExpiry, 0);
    assertEq(_auctionDeadline, 0);
  }

  function test_Emit_SettleAuction(
    Auction memory _auction,
    uint256 _activeDebtAuctions
  ) public happyPath(_auction, _activeDebtAuctions) {
    expectEmitNoIndex();
    emit SettleAuction(_auction.id, _activeDebtAuctions - 1);

    debtAuctionHouse.settleAuction(_auction.id);
  }
}

contract Unit_DebtAuctionHouse_TerminateAuctionPrematurely is Base {
  event TerminateAuctionPrematurely(
    uint256 indexed _id, address _sender, address _highBidder, uint256 _bidAmount, uint256 _activeDebtAuctions
  );

  function setUp() public override {
    Base.setUp();

    vm.startPrank(user);
  }

  modifier happyPath(Auction memory _auction) {
    _assumeHappyPath(_auction);
    _mockContractEnabled(0);
    _mockAuction(_auction);
    _;
  }

  function _assumeHappyPath(Auction memory _auction) internal pure {
    vm.assume(_auction.highBidder != address(0));
  }

  function test_Revert_ContractIsEnabled(Auction memory _auction) public {
    _mockContractEnabled(1);

    vm.expectRevert(IDisableable.ContractIsEnabled.selector);

    debtAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Revert_HighBidderNotSet(Auction memory _auction) public {
    _auction.highBidder = address(0);

    _mockContractEnabled(0);
    _mockAuction(_auction);

    vm.expectRevert('DebtAuctionHouse/high-bidder-not-set');

    debtAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Call_SafeEngine_CreateUnbackedDebt(Auction memory _auction) public happyPath(_auction) {
    _mockAccountingEngine(address(mockAccountingEngine));

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.createUnbackedDebt, (address(mockAccountingEngine), _auction.highBidder, _auction.bidAmount)
      )
    );

    debtAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Emit_TerminateAuctionPrematurely(
    Auction memory _auction,
    uint256 _activeDebtAuctions
  ) public happyPath(_auction) {
    _mockActiveDebtAuctions(_activeDebtAuctions);

    expectEmitNoIndex();
    emit TerminateAuctionPrematurely(_auction.id, user, _auction.highBidder, _auction.bidAmount, _activeDebtAuctions);

    debtAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Set_Bids(Auction memory _auction) public happyPath(_auction) {
    debtAuctionHouse.terminateAuctionPrematurely(_auction.id);

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline) =
      debtAuctionHouse.bids(_auction.id);

    assertEq(_bidAmount, 0);
    assertEq(_amountToSell, 0);
    assertEq(_highBidder, address(0));
    assertEq(_bidExpiry, 0);
    assertEq(_auctionDeadline, 0);
  }
}

contract Unit_DebtAuctionHouse_ModifyParameters is Base {
  event ModifyParameters(bytes32 indexed _parameter, bytes32 indexed _collateralType, bytes _data);

  function test_Revert_Unauthorized(bytes32 _parameter, bytes memory _data) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    debtAuctionHouse.modifyParameters(_parameter, _data);
  }

  function test_Revert_ContractIsDisabled(bytes32 _parameter, bytes memory _data) public authorized {
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    debtAuctionHouse.modifyParameters(_parameter, _data);
  }

  function test_Set_Parameters(IDebtAuctionHouse.DebtAuctionHouseParams memory _fuzz) public authorized {
    debtAuctionHouse.modifyParameters('bidDecrease', abi.encode(_fuzz.bidDecrease));
    debtAuctionHouse.modifyParameters('amountSoldIncrease', abi.encode(_fuzz.amountSoldIncrease));
    debtAuctionHouse.modifyParameters('bidDuration', abi.encode(_fuzz.bidDuration));
    debtAuctionHouse.modifyParameters('totalAuctionLength', abi.encode(_fuzz.totalAuctionLength));

    IDebtAuctionHouse.DebtAuctionHouseParams memory _params = debtAuctionHouse.params();

    assertEq(keccak256(abi.encode(_params)), keccak256(abi.encode(_fuzz)));
  }

  function test_Set_ProtocolToken(address _protocolToken) public authorized {
    debtAuctionHouse.modifyParameters('protocolToken', abi.encode(_protocolToken));

    assertEq(address(debtAuctionHouse.protocolToken()), _protocolToken);
  }

  function test_Set_AccountingEngine(address _accountingEngine) public authorized {
    debtAuctionHouse.modifyParameters('accountingEngine', abi.encode(_accountingEngine));

    assertEq(debtAuctionHouse.accountingEngine(), _accountingEngine);
  }

  function test_Revert_UnrecognizedParam() public authorized {
    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    debtAuctionHouse.modifyParameters('unrecognizedParam', abi.encode(0));
  }

  function test_Emit_ModifyParameters(address _accountingEngine) public authorized {
    expectEmitNoIndex();
    emit ModifyParameters('accountingEngine', GLOBAL_PARAM, abi.encode(_accountingEngine));

    debtAuctionHouse.modifyParameters('accountingEngine', abi.encode(_accountingEngine));
  }
}

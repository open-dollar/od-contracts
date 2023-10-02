// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {DebtAuctionHouseForTest, IDebtAuctionHouse, DebtAuctionHouse} from '@test/mocks/DebtAuctionHouseForTest.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

import {Math, WAD} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  struct DebtAuction {
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
  IAccountingEngine mockAccountingEngine = IAccountingEngine(mockContract('AccountingEngine'));

  DebtAuctionHouseForTest debtAuctionHouse;

  IDebtAuctionHouse.DebtAuctionHouseParams dahParams = IDebtAuctionHouse.DebtAuctionHouseParams({
    bidDecrease: 1.05e18,
    amountSoldIncrease: 1.5e18,
    bidDuration: 3 hours,
    totalAuctionLength: 2 days
  });

  function setUp() public virtual {
    vm.startPrank(deployer);

    debtAuctionHouse = new DebtAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken), dahParams);
    label(address(debtAuctionHouse), 'DebtAuctionHouse');

    debtAuctionHouse.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockTotalOnAuctionDebt(uint256 _totalOnAuctionDebt) internal {
    vm.mockCall(
      address(mockAccountingEngine),
      abi.encodeCall(mockAccountingEngine.totalOnAuctionDebt, ()),
      abi.encode(_totalOnAuctionDebt)
    );
  }

  function _mockContractEnabled(bool _contractEnabled) internal {
    stdstore.target(address(debtAuctionHouse)).sig(IDisableable.contractEnabled.selector).checked_write(
      _contractEnabled
    );
  }

  function _mockAuction(DebtAuction memory _auction) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    debtAuctionHouse.addAuction(
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

  function _mockAmountSoldIncrease(uint256 _amountSoldIncrease) internal {
    stdstore.target(address(debtAuctionHouse)).sig(IDebtAuctionHouse.params.selector).depth(1).checked_write(
      _amountSoldIncrease
    );
  }

  function _mockBidDuration(uint256 _bidDuration) internal {
    stdstore.target(address(debtAuctionHouse)).sig(IDebtAuctionHouse.params.selector).depth(2).checked_write(
      _bidDuration
    );
  }

  function _mockTotalAuctionLength(uint256 _totalAuctionLength) internal {
    stdstore.target(address(debtAuctionHouse)).sig(IDebtAuctionHouse.params.selector).depth(3).checked_write(
      _totalAuctionLength
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

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new DebtAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken), dahParams);
  }

  function test_Set_ContractEnabled() public happyPath {
    assertEq(debtAuctionHouse.contractEnabled(), true);
  }

  function test_Set_SafeEngine(address _safeEngine) public happyPath mockAsContract(_safeEngine) {
    debtAuctionHouse = new DebtAuctionHouseForTest(_safeEngine, address(mockProtocolToken), dahParams);

    assertEq(address(debtAuctionHouse.safeEngine()), _safeEngine);
  }

  function test_Set_ProtocolToken(address _protocolToken) public happyPath mockAsContract(_protocolToken) {
    debtAuctionHouse = new DebtAuctionHouseForTest(address(mockSafeEngine), _protocolToken, dahParams);

    assertEq(address(debtAuctionHouse.protocolToken()), _protocolToken);
  }

  function test_Set_DAH_Params(IDebtAuctionHouse.DebtAuctionHouseParams memory _dahParams) public happyPath {
    debtAuctionHouse = new DebtAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken), _dahParams);

    assertEq(abi.encode(debtAuctionHouse.params()), abi.encode(_dahParams));
  }

  function test_Revert_Null_SafeEngine() public {
    vm.expectRevert(Assertions.NullAddress.selector);

    new DebtAuctionHouseForTest(address(0), address(mockProtocolToken), dahParams);
  }

  function test_Revert_Null_ProtocolToken() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new DebtAuctionHouseForTest(address(mockSafeEngine), address(0), dahParams);
  }
}

contract Unit_DebtAuctionHouse_DisableContract is Base {
  event DisableContract();

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_AccountingEngine() public happyPath {
    debtAuctionHouse.disableContract();

    assertEq(debtAuctionHouse.accountingEngine(), authorizedAccount);
  }

  function test_Set_ActiveDebtAuctions(uint256 _activeDebtAuctions) public happyPath {
    vm.assume(_activeDebtAuctions != 0);

    _mockActiveDebtAuctions(_activeDebtAuctions);

    debtAuctionHouse.disableContract();

    assertEq(debtAuctionHouse.activeDebtAuctions(), 0);
  }
}

contract Unit_DebtAuctionHouse_StartAuction is Base {
  event StartAuction(
    uint256 indexed _id,
    address indexed _auctioneer,
    uint256 _blockTimestamp,
    uint256 _amountToSell,
    uint256 _amountToRaise,
    uint256 _auctionDeadline
  );

  modifier happyPath(uint256 _auctionsStarted, uint256 _activeDebtAuctions, uint256 _totalAuctionLength) {
    vm.startPrank(authorizedAccount);

    _assumeHappyPath(_auctionsStarted, _activeDebtAuctions, _totalAuctionLength);
    _mockValues(_auctionsStarted, _activeDebtAuctions, _totalAuctionLength);
    _;
  }

  function _assumeHappyPath(
    uint256 _auctionsStarted,
    uint256 _activeDebtAuctions,
    uint256 _totalAuctionLength
  ) internal view {
    vm.assume(_auctionsStarted < type(uint256).max);
    vm.assume(notOverflowAdd(block.timestamp, _totalAuctionLength));
    vm.assume(_activeDebtAuctions < type(uint256).max);
  }

  function _mockValues(uint256 _auctionsStarted, uint256 _activeDebtAuctions, uint256 _totalAuctionLength) internal {
    _mockAuctionsStarted(_auctionsStarted);
    _mockActiveDebtAuctions(_activeDebtAuctions);
    _mockTotalAuctionLength(_totalAuctionLength);
  }

  function test_Revert_Unauthorized(address _incomeReceiver, uint256 _amountToSell, uint256 _initialBid) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid);
  }

  function test_Revert_ContractIsDisabled(address _incomeReceiver, uint256 _amountToSell, uint256 _initialBid) public {
    vm.startPrank(authorizedAccount);

    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid);
  }

  function test_Revert_Overflow_0(address _incomeReceiver, uint256 _amountToSell, uint256 _initialBid) public {
    vm.startPrank(authorizedAccount);

    _mockValues(type(uint256).max, 0, 0);

    vm.expectRevert();

    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid);
  }

  function test_Revert_Overflow_1(
    address _incomeReceiver,
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint256 _totalAuctionLength
  ) public {
    vm.startPrank(authorizedAccount);
    vm.assume(_auctionsStarted < type(uint256).max);
    vm.assume(notOverflowAdd(block.timestamp, _totalAuctionLength));

    _mockValues(_auctionsStarted, type(uint256).max, _totalAuctionLength);

    vm.expectRevert();

    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid);
  }

  function test_Set_AuctionsStarted(
    address _incomeReceiver,
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint256 _activeDebtAuctions,
    uint256 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _activeDebtAuctions, _totalAuctionLength) {
    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid);

    assertEq(debtAuctionHouse.auctionsStarted(), _auctionsStarted + 1);
  }

  function test_Set_Auctions(
    address _incomeReceiver,
    uint256 _amountToSellFuzzed,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint256 _activeDebtAuctions,
    uint256 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _activeDebtAuctions, _totalAuctionLength) {
    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSellFuzzed, _initialBid);

    IDebtAuctionHouse.Auction memory _auction = debtAuctionHouse.auctions(_auctionsStarted + 1);
    assertEq(_auction.bidAmount, _initialBid);
    assertEq(_auction.amountToSell, _amountToSellFuzzed);
    assertEq(_auction.highBidder, _incomeReceiver);
    assertEq(_auction.bidExpiry, 0);
    assertEq(_auction.auctionDeadline, block.timestamp + _totalAuctionLength);
  }

  function test_Set_ActiveDebtAuctions(
    address _incomeReceiver,
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint256 _activeDebtAuctions,
    uint256 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _activeDebtAuctions, _totalAuctionLength) {
    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid);

    assertEq(debtAuctionHouse.activeDebtAuctions(), _activeDebtAuctions + 1);
  }

  function test_Emit_StartAuction(
    address _incomeReceiver,
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint256 _activeDebtAuctions,
    uint256 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _activeDebtAuctions, _totalAuctionLength) {
    vm.expectEmit();
    emit StartAuction(
      _auctionsStarted + 1,
      authorizedAccount,
      block.timestamp,
      _amountToSell,
      _initialBid,
      block.timestamp + _totalAuctionLength
    );

    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid);
  }

  function test_Return_Id(
    address _incomeReceiver,
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint256 _activeDebtAuctions,
    uint256 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _activeDebtAuctions, _totalAuctionLength) {
    assertEq(debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid), _auctionsStarted + 1);
  }
}

contract Unit_DebtAuctionHouse_RestartAuction is Base {
  event RestartAuction(uint256 indexed _id, uint256 _blockTimestamp, uint256 _auctionDeadline);

  modifier happyPath(
    DebtAuction memory _auction,
    uint256 _auctionsStarted,
    uint256 _amountSoldIncrease,
    uint256 _totalAuctionLength
  ) {
    _assumeHappyPath(_auction, _auctionsStarted, _amountSoldIncrease, _totalAuctionLength);
    _mockValues(_auction, _auctionsStarted, _amountSoldIncrease, _totalAuctionLength);
    _;
  }

  function _assumeHappyPath(
    DebtAuction memory _auction,
    uint256 _auctionsStarted,
    uint256 _amountSoldIncrease,
    uint256 _totalAuctionLength
  ) internal view {
    vm.assume(_auction.id > 0 && _auction.id <= _auctionsStarted);
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(_auction.bidExpiry == 0);
    vm.assume(notOverflowMul(_amountSoldIncrease, _auction.amountToSell));
    vm.assume(notOverflowAdd(block.timestamp, _totalAuctionLength));
  }

  function _mockValues(
    DebtAuction memory _auction,
    uint256 _auctionsStarted,
    uint256 _amountSoldIncrease,
    uint256 _totalAuctionLength
  ) internal {
    _mockAuction(_auction);
    _mockAuctionsStarted(_auctionsStarted);
    _mockAmountSoldIncrease(_amountSoldIncrease);
    _mockTotalAuctionLength(_totalAuctionLength);
  }

  function test_Revert_AuctionNeverStarted_0(DebtAuction memory _auction) public {
    vm.assume(_auction.id == 0);

    _mockValues(_auction, 0, 0, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_AuctionNeverStarted.selector);

    debtAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_AuctionNeverStarted_1(DebtAuction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id > _auctionsStarted);

    _mockValues(_auction, _auctionsStarted, 0, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_AuctionNeverStarted.selector);

    debtAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_NotFinished(DebtAuction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id > 0 && _auction.id <= _auctionsStarted);
    vm.assume(_auction.auctionDeadline > block.timestamp);

    _mockValues(_auction, _auctionsStarted, 0, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_AuctionNotFinished.selector);

    debtAuctionHouse.restartAuction(_auction.id);
  }

  function test_Revert_BidAlreadyPlaced(DebtAuction memory _auction, uint256 _auctionsStarted) public {
    vm.assume(_auction.id > 0 && _auction.id <= _auctionsStarted);
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(_auction.bidExpiry != 0);

    _mockValues(_auction, _auctionsStarted, 0, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_BidAlreadyPlaced.selector);

    debtAuctionHouse.restartAuction(_auction.id);
  }

  function test_Set_Auctions_AmountToSell(
    DebtAuction memory _auction,
    uint256 _auctionsStarted,
    uint256 _amountSoldIncrease,
    uint256 _totalAuctionLength
  ) public happyPath(_auction, _auctionsStarted, _amountSoldIncrease, _totalAuctionLength) {
    debtAuctionHouse.restartAuction(_auction.id);

    assertEq(debtAuctionHouse.auctions(_auction.id).amountToSell, (_amountSoldIncrease * _auction.amountToSell) / WAD);
  }

  function test_Set_Auctions_AuctionDeadline(
    DebtAuction memory _auction,
    uint256 _auctionsStarted,
    uint256 _amountSoldIncrease,
    uint256 _totalAuctionLength
  ) public happyPath(_auction, _auctionsStarted, _amountSoldIncrease, _totalAuctionLength) {
    debtAuctionHouse.restartAuction(_auction.id);

    assertEq(debtAuctionHouse.auctions(_auction.id).auctionDeadline, block.timestamp + _totalAuctionLength);
  }

  function test_Emit_RestartAuction(
    DebtAuction memory _auction,
    uint256 _auctionsStarted,
    uint256 _amountSoldIncrease,
    uint256 _totalAuctionLength
  ) public happyPath(_auction, _auctionsStarted, _amountSoldIncrease, _totalAuctionLength) {
    vm.expectEmit();
    emit RestartAuction(_auction.id, block.timestamp, block.timestamp + _totalAuctionLength);

    debtAuctionHouse.restartAuction(_auction.id);
  }
}

contract Unit_DebtAuctionHouse_DecreaseSoldAmount is Base {
  event DecreaseSoldAmount(
    uint256 indexed _id,
    address _bidder,
    uint256 _blockTimestamp,
    uint256 _raisedAmount,
    uint256 _soldAmount,
    uint256 _bidExpiry
  );

  modifier happyPath(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease,
    uint256 _bidDuration,
    uint256 _totalOnAuctionDebt
  ) {
    vm.startPrank(user);

    _assumeHappyPath(_auction, _amountToBuy, _bidDecrease, _bidDuration);
    _mockValues(_auction, _bidDecrease, _bidDuration, _totalOnAuctionDebt);
    _;
  }

  function _assumeHappyPath(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease,
    uint256 _bidDuration
  ) internal view {
    _auction.highBidder = address(mockAccountingEngine);

    vm.assume(_auction.bidExpiry > block.timestamp || _auction.bidExpiry == 0);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_amountToBuy < _auction.amountToSell);
    vm.assume(notOverflowMul(_bidDecrease, _amountToBuy));
    vm.assume(notOverflowMul(_auction.amountToSell, WAD));
    vm.assume(_bidDecrease * _amountToBuy <= _auction.amountToSell * WAD);
    vm.assume(notOverflowAdd(block.timestamp, _bidDuration));
  }

  function _mockValues(
    DebtAuction memory _auction,
    uint256 _bidDecrease,
    uint256 _bidDuration,
    uint256 _totalOnAuctionDebt
  ) internal {
    _mockAuction(_auction);
    _mockBidDecrease(_bidDecrease);
    _mockBidDuration(_bidDuration);
    _mockTotalOnAuctionDebt(_totalOnAuctionDebt);
  }

  function test_Revert_ContractIsDisabled(DebtAuction memory _auction, uint256 _amountToBuy) public {
    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy);
  }

  function test_Revert_HighBidderNotSet(DebtAuction memory _auction, uint256 _amountToBuy) public {
    _auction.highBidder = address(0);

    _mockValues(_auction, 0, 0, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_HighBidderNotSet.selector);

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy);
  }

  function test_Revert_BidAlreadyExpired(DebtAuction memory _auction, uint256 _amountToBuy) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry != 0 && _auction.bidExpiry <= block.timestamp);

    _mockValues(_auction, 0, 0, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_BidAlreadyExpired.selector);

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy);
  }

  function test_Revert_AuctionAlreadyExpired(DebtAuction memory _auction, uint256 _amountToBuy) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline <= block.timestamp);

    _mockValues(_auction, 0, 0, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_AuctionAlreadyExpired.selector);

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy);
  }

  function test_Revert_AmountBoughtNotLower(DebtAuction memory _auction, uint256 _amountToBuy) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_amountToBuy >= _auction.amountToSell);

    _mockValues(_auction, 0, 0, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_AmountBoughtNotLower.selector);

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy);
  }

  function test_Revert_InsufficientDecrease(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease
  ) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_amountToBuy < _auction.amountToSell);
    vm.assume(notOverflowMul(_bidDecrease, _amountToBuy));
    vm.assume(notOverflowMul(_auction.amountToSell, WAD));
    vm.assume(_bidDecrease * _amountToBuy > _auction.amountToSell * WAD);

    _mockValues(_auction, _bidDecrease, 0, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_InsufficientDecrease.selector);

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy);
  }

  function test_Call_SafeEngine_TransferInternalCoins(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    IDebtAuctionHouse.DebtAuctionHouseParams memory _dahParams,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _dahParams.bidDecrease, _dahParams.bidDuration, _totalOnAuctionDebt) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.transferInternalCoins, (user, _auction.highBidder, _auction.bidAmount)),
      1
    );

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy);
  }

  function test_NotCall_HighBidder_CancelAuctionedDebtWithSurplus(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease,
    uint256 _bidDuration,
    uint256 _totalOnAuctionDebt
  ) public {
    vm.assume(_auction.bidExpiry > block.timestamp);

    _assumeHappyPath(_auction, _amountToBuy, _bidDecrease, _bidDuration);
    _mockValues(_auction, _bidDecrease, _bidDuration, _totalOnAuctionDebt);

    vm.expectCall(
      address(mockAccountingEngine),
      abi.encodeCall(
        mockAccountingEngine.cancelAuctionedDebtWithSurplus, (Math.min(_auction.bidAmount, _totalOnAuctionDebt))
      ),
      0
    );

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy);
  }

  function test_Call_HighBidder_CancelAuctionedDebtWithSurplus(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease,
    uint256 _bidDuration,
    uint256 _totalOnAuctionDebt
  ) public {
    vm.assume(_auction.bidExpiry == 0);

    _assumeHappyPath(_auction, _amountToBuy, _bidDecrease, _bidDuration);
    _mockValues(_auction, _bidDecrease, _bidDuration, _totalOnAuctionDebt);

    vm.expectCall(
      address(mockAccountingEngine),
      abi.encodeCall(
        mockAccountingEngine.cancelAuctionedDebtWithSurplus, (Math.min(_auction.bidAmount, _totalOnAuctionDebt))
      ),
      1
    );

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy);
  }

  function test_Set_Auctions_HighBidder(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease,
    uint256 _bidDuration,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _bidDecrease, _bidDuration, _totalOnAuctionDebt) {
    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy);

    assertEq(debtAuctionHouse.auctions(_auction.id).highBidder, user);
  }

  function test_Set_Auctions_AmountToSell(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease,
    uint256 _bidDuration,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _bidDecrease, _bidDuration, _totalOnAuctionDebt) {
    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy);

    assertEq(debtAuctionHouse.auctions(_auction.id).amountToSell, _amountToBuy);
  }

  function test_Set_Auctions_BidExpiry(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease,
    uint256 _bidDuration,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _bidDecrease, _bidDuration, _totalOnAuctionDebt) {
    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy);

    assertEq(debtAuctionHouse.auctions(_auction.id).bidExpiry, block.timestamp + _bidDuration);
  }

  function test_Emit_DecreaseSoldAmount(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease,
    uint256 _bidDuration,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _bidDecrease, _bidDuration, _totalOnAuctionDebt) {
    vm.expectEmit();
    emit DecreaseSoldAmount(
      _auction.id, user, block.timestamp, _auction.bidAmount, _amountToBuy, block.timestamp + _bidDuration
    );

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy);
  }
}

contract Unit_DebtAuctionHouse_SettleAuction is Base {
  event SettleAuction(uint256 indexed _id, uint256 _blockTimestamp, address _highBidder, uint256 _raisedAmount);

  modifier happyPath(DebtAuction memory _auction, uint256 _activeDebtAuctions) {
    _assumeHappyPath(_auction, _activeDebtAuctions);
    _mockValues(_auction, _activeDebtAuctions);
    _;
  }

  function _assumeHappyPath(DebtAuction memory _auction, uint256 _activeDebtAuctions) internal view {
    vm.assume(
      _auction.bidExpiry != 0 && (_auction.bidExpiry < block.timestamp || _auction.auctionDeadline < block.timestamp)
    );
    vm.assume(_activeDebtAuctions > 0);
  }

  function _mockValues(DebtAuction memory _auction, uint256 _activeDebtAuctions) internal {
    _mockAuction(_auction);
    _mockActiveDebtAuctions(_activeDebtAuctions);
  }

  function test_Revert_ContractIsDisabled(DebtAuction memory _auction) public {
    _mockContractEnabled(false);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    debtAuctionHouse.settleAuction(_auction.id);
  }

  function test_Revert_NotFinished_0(DebtAuction memory _auction) public {
    vm.assume(_auction.bidExpiry == 0);

    _mockValues(_auction, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_AuctionNotFinished.selector);

    debtAuctionHouse.settleAuction(_auction.id);
  }

  function test_Revert_NotFinished_1(DebtAuction memory _auction) public {
    vm.assume(_auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);

    _mockValues(_auction, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_AuctionNotFinished.selector);

    debtAuctionHouse.settleAuction(_auction.id);
  }

  function test_Call_ProtocolToken_Mint(
    DebtAuction memory _auction,
    uint256 _activeDebtAuctions
  ) public happyPath(_auction, _activeDebtAuctions) {
    vm.expectCall(
      address(mockProtocolToken),
      abi.encodeCall(mockProtocolToken.mint, (_auction.highBidder, _auction.amountToSell)),
      1
    );

    debtAuctionHouse.settleAuction(_auction.id);
  }

  function test_Set_ActiveDebtAuctions(
    DebtAuction memory _auction,
    uint256 _activeDebtAuctions
  ) public happyPath(_auction, _activeDebtAuctions) {
    debtAuctionHouse.settleAuction(_auction.id);

    assertEq(debtAuctionHouse.activeDebtAuctions(), _activeDebtAuctions - 1);
  }

  function test_Set_Auctions(
    DebtAuction memory _auction,
    uint256 _activeDebtAuctions
  ) public happyPath(_auction, _activeDebtAuctions) {
    debtAuctionHouse.settleAuction(_auction.id);

    IDebtAuctionHouse.Auction memory __auction = debtAuctionHouse.auctions(_auction.id);
    assertEq(__auction.bidAmount, 0);
    assertEq(__auction.amountToSell, 0);
    assertEq(__auction.highBidder, address(0));
    assertEq(__auction.bidExpiry, 0);
    assertEq(__auction.auctionDeadline, 0);
  }

  function test_Emit_SettleAuction(
    DebtAuction memory _auction,
    uint256 _activeDebtAuctions
  ) public happyPath(_auction, _activeDebtAuctions) {
    vm.expectEmit();
    emit SettleAuction(_auction.id, block.timestamp, _auction.highBidder, _auction.bidAmount);

    debtAuctionHouse.settleAuction(_auction.id);
  }
}

contract Unit_DebtAuctionHouse_TerminateAuctionPrematurely is Base {
  event TerminateAuctionPrematurely(
    uint256 indexed _id, uint256 _blockTimestamp, address _highBidder, uint256 _raisedAmount
  );

  modifier happyPath(DebtAuction memory _auction, uint256 _activeDebtAuctions) {
    vm.startPrank(user);

    _assumeHappyPath(_auction);
    _mockValues(_auction, _activeDebtAuctions);
    _;
  }

  function _assumeHappyPath(DebtAuction memory _auction) internal pure {
    vm.assume(_auction.highBidder != address(0));
  }

  function _mockValues(DebtAuction memory _auction, uint256 _activeDebtAuctions) internal {
    _mockContractEnabled(false);
    _mockAuction(_auction);
    _mockActiveDebtAuctions(_activeDebtAuctions);
    _mockAccountingEngine(address(mockAccountingEngine));
  }

  function test_Revert_ContractIsEnabled(DebtAuction memory _auction) public {
    vm.expectRevert(IDisableable.ContractIsEnabled.selector);

    debtAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Revert_HighBidderNotSet(DebtAuction memory _auction) public {
    _auction.highBidder = address(0);

    _mockValues(_auction, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_HighBidderNotSet.selector);

    debtAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Call_SafeEngine_CreateUnbackedDebt(
    DebtAuction memory _auction,
    uint256 _activeDebtAuctions
  ) public happyPath(_auction, _activeDebtAuctions) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.createUnbackedDebt, (address(mockAccountingEngine), _auction.highBidder, _auction.bidAmount)
      ),
      1
    );

    debtAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Emit_TerminateAuctionPrematurely(
    DebtAuction memory _auction,
    uint256 _activeDebtAuctions
  ) public happyPath(_auction, _activeDebtAuctions) {
    vm.expectEmit();
    emit TerminateAuctionPrematurely(_auction.id, block.timestamp, _auction.highBidder, _auction.bidAmount);

    debtAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Set_Auctions(
    DebtAuction memory _auction,
    uint256 _activeDebtAuctions
  ) public happyPath(_auction, _activeDebtAuctions) {
    debtAuctionHouse.terminateAuctionPrematurely(_auction.id);

    IDebtAuctionHouse.Auction memory __auction = debtAuctionHouse.auctions(_auction.id);
    assertEq(__auction.bidAmount, 0);
    assertEq(__auction.amountToSell, 0);
    assertEq(__auction.highBidder, address(0));
    assertEq(__auction.bidExpiry, 0);
    assertEq(__auction.auctionDeadline, 0);
  }
}

contract Unit_DebtAuctionHouse_ModifyParameters is Base {
  event ModifyParameters(bytes32 indexed _param, bytes32 indexed _cType, bytes _data);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_Parameters(IDebtAuctionHouse.DebtAuctionHouseParams memory _fuzz) public happyPath {
    debtAuctionHouse.modifyParameters('bidDecrease', abi.encode(_fuzz.bidDecrease));
    debtAuctionHouse.modifyParameters('amountSoldIncrease', abi.encode(_fuzz.amountSoldIncrease));
    debtAuctionHouse.modifyParameters('bidDuration', abi.encode(_fuzz.bidDuration));
    debtAuctionHouse.modifyParameters('totalAuctionLength', abi.encode(_fuzz.totalAuctionLength));

    IDebtAuctionHouse.DebtAuctionHouseParams memory _params = debtAuctionHouse.params();

    assertEq(abi.encode(_params), abi.encode(_fuzz));
  }

  function test_Set_ProtocolToken(address _protocolToken) public happyPath mockAsContract(_protocolToken) {
    debtAuctionHouse.modifyParameters('protocolToken', abi.encode(_protocolToken));

    assertEq(address(debtAuctionHouse.protocolToken()), _protocolToken);
  }

  function test_Revert_ProtocolToken_NullAddress() public {
    vm.startPrank(authorizedAccount);
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    debtAuctionHouse.modifyParameters('protocolToken', abi.encode(0));
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);
    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    debtAuctionHouse.modifyParameters('unrecognizedParam', _data);
  }
}

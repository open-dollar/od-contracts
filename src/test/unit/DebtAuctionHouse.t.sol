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

  struct DebtAuction {
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

  function _mockAuction(DebtAuction memory _auction) internal {
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

  function _mockAmountSoldIncrease(uint256 _amountSoldIncrease) internal {
    stdstore.target(address(debtAuctionHouse)).sig(IDebtAuctionHouse.params.selector).depth(1).checked_write(
      _amountSoldIncrease
    );
  }

  function _mockBidDuration(uint48 _bidDuration) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    debtAuctionHouse.setBidDuration(_bidDuration);
  }

  function _mockTotalAuctionLength(uint48 _totalAuctionLength) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    debtAuctionHouse.setTotalAuctionLength(_totalAuctionLength);
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
    expectEmitNoIndex();
    emit AddAuthorization(user);

    debtAuctionHouse = new DebtAuctionHouseForTest(address(mockSafeEngine), address(mockProtocolToken));
  }

  function test_Set_ContractEnabled() public happyPath {
    assertEq(debtAuctionHouse.contractEnabled(), 1);
  }

  function test_Set_SafeEngine(address _safeEngine) public happyPath {
    debtAuctionHouse = new DebtAuctionHouseForTest(_safeEngine, address(mockProtocolToken));

    assertEq(address(debtAuctionHouse.safeEngine()), _safeEngine);
  }

  function test_Set_ProtocolToken(address _protocolToken) public happyPath {
    debtAuctionHouse = new DebtAuctionHouseForTest(address(mockSafeEngine), _protocolToken);

    assertEq(address(debtAuctionHouse.protocolToken()), _protocolToken);
  }

  function test_Set_BidDecrease() public happyPath {
    assertEq(debtAuctionHouse.params().bidDecrease, 1.05e18);
  }

  function test_Set_AmountSoldIncrease() public happyPath {
    assertEq(debtAuctionHouse.params().amountSoldIncrease, 1.5e18);
  }

  function test_Set_BidDuration() public happyPath {
    assertEq(debtAuctionHouse.params().bidDuration, 3 hours);
  }

  function test_Set_TotalAuctionLength() public happyPath {
    assertEq(debtAuctionHouse.params().totalAuctionLength, 2 days);
  }
}

contract Unit_DebtAuctionHouse_DisableContract is Base {
  event DisableContract();

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    debtAuctionHouse.disableContract();
  }

  function test_Emit_DisableContract() public happyPath {
    expectEmitNoIndex();
    emit DisableContract();

    debtAuctionHouse.disableContract();
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
    uint256 _auctionsStarted,
    uint256 _amountToSell,
    uint256 _initialBid,
    address indexed _incomeReceiver,
    uint256 indexed _auctionDeadline,
    uint256 _activeDebtAuctions
  );

  modifier happyPath(uint256 _auctionsStarted, uint256 _activeDebtAuctions, uint48 _totalAuctionLength) {
    vm.startPrank(authorizedAccount);

    _assumeHappyPath(_auctionsStarted, _activeDebtAuctions, _totalAuctionLength);
    _mockValues(_auctionsStarted, _activeDebtAuctions, _totalAuctionLength);
    _;
  }

  function _assumeHappyPath(
    uint256 _auctionsStarted,
    uint256 _activeDebtAuctions,
    uint48 _totalAuctionLength
  ) internal view {
    vm.assume(_auctionsStarted < type(uint256).max);
    vm.assume(notOverflowAddUint48(uint48(block.timestamp), _totalAuctionLength));
    vm.assume(_activeDebtAuctions < type(uint256).max);
  }

  function _mockValues(uint256 _auctionsStarted, uint256 _activeDebtAuctions, uint48 _totalAuctionLength) internal {
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

    _mockContractEnabled(0);

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
    uint48 _totalAuctionLength
  ) public {
    vm.startPrank(authorizedAccount);
    vm.assume(_auctionsStarted < type(uint256).max);
    vm.assume(notOverflowAddUint48(uint48(block.timestamp), _totalAuctionLength));

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
    uint48 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _activeDebtAuctions, _totalAuctionLength) {
    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid);

    assertEq(debtAuctionHouse.auctionsStarted(), _auctionsStarted + 1);
  }

  function test_Set_Bids(
    address _incomeReceiver,
    uint256 _amountToSellFuzzed,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint256 _activeDebtAuctions,
    uint48 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _activeDebtAuctions, _totalAuctionLength) {
    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSellFuzzed, _initialBid);

    (uint256 _bidAmount, uint256 _amountToSell, address _highBidder, uint48 _bidExpiry, uint48 _auctionDeadline) =
      debtAuctionHouse.bids(_auctionsStarted + 1);

    assertEq(_bidAmount, _initialBid);
    assertEq(_amountToSell, _amountToSellFuzzed);
    assertEq(_highBidder, _incomeReceiver);
    assertEq(_bidExpiry, 0);
    assertEq(_auctionDeadline, block.timestamp + _totalAuctionLength);
  }

  function test_Set_ActiveDebtAuctions(
    address _incomeReceiver,
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint256 _activeDebtAuctions,
    uint48 _totalAuctionLength
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
    uint48 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _activeDebtAuctions, _totalAuctionLength) {
    expectEmitNoIndex();
    emit StartAuction(
      _auctionsStarted + 1,
      _auctionsStarted + 1,
      _amountToSell,
      _initialBid,
      _incomeReceiver,
      block.timestamp + _totalAuctionLength,
      _activeDebtAuctions + 1
    );

    debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid);
  }

  function test_Return_Id(
    address _incomeReceiver,
    uint256 _amountToSell,
    uint256 _initialBid,
    uint256 _auctionsStarted,
    uint256 _activeDebtAuctions,
    uint48 _totalAuctionLength
  ) public happyPath(_auctionsStarted, _activeDebtAuctions, _totalAuctionLength) {
    assertEq(debtAuctionHouse.startAuction(_incomeReceiver, _amountToSell, _initialBid), _auctionsStarted + 1);
  }
}

contract Unit_DebtAuctionHouse_RestartAuction is Base {
  event RestartAuction(uint256 indexed _id, uint256 _auctionDeadline);

  modifier happyPath(
    DebtAuction memory _auction,
    uint256 _auctionsStarted,
    uint256 _amountSoldIncrease,
    uint48 _totalAuctionLength
  ) {
    _assumeHappyPath(_auction, _auctionsStarted, _amountSoldIncrease, _totalAuctionLength);
    _mockValues(_auction, _auctionsStarted, _amountSoldIncrease, _totalAuctionLength);
    _;
  }

  function _assumeHappyPath(
    DebtAuction memory _auction,
    uint256 _auctionsStarted,
    uint256 _amountSoldIncrease,
    uint48 _totalAuctionLength
  ) internal view {
    vm.assume(_auction.id > 0 && _auction.id <= _auctionsStarted);
    vm.assume(_auction.auctionDeadline < block.timestamp);
    vm.assume(_auction.bidExpiry == 0);
    vm.assume(notOverflowMul(_amountSoldIncrease, _auction.amountToSell));
    vm.assume(notOverflowAddUint48(uint48(block.timestamp), _totalAuctionLength));
  }

  function _mockValues(
    DebtAuction memory _auction,
    uint256 _auctionsStarted,
    uint256 _amountSoldIncrease,
    uint48 _totalAuctionLength
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

  function test_Set_Bids_AmountToSell(
    DebtAuction memory _auction,
    uint256 _auctionsStarted,
    uint256 _amountSoldIncrease,
    uint48 _totalAuctionLength
  ) public happyPath(_auction, _auctionsStarted, _amountSoldIncrease, _totalAuctionLength) {
    debtAuctionHouse.restartAuction(_auction.id);

    (, uint256 _amountToSell,,,) = debtAuctionHouse.bids(_auction.id);

    assertEq(_amountToSell, (_amountSoldIncrease * _auction.amountToSell) / WAD);
  }

  function test_Set_Bids_AuctionDeadline(
    DebtAuction memory _auction,
    uint256 _auctionsStarted,
    uint256 _amountSoldIncrease,
    uint48 _totalAuctionLength
  ) public happyPath(_auction, _auctionsStarted, _amountSoldIncrease, _totalAuctionLength) {
    debtAuctionHouse.restartAuction(_auction.id);

    (,,,, uint48 _auctionDeadline) = debtAuctionHouse.bids(_auction.id);

    assertEq(_auctionDeadline, block.timestamp + _totalAuctionLength);
  }

  function test_Emit_RestartAuction(
    DebtAuction memory _auction,
    uint256 _auctionsStarted,
    uint256 _amountSoldIncrease,
    uint48 _totalAuctionLength
  ) public happyPath(_auction, _auctionsStarted, _amountSoldIncrease, _totalAuctionLength) {
    expectEmitNoIndex();
    emit RestartAuction(_auction.id, block.timestamp + _totalAuctionLength);

    debtAuctionHouse.restartAuction(_auction.id);
  }
}

contract Unit_DebtAuctionHouse_DecreaseSoldAmount is Base {
  event DecreaseSoldAmount(
    uint256 indexed _id, address _highBidder, uint256 _amountToBuy, uint256 _bid, uint256 _bidExpiry
  );

  modifier happyPath(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease,
    uint48 _bidDuration,
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
    uint48 _bidDuration
  ) internal view {
    _auction.highBidder = address(mockAccountingEngine);

    vm.assume(_auction.bidExpiry > block.timestamp || _auction.bidExpiry == 0);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_amountToBuy < _auction.amountToSell);
    vm.assume(notOverflowMul(_bidDecrease, _amountToBuy));
    vm.assume(notOverflowMul(_auction.amountToSell, WAD));
    vm.assume(_bidDecrease * _amountToBuy <= _auction.amountToSell * WAD);
    vm.assume(notOverflowAddUint48(uint48(block.timestamp), _bidDuration));
  }

  function _mockValues(
    DebtAuction memory _auction,
    uint256 _bidDecrease,
    uint48 _bidDuration,
    uint256 _totalOnAuctionDebt
  ) internal {
    _mockAuction(_auction);
    _mockBidDecrease(_bidDecrease);
    _mockBidDuration(_bidDuration);
    _mockTotalOnAuctionDebt(_totalOnAuctionDebt);
  }

  function test_Revert_ContractIsDisabled(DebtAuction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_HighBidderNotSet(DebtAuction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    _auction.highBidder = address(0);

    _mockValues(_auction, 0, 0, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_HighBidderNotSet.selector);

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_BidAlreadyExpired(DebtAuction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry != 0 && _auction.bidExpiry <= block.timestamp);

    _mockValues(_auction, 0, 0, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_BidAlreadyExpired.selector);

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_AuctionAlreadyExpired(DebtAuction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline <= block.timestamp);

    _mockValues(_auction, 0, 0, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_AuctionAlreadyExpired.selector);

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_NotMatchingBid(DebtAuction memory _auction, uint256 _amountToBuy, uint256 _bid) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_bid != _auction.bidAmount);

    _mockValues(_auction, 0, 0, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_NotMatchingBid.selector);

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _bid);
  }

  function test_Revert_AmountBoughtNotLower(DebtAuction memory _auction, uint256 _amountToBuy) public {
    vm.assume(_auction.highBidder != address(0));
    vm.assume(_auction.bidExpiry == 0 || _auction.bidExpiry > block.timestamp);
    vm.assume(_auction.auctionDeadline > block.timestamp);
    vm.assume(_amountToBuy >= _auction.amountToSell);

    _mockValues(_auction, 0, 0, 0);

    vm.expectRevert(IDebtAuctionHouse.DAH_AmountBoughtNotLower.selector);

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);
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

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);
  }

  function test_Call_SafeEngine_TransferInternalCoins(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    IDebtAuctionHouse.DebtAuctionHouseParams memory _params,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _params.bidDecrease, _params.bidDuration, _totalOnAuctionDebt) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.transferInternalCoins, (user, _auction.highBidder, _auction.bidAmount))
    );

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);
  }

  function test_Call_HighBidder_CancelAuctionedDebtWithSurplus(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease,
    uint48 _bidDuration,
    uint256 _totalOnAuctionDebt
  ) public {
    vm.assume(_auction.bidExpiry == 0);

    _assumeHappyPath(_auction, _amountToBuy, _bidDecrease, _bidDuration);
    _mockValues(_auction, _bidDecrease, _bidDuration, _totalOnAuctionDebt);

    vm.expectCall(
      address(mockAccountingEngine),
      abi.encodeCall(
        mockAccountingEngine.cancelAuctionedDebtWithSurplus, (Math.min(_auction.bidAmount, _totalOnAuctionDebt))
      )
    );

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);
  }

  function testFail_Call_HighBidder_CancelAuctionedDebtWithSurplus(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease,
    uint48 _bidDuration,
    uint256 _totalOnAuctionDebt
  ) public {
    vm.assume(_auction.bidExpiry > block.timestamp);

    _assumeHappyPath(_auction, _amountToBuy, _bidDecrease, _bidDuration);
    _mockValues(_auction, _bidDecrease, _bidDuration, _totalOnAuctionDebt);

    vm.expectCall(
      address(mockAccountingEngine),
      abi.encodeCall(
        mockAccountingEngine.cancelAuctionedDebtWithSurplus, (Math.min(_auction.bidAmount, _totalOnAuctionDebt))
      )
    );

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);
  }

  function test_Set_Bids_HighBidder(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease,
    uint48 _bidDuration,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _bidDecrease, _bidDuration, _totalOnAuctionDebt) {
    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);

    (,, address _highBidder,,) = debtAuctionHouse.bids(_auction.id);

    assertEq(_highBidder, user);
  }

  function test_Set_Bids_AmountToSell(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease,
    uint48 _bidDuration,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _bidDecrease, _bidDuration, _totalOnAuctionDebt) {
    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);

    (, uint256 _amountToSell,,,) = debtAuctionHouse.bids(_auction.id);

    assertEq(_amountToSell, _amountToBuy);
  }

  function test_Set_Bids_BidExpiry(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease,
    uint48 _bidDuration,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _bidDecrease, _bidDuration, _totalOnAuctionDebt) {
    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);

    (,,, uint48 _bidExpiry,) = debtAuctionHouse.bids(_auction.id);

    assertEq(_bidExpiry, block.timestamp + _bidDuration);
  }

  function test_Emit_DecreaseSoldAmount(
    DebtAuction memory _auction,
    uint256 _amountToBuy,
    uint256 _bidDecrease,
    uint48 _bidDuration,
    uint256 _totalOnAuctionDebt
  ) public happyPath(_auction, _amountToBuy, _bidDecrease, _bidDuration, _totalOnAuctionDebt) {
    expectEmitNoIndex();
    emit DecreaseSoldAmount(_auction.id, user, _amountToBuy, _auction.bidAmount, block.timestamp + _bidDuration);

    debtAuctionHouse.decreaseSoldAmount(_auction.id, _amountToBuy, _auction.bidAmount);
  }
}

contract Unit_DebtAuctionHouse_SettleAuction is Base {
  event SettleAuction(uint256 indexed _id, uint256 _activeDebtAuctions);

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
    _mockContractEnabled(0);

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
      address(mockProtocolToken), abi.encodeCall(mockProtocolToken.mint, (_auction.highBidder, _auction.amountToSell))
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

  function test_Set_Bids(
    DebtAuction memory _auction,
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
    DebtAuction memory _auction,
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
    _mockContractEnabled(0);
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
      )
    );

    debtAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Emit_TerminateAuctionPrematurely(
    DebtAuction memory _auction,
    uint256 _activeDebtAuctions
  ) public happyPath(_auction, _activeDebtAuctions) {
    expectEmitNoIndex();
    emit TerminateAuctionPrematurely(_auction.id, user, _auction.highBidder, _auction.bidAmount, _activeDebtAuctions);

    debtAuctionHouse.terminateAuctionPrematurely(_auction.id);
  }

  function test_Set_Bids(
    DebtAuction memory _auction,
    uint256 _activeDebtAuctions
  ) public happyPath(_auction, _activeDebtAuctions) {
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
  event ModifyParameters(bytes32 indexed _param, bytes32 indexed _cType, bytes _data);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized(bytes32 _param, bytes memory _data) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    debtAuctionHouse.modifyParameters(_param, _data);
  }

  function test_Revert_ContractIsDisabled(bytes32 _param, bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    debtAuctionHouse.modifyParameters(_param, _data);
  }

  function test_Set_Parameters(IDebtAuctionHouse.DebtAuctionHouseParams memory _fuzz) public happyPath {
    debtAuctionHouse.modifyParameters('bidDecrease', abi.encode(_fuzz.bidDecrease));
    debtAuctionHouse.modifyParameters('amountSoldIncrease', abi.encode(_fuzz.amountSoldIncrease));
    debtAuctionHouse.modifyParameters('bidDuration', abi.encode(_fuzz.bidDuration));
    debtAuctionHouse.modifyParameters('totalAuctionLength', abi.encode(_fuzz.totalAuctionLength));

    IDebtAuctionHouse.DebtAuctionHouseParams memory _params = debtAuctionHouse.params();

    assertEq(abi.encode(_params), abi.encode(_fuzz));
  }

  function test_Set_ProtocolToken(address _protocolToken) public happyPath {
    debtAuctionHouse.modifyParameters('protocolToken', abi.encode(_protocolToken));

    assertEq(address(debtAuctionHouse.protocolToken()), _protocolToken);
  }

  function test_Set_AccountingEngine(address _accountingEngine) public happyPath {
    debtAuctionHouse.modifyParameters('accountingEngine', abi.encode(_accountingEngine));

    assertEq(debtAuctionHouse.accountingEngine(), _accountingEngine);
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    debtAuctionHouse.modifyParameters('unrecognizedParam', _data);
  }

  function test_Emit_ModifyParameters(address _accountingEngine) public happyPath {
    expectEmitNoIndex();
    emit ModifyParameters('accountingEngine', GLOBAL_PARAM, abi.encode(_accountingEngine));

    debtAuctionHouse.modifyParameters('accountingEngine', abi.encode(_accountingEngine));
  }
}

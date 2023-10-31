// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {
  SettlementSurplusAuctioneer,
  ISettlementSurplusAuctioneer
} from '@contracts/settlement/SettlementSurplusAuctioneer.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ISurplusAuctionHouse} from '@interfaces/ISurplusAuctionHouse.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IAccountingEngine mockAccountingEngine = IAccountingEngine(mockContract('AccountingEngine'));
  ISurplusAuctionHouse mockSurplusAuctionHouse = ISurplusAuctionHouse(mockContract('SurplusAuctionHouse'));
  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SafeEngine'));

  SettlementSurplusAuctioneer settlementSurplusAuctioneer;

  function setUp() public virtual {
    vm.startPrank(deployer);

    _mockSafeEngine(mockSafeEngine);

    settlementSurplusAuctioneer =
      new SettlementSurplusAuctioneer(address(mockAccountingEngine), address(mockSurplusAuctionHouse));
    label(address(settlementSurplusAuctioneer), 'SettlementSurplusAuctioneer');

    settlementSurplusAuctioneer.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockContractEnabled(bool _contractEnabled) internal {
    vm.mockCall(
      address(mockAccountingEngine),
      abi.encodeCall(mockAccountingEngine.contractEnabled, ()),
      abi.encode(_contractEnabled)
    );
  }

  function _mockSafeEngine(ISAFEEngine _safeEngine) internal {
    vm.mockCall(
      address(mockAccountingEngine), abi.encodeCall(mockAccountingEngine.safeEngine, ()), abi.encode(_safeEngine)
    );
  }

  function _mockAccountingEngineParams(
    uint256 _surplusIsTransferred,
    uint256 _surplusDelay,
    uint256 _popDebtDelay,
    uint256 _disableCooldown,
    uint256 _surplusAmount,
    uint256 _surplusBuffer,
    uint256 _debtAuctionMintedTokens,
    uint256 _debtAuctionBidSize
  ) internal {
    vm.mockCall(
      address(mockAccountingEngine),
      abi.encodeCall(mockAccountingEngine.params, ()),
      abi.encode(
        _surplusIsTransferred,
        _surplusDelay,
        _popDebtDelay,
        _disableCooldown,
        _surplusAmount,
        _surplusBuffer,
        _debtAuctionMintedTokens,
        _debtAuctionBidSize
      )
    );
  }

  function _mockStartAuction(uint256 _amountToSell, uint256 _initialBid, uint256 _id) internal {
    vm.mockCall(
      address(mockSurplusAuctionHouse),
      abi.encodeCall(mockSurplusAuctionHouse.startAuction, (_amountToSell, _initialBid)),
      abi.encode(_id)
    );
  }

  function _mockCoinBalance(address _coinAddress, uint256 _coinBalance) internal {
    vm.mockCall(
      address(mockSafeEngine), abi.encodeCall(mockSafeEngine.coinBalance, (_coinAddress)), abi.encode(_coinBalance)
    );
  }

  function _mockLastSurplusAuctionTime(uint256 _lastSurplusTime) internal {
    stdstore.target(address(settlementSurplusAuctioneer)).sig(ISettlementSurplusAuctioneer.lastSurplusTime.selector)
      .checked_write(_lastSurplusTime);
  }
}

contract Unit_SettlementSurplusAuctioneer_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    settlementSurplusAuctioneer =
      new SettlementSurplusAuctioneer(address(mockAccountingEngine), address(mockSurplusAuctionHouse));
  }

  function test_Set_AccountingEngine() public happyPath {
    assertEq(address(settlementSurplusAuctioneer.accountingEngine()), address(mockAccountingEngine));
  }

  function test_Set_SurplusAuctionHouse() public happyPath {
    assertEq(address(settlementSurplusAuctioneer.surplusAuctionHouse()), address(mockSurplusAuctionHouse));
  }

  function test_Set_SafeEngine() public happyPath {
    assertEq(address(settlementSurplusAuctioneer.safeEngine()), address(mockSafeEngine));
  }

  function test_Call_SafeEngine_ApproveSAFEModification() public happyPath {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.approveSAFEModification, (address(mockSurplusAuctionHouse))),
      1
    );

    settlementSurplusAuctioneer =
      new SettlementSurplusAuctioneer(address(mockAccountingEngine), address(mockSurplusAuctionHouse));
  }

  function test_Revert_Null_AccountingEngine() public {
    vm.expectRevert(Assertions.NullAddress.selector);

    new SettlementSurplusAuctioneer(address(0), address(mockSurplusAuctionHouse));
  }

  function test_Revert_Null_SurplusAuctionHouse() public {
    vm.expectRevert(Assertions.NullAddress.selector);

    new SettlementSurplusAuctioneer(address(mockAccountingEngine), address(0));
  }
}

contract Unit_SettlementSurplusAuctioneer_AuctionSurplus is Base {
  event AuctionSurplus(uint256 indexed _id, uint256 _lastSurplusTime, uint256 _coinBalance);

  modifier happyPath(
    uint256 _lastSurplusTime,
    uint256 _surplusDelay,
    uint256 _surplusAmount,
    uint256 _coinBalance,
    uint256 _idA,
    uint256 _idB
  ) {
    _assumeHappyPath(_lastSurplusTime, _surplusDelay);
    _mockValues(_lastSurplusTime, _surplusDelay, _surplusAmount, _coinBalance, _idA, _idB);
    _;
  }

  function _assumeHappyPath(uint256 _lastSurplusTime, uint256 _surplusDelay) internal view {
    vm.assume(notOverflowAdd(_lastSurplusTime, _surplusDelay));
    vm.assume(block.timestamp >= _lastSurplusTime + _surplusDelay);
  }

  function _mockValues(
    uint256 _lastSurplusTime,
    uint256 _surplusDelay,
    uint256 _surplusAmount,
    uint256 _coinBalance,
    uint256 _idA,
    uint256 _idB
  ) internal {
    _mockLastSurplusAuctionTime(_lastSurplusTime);
    _mockContractEnabled(false);
    _mockAccountingEngineParams(0, _surplusDelay, 0, 0, _surplusAmount, 0, 0, 0);
    _mockCoinBalance(address(settlementSurplusAuctioneer), _coinBalance);
    _mockStartAuction(_coinBalance, 0, _idA);
    _mockStartAuction(_surplusAmount, 0, _idB);
  }

  function test_Revert_AccountingEngineStillEnabled() public {
    _mockContractEnabled(true);

    vm.expectRevert(ISettlementSurplusAuctioneer.SSA_AccountingEngineStillEnabled.selector);

    settlementSurplusAuctioneer.auctionSurplus();
  }

  function test_Revert_SurplusAuctionDelayNotPassed(uint256 _lastSurplusTime, uint256 _surplusDelay) public {
    vm.assume(notOverflowAdd(_lastSurplusTime, _surplusDelay));
    vm.assume(block.timestamp < _lastSurplusTime + _surplusDelay);

    _mockValues(_lastSurplusTime, _surplusDelay, 0, 0, 0, 0);

    vm.expectRevert(ISettlementSurplusAuctioneer.SSA_SurplusAuctionDelayNotPassed.selector);

    settlementSurplusAuctioneer.auctionSurplus();
  }

  function test_Set_LastSurplusAuctionTime(
    uint256 _lastSurplusTime,
    uint256 _surplusDelay,
    uint256 _surplusAmount,
    uint256 _coinBalance,
    uint256 _idA,
    uint256 _idB
  ) public happyPath(_lastSurplusTime, _surplusDelay, _surplusAmount, _coinBalance, _idA, _idB) {
    settlementSurplusAuctioneer.auctionSurplus();

    assertEq(settlementSurplusAuctioneer.lastSurplusTime(), block.timestamp);
  }

  function test_Return_Id_A(
    uint256 _lastSurplusTime,
    uint256 _surplusDelay,
    uint256 _surplusAmount,
    uint256 _coinBalance,
    uint256 _idA,
    uint256 _idB
  ) public happyPath(_lastSurplusTime, _surplusDelay, _surplusAmount, _coinBalance, _idA, _idB) {
    vm.assume(_coinBalance < _surplusAmount);
    vm.assume(_coinBalance > 0);

    assertEq(settlementSurplusAuctioneer.auctionSurplus(), _idA);
  }

  function test_Return_Id_B(
    uint256 _lastSurplusTime,
    uint256 _surplusDelay,
    uint256 _surplusAmount,
    uint256 _coinBalance,
    uint256 _idA,
    uint256 _idB
  ) public happyPath(_lastSurplusTime, _surplusDelay, _surplusAmount, _coinBalance, _idA, _idB) {
    vm.assume(_coinBalance >= _surplusAmount);
    vm.assume(_surplusAmount > 0);

    assertEq(settlementSurplusAuctioneer.auctionSurplus(), _idB);
  }

  function test_Return_Id_C(
    uint256 _lastSurplusTime,
    uint256 _surplusDelay,
    uint256 _surplusAmount,
    uint256 _coinBalance,
    uint256 _idA,
    uint256 _idB
  ) public happyPath(_lastSurplusTime, _surplusDelay, _surplusAmount, _coinBalance, _idA, _idB) {
    vm.assume(
      _coinBalance < _surplusAmount && _coinBalance == 0 || _coinBalance >= _surplusAmount && _surplusAmount == 0
    );

    assertEq(settlementSurplusAuctioneer.auctionSurplus(), 0);
  }

  function test_Emit_AuctionSurplus_A(
    uint256 _lastSurplusTime,
    uint256 _surplusDelay,
    uint256 _surplusAmount,
    uint256 _coinBalance,
    uint256 _idA,
    uint256 _idB
  ) public happyPath(_lastSurplusTime, _surplusDelay, _surplusAmount, _coinBalance, _idA, _idB) {
    vm.assume(_coinBalance < _surplusAmount);
    vm.assume(_coinBalance > 0);

    vm.expectEmit();
    emit AuctionSurplus(_idA, block.timestamp, 0);

    settlementSurplusAuctioneer.auctionSurplus();
  }

  function testFail_Emit_AuctionSurplus_A(
    uint256 _lastSurplusTime,
    uint256 _surplusDelay,
    uint256 _surplusAmount,
    uint256 _coinBalance,
    uint256 _idA,
    uint256 _idB
  ) public happyPath(_lastSurplusTime, _surplusDelay, _surplusAmount, _coinBalance, _idA, _idB) {
    vm.assume(_coinBalance < _surplusAmount);
    vm.assume(_coinBalance == 0);

    vm.expectEmit();
    emit AuctionSurplus(_idA, block.timestamp, 0);

    settlementSurplusAuctioneer.auctionSurplus();
  }

  function test_Emit_AuctionSurplus_B(
    uint256 _lastSurplusTime,
    uint256 _surplusDelay,
    uint256 _surplusAmount,
    uint256 _coinBalance,
    uint256 _idA,
    uint256 _idB
  ) public happyPath(_lastSurplusTime, _surplusDelay, _surplusAmount, _coinBalance, _idA, _idB) {
    vm.assume(_coinBalance >= _surplusAmount);
    vm.assume(_surplusAmount > 0);

    vm.expectEmit();
    emit AuctionSurplus(_idB, block.timestamp, _coinBalance - _surplusAmount);

    settlementSurplusAuctioneer.auctionSurplus();
  }

  function testFail_Emit_AuctionSurplus_B(
    uint256 _lastSurplusTime,
    uint256 _surplusDelay,
    uint256 _surplusAmount,
    uint256 _coinBalance,
    uint256 _idA,
    uint256 _idB
  ) public happyPath(_lastSurplusTime, _surplusDelay, _surplusAmount, _coinBalance, _idA, _idB) {
    vm.assume(_coinBalance >= _surplusAmount);
    vm.assume(_surplusAmount == 0);

    vm.expectEmit();
    emit AuctionSurplus(_idB, block.timestamp, _coinBalance - _surplusAmount);

    settlementSurplusAuctioneer.auctionSurplus();
  }
}

contract Unit_SettlementSurplusAuctioneer_ModifyParameters is Base {
  event ModifyParameters(bytes32 indexed _param, bytes32 indexed _cType, bytes _data);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_AccountingEngine(address _accountingEngine) public happyPath {
    settlementSurplusAuctioneer.modifyParameters('accountingEngine', abi.encode(_accountingEngine));

    assertEq(address(settlementSurplusAuctioneer.accountingEngine()), _accountingEngine);
  }

  function test_Set_SurplusAuctionHouse(address _surplusAuctionHouse) public happyPath {
    address _previousSurplusAuctionHouse = address(settlementSurplusAuctioneer.surplusAuctionHouse());

    vm.expectCall(
      address(mockSafeEngine), abi.encodeCall(mockSafeEngine.denySAFEModification, (_previousSurplusAuctionHouse))
    );
    vm.expectCall(
      address(mockSafeEngine), abi.encodeCall(mockSafeEngine.approveSAFEModification, (_surplusAuctionHouse))
    );

    settlementSurplusAuctioneer.modifyParameters('surplusAuctionHouse', abi.encode(_surplusAuctionHouse));

    assertEq(address(settlementSurplusAuctioneer.surplusAuctionHouse()), _surplusAuctionHouse);
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    settlementSurplusAuctioneer.modifyParameters('unrecognizedParam', _data);
  }
}

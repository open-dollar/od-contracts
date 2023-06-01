// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {GlobalSettlement, IGlobalSettlement} from '@contracts/settlement/GlobalSettlement.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';
import {IModifiable, GLOBAL_PARAM} from '@interfaces/utils/IModifiable.sol';
import {Math, RAY, WAD} from '@libraries/Math.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SafeEngine'));
  ILiquidationEngine mockLiquidationEngine = ILiquidationEngine(mockContract('LiquidationEngine'));
  IAccountingEngine mockAccountingEngine = IAccountingEngine(mockContract('AccountingEngine'));
  IOracleRelayer mockOracleRelayer = IOracleRelayer(mockContract('OracleRelayer'));
  IStabilityFeeTreasury mockStabilityFeeTreasury = IStabilityFeeTreasury(mockContract('StabilityFeeTreasury'));
  ICollateralAuctionHouse mockCollateralAuctionHouse = ICollateralAuctionHouse(mockContract('CollateralAuctionHouse'));
  IBaseOracle mockOracle = IBaseOracle(mockContract('Oracle'));

  GlobalSettlement globalSettlement;

  function setUp() public virtual {
    vm.startPrank(deployer);

    globalSettlement = new GlobalSettlement();
    label(address(globalSettlement), 'GlobalSettlement');

    globalSettlement.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockCoinBalance(address _coinAddress, uint256 _coinBalance) internal {
    vm.mockCall(
      address(mockSafeEngine), abi.encodeCall(mockSafeEngine.coinBalance, (_coinAddress)), abi.encode(_coinBalance)
    );
  }

  function _mockGlobalDebt(uint256 _globalDebt) internal {
    vm.mockCall(address(mockSafeEngine), abi.encodeCall(mockSafeEngine.globalDebt, ()), abi.encode(_globalDebt));
  }

  function _mockSafeEngineCollateralData(
    bytes32 _cType,
    uint256 _debtAmount,
    uint256 _accumulatedRate,
    uint256 _safetyPrice,
    uint256 _liquidationPrice
  ) internal {
    vm.mockCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.cData, (_cType)),
      abi.encode(_debtAmount, _accumulatedRate, _safetyPrice, _liquidationPrice)
    );
  }

  function _mockSafeEngineSafeData(
    bytes32 _cType,
    address _safe,
    uint256 _lockedCollateral,
    uint256 _generatedDebt
  ) internal {
    vm.mockCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.safes, (_cType, _safe)),
      abi.encode(_lockedCollateral, _generatedDebt)
    );
  }

  function _mockLiquidationEngineCollateralParams(
    bytes32 _cType,
    address _collateralAuctionHouse,
    uint256 _liquidationPenalty,
    uint256 _liquidationQuantity
  ) internal {
    vm.mockCall(
      address(mockLiquidationEngine),
      abi.encodeCall(mockLiquidationEngine.cParams, (_cType)),
      abi.encode(_collateralAuctionHouse, _liquidationPenalty, _liquidationQuantity)
    );
  }

  function _mockRedemptionPrice(uint256 _redemptionPrice) internal {
    vm.mockCall(
      address(mockOracleRelayer), abi.encodeCall(mockOracleRelayer.redemptionPrice, ()), abi.encode(_redemptionPrice)
    );
  }

  function _mockOracleRelayerCollateralParams(
    bytes32 _cType,
    address _oracle,
    uint256 _safetyCRatio,
    uint256 _liquidationCRatio
  ) internal {
    vm.mockCall(
      address(mockOracleRelayer),
      abi.encodeCall(mockOracleRelayer.cParams, (_cType)),
      abi.encode(_oracle, _safetyCRatio, _liquidationCRatio)
    );
  }

  function _mockAuction(
    uint256 _id,
    uint256 _bidAmount,
    uint256 _amountToSell,
    uint256 _amountToRaise,
    uint256 _raisedAmount,
    address _forgoneCollateralReceiver
  ) internal {
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeCall(mockCollateralAuctionHouse.bidAmount, (_id)),
      abi.encode(_bidAmount)
    );
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeCall(mockCollateralAuctionHouse.remainingAmountToSell, (_id)),
      abi.encode(_amountToSell)
    );
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeCall(mockCollateralAuctionHouse.amountToRaise, (_id)),
      abi.encode(_amountToRaise)
    );
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeCall(mockCollateralAuctionHouse.raisedAmount, (_id)),
      abi.encode(_raisedAmount)
    );
    vm.mockCall(
      address(mockCollateralAuctionHouse),
      abi.encodeCall(mockCollateralAuctionHouse.forgoneCollateralReceiver, (_id)),
      abi.encode(_forgoneCollateralReceiver)
    );
  }

  function _mockOracleRead(uint256 _oracleReadValue) internal {
    vm.mockCall(address(mockOracle), abi.encodeCall(mockOracle.read, ()), abi.encode(_oracleReadValue));
  }

  function _mockContractEnabled(uint256 _contractEnabled) internal {
    stdstore.target(address(globalSettlement)).sig(IDisableable.contractEnabled.selector).checked_write(
      _contractEnabled
    );
  }

  function _mockShutdownTime(uint256 _shutdownTime) internal {
    stdstore.target(address(globalSettlement)).sig(IGlobalSettlement.shutdownTime.selector).checked_write(_shutdownTime);
  }

  function _mockShutdownCooldown(uint256 _shutdownCooldown) internal {
    stdstore.target(address(globalSettlement)).sig(IGlobalSettlement.shutdownCooldown.selector).checked_write(
      _shutdownCooldown
    );
  }

  function _mockOutstandingCoinSupply(uint256 _outstandingCoinSupply) internal {
    stdstore.target(address(globalSettlement)).sig(IGlobalSettlement.outstandingCoinSupply.selector).checked_write(
      _outstandingCoinSupply
    );
  }

  function _mockFinalCoinPerCollateralPrice(bytes32 _cType, uint256 _finalCoinPerCollateralPrice) internal {
    stdstore.target(address(globalSettlement)).sig(IGlobalSettlement.finalCoinPerCollateralPrice.selector).with_key(
      _cType
    ).checked_write(_finalCoinPerCollateralPrice);
  }

  function _mockCollateralShortfall(bytes32 _cType, uint256 _collateralShortfall) internal {
    stdstore.target(address(globalSettlement)).sig(IGlobalSettlement.collateralShortfall.selector).with_key(_cType)
      .checked_write(_collateralShortfall);
  }

  function _mockCollateralTotalDebt(bytes32 _cType, uint256 _collateralTotalDebt) internal {
    stdstore.target(address(globalSettlement)).sig(IGlobalSettlement.collateralTotalDebt.selector).with_key(_cType)
      .checked_write(_collateralTotalDebt);
  }

  function _mockCollateralCashPrice(bytes32 _cType, uint256 _collateralCashPrice) internal {
    stdstore.target(address(globalSettlement)).sig(IGlobalSettlement.collateralCashPrice.selector).with_key(_cType)
      .checked_write(_collateralCashPrice);
  }

  function _mockCoinBag(address _coinHolder, uint256 _coinBag) internal {
    stdstore.target(address(globalSettlement)).sig(IGlobalSettlement.coinBag.selector).with_key(_coinHolder)
      .checked_write(_coinBag);
  }

  function _mockCoinsUsedToRedeem(bytes32 _cType, address _coinHolder, uint256 _coinsUsedToRedeem) internal {
    stdstore.target(address(globalSettlement)).sig(IGlobalSettlement.coinsUsedToRedeem.selector).with_key(_cType)
      .with_key(_coinHolder).checked_write(_coinsUsedToRedeem);
  }

  function _mockSafeEngine(address _safeEngine) internal {
    stdstore.target(address(globalSettlement)).sig(IGlobalSettlement.safeEngine.selector).checked_write(_safeEngine);
  }

  function _mockLiquidationEngine(address _liquidationEngine) internal {
    stdstore.target(address(globalSettlement)).sig(IGlobalSettlement.liquidationEngine.selector).checked_write(
      _liquidationEngine
    );
  }

  function _mockAccountingEngine(address _accountingEngine) internal {
    stdstore.target(address(globalSettlement)).sig(IGlobalSettlement.accountingEngine.selector).checked_write(
      _accountingEngine
    );
  }

  function _mockOracleRelayer(address _oracleRelayer) internal {
    stdstore.target(address(globalSettlement)).sig(IGlobalSettlement.oracleRelayer.selector).checked_write(
      _oracleRelayer
    );
  }

  function _mockStabilityFeeTreasury(address _stabilityFeeTreasury) internal {
    stdstore.target(address(globalSettlement)).sig(IGlobalSettlement.stabilityFeeTreasury.selector).checked_write(
      _stabilityFeeTreasury
    );
  }
}

contract Unit_GlobalSettlement_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    expectEmitNoIndex();
    emit AddAuthorization(user);

    globalSettlement = new GlobalSettlement();
  }

  function test_Set_ContractEnabled() public happyPath {
    assertEq(globalSettlement.contractEnabled(), 1);
  }
}

contract Unit_GlobalSettlement_DisableContract is Base {
  function test_Revert_NonDisableable() public {
    vm.expectRevert(IDisableable.NonDisableable.selector);

    globalSettlement.disableContract();
  }
}

contract Unit_GlobalSettlement_ShutdownSystem is Base {
  event ShutdownSystem();
  event DisableContract();

  modifier happyPath() {
    vm.startPrank(authorizedAccount);

    _mockValues();
    _;
  }

  function _mockValues() internal {
    _mockSafeEngine(address(mockSafeEngine));
    _mockLiquidationEngine(address(mockLiquidationEngine));
    _mockAccountingEngine(address(mockAccountingEngine));
    _mockOracleRelayer(address(mockOracleRelayer));
    _mockStabilityFeeTreasury(address(mockStabilityFeeTreasury));
  }

  function test_Revert_Unauthorized() public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    globalSettlement.shutdownSystem();
  }

  function test_Revert_ContractIsDisabled() public {
    vm.startPrank(authorizedAccount);

    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    globalSettlement.shutdownSystem();
  }

  function test_Set_ShutdownTime() public happyPath {
    globalSettlement.shutdownSystem();

    assertEq(globalSettlement.shutdownTime(), block.timestamp);
  }

  function test_Emit_DisableContract() public happyPath {
    expectEmitNoIndex();
    emit DisableContract();

    globalSettlement.shutdownSystem();
  }

  function test_Call_SafeEngine_DisableContract() public happyPath {
    vm.expectCall(address(mockSafeEngine), abi.encodeCall(mockSafeEngine.disableContract, ()));

    globalSettlement.shutdownSystem();
  }

  function test_Call_LiquidationEngine_DisableContract() public happyPath {
    vm.expectCall(address(mockLiquidationEngine), abi.encodeCall(mockLiquidationEngine.disableContract, ()));

    globalSettlement.shutdownSystem();
  }

  function test_Call_StabilityFeeTreasury_DisableContract() public happyPath {
    vm.expectCall(address(mockStabilityFeeTreasury), abi.encodeCall(mockStabilityFeeTreasury.disableContract, ()));

    globalSettlement.shutdownSystem();
  }

  function testFail_Call_StabilityFeeTreasury_DisableContract() public happyPath {
    _mockStabilityFeeTreasury(address(0));

    vm.expectCall(address(mockStabilityFeeTreasury), abi.encodeCall(mockStabilityFeeTreasury.disableContract, ()));

    globalSettlement.shutdownSystem();
  }

  function test_Call_AccountingEngine_DisableContract() public happyPath {
    vm.expectCall(address(mockAccountingEngine), abi.encodeCall(mockAccountingEngine.disableContract, ()));

    globalSettlement.shutdownSystem();
  }

  function test_Call_OracleRelayer_DisableContract() public happyPath {
    vm.expectCall(address(mockOracleRelayer), abi.encodeCall(mockOracleRelayer.disableContract, ()));

    globalSettlement.shutdownSystem();
  }

  function test_Emit_ShutdownSystem() public happyPath {
    expectEmitNoIndex();
    emit ShutdownSystem();

    globalSettlement.shutdownSystem();
  }
}

contract Unit_GlobalSettlement_FreezeCollateralType is Base {
  using Math for uint256;

  event FreezeCollateralType(bytes32 indexed _cType, uint256 _finalCoinPerCollateralPrice);

  modifier happyPath(bytes32 _cType, uint256 _debtAmount, uint256 _redemptionPrice, uint256 _oracleReadValue) {
    _assumeHappyPath(_redemptionPrice, _oracleReadValue);
    _mockValues(_cType, 0, _debtAmount, _redemptionPrice, _oracleReadValue);
    _;
  }

  function _assumeHappyPath(uint256 _redemptionPrice, uint256 _oracleReadValue) internal view {
    vm.assume(notOverflowMul(_redemptionPrice, WAD));
    vm.assume(_oracleReadValue != 0);
  }

  function _mockValues(
    bytes32 _cType,
    uint256 _finalCoinPerCollateralPrice,
    uint256 _debtAmount,
    uint256 _redemptionPrice,
    uint256 _oracleReadValue
  ) internal {
    _mockContractEnabled(0);
    _mockFinalCoinPerCollateralPrice(_cType, _finalCoinPerCollateralPrice);
    _mockSafeEngine(address(mockSafeEngine));
    _mockOracleRelayer(address(mockOracleRelayer));
    _mockSafeEngineCollateralData(_cType, _debtAmount, 0, 0, 0);
    _mockOracleRelayerCollateralParams(_cType, address(mockOracle), 0, 0);
    _mockRedemptionPrice(_redemptionPrice);
    _mockOracleRead(_oracleReadValue);
  }

  function test_Revert_ContractIsEnabled(bytes32 _cType) public {
    vm.expectRevert(IDisableable.ContractIsEnabled.selector);

    globalSettlement.freezeCollateralType(_cType);
  }

  function test_Revert_FinalCollateralPriceAlreadyDefined(bytes32 _cType, uint256 _finalCoinPerCollateralPrice) public {
    vm.assume(_finalCoinPerCollateralPrice != 0);

    _mockValues(_cType, _finalCoinPerCollateralPrice, 0, 0, 0);

    vm.expectRevert(IGlobalSettlement.GS_FinalCollateralPriceAlreadyDefined.selector);

    globalSettlement.freezeCollateralType(_cType);
  }

  function test_Set_CollateralTotalDebt(
    bytes32 _cType,
    uint256 _debtAmount,
    uint256 _redemptionPrice,
    uint256 _oracleReadValue
  ) public happyPath(_cType, _debtAmount, _redemptionPrice, _oracleReadValue) {
    globalSettlement.freezeCollateralType(_cType);

    assertEq(globalSettlement.collateralTotalDebt(_cType), _debtAmount);
  }

  function test_Set_FinalCoinPerCollateralPrice(
    bytes32 _cType,
    uint256 _debtAmount,
    uint256 _redemptionPrice,
    uint256 _oracleReadValue
  ) public happyPath(_cType, _debtAmount, _redemptionPrice, _oracleReadValue) {
    globalSettlement.freezeCollateralType(_cType);

    assertEq(globalSettlement.finalCoinPerCollateralPrice(_cType), _redemptionPrice.wdiv(_oracleReadValue));
  }

  function test_Emit_FreezeCollateralType(
    bytes32 _cType,
    uint256 _debtAmount,
    uint256 _redemptionPrice,
    uint256 _oracleReadValue
  ) public happyPath(_cType, _debtAmount, _redemptionPrice, _oracleReadValue) {
    expectEmitNoIndex();
    emit FreezeCollateralType(_cType, _redemptionPrice.wdiv(_oracleReadValue));

    globalSettlement.freezeCollateralType(_cType);
  }
}

contract Unit_GlobalSettlement_FastTrackAuction is Base {
  struct FastTrackAuctionStruct {
    bytes32 collateralType;
    uint256 finalCoinPerCollateralPrice;
    uint256 collateralTotalDebt;
    uint256 accumulatedRate;
    uint256 id;
    uint256 bidAmount;
    uint256 amountToSell;
    uint256 amountToRaise;
    uint256 raisedAmount;
    address forgoneCollateralReceiver;
  }

  event FastTrackAuction(bytes32 indexed _cType, uint256 indexed _auctionId, uint256 _collateralTotalDebt);

  modifier happyPath(FastTrackAuctionStruct memory _auction) {
    _assumeHappyPath(_auction);
    _mockValues(_auction);
    _;
  }

  function _assumeHappyPath(FastTrackAuctionStruct memory _auction) internal view returns (uint256 _debt) {
    vm.assume(_auction.finalCoinPerCollateralPrice != 0);
    vm.assume(notUnderflow(_auction.amountToRaise, _auction.raisedAmount));
    vm.assume(_auction.accumulatedRate != 0);

    _debt = (_auction.amountToRaise - _auction.raisedAmount) / _auction.accumulatedRate;

    vm.assume(notOverflowAdd(_auction.collateralTotalDebt, _debt));
    vm.assume(notOverflowInt256(_auction.amountToSell));
    vm.assume(notOverflowInt256(_debt));
  }

  function _mockValues(FastTrackAuctionStruct memory _auction) internal {
    _mockFinalCoinPerCollateralPrice(_auction.collateralType, _auction.finalCoinPerCollateralPrice);
    _mockCollateralTotalDebt(_auction.collateralType, _auction.collateralTotalDebt);
    _mockSafeEngine(address(mockSafeEngine));
    _mockLiquidationEngine(address(mockLiquidationEngine));
    _mockAccountingEngine(address(mockAccountingEngine));
    _mockSafeEngineCollateralData(_auction.collateralType, 0, _auction.accumulatedRate, 0, 0);
    _mockLiquidationEngineCollateralParams(_auction.collateralType, address(mockCollateralAuctionHouse), 0, 0);
    _mockAuction(
      _auction.id,
      _auction.bidAmount,
      _auction.amountToSell,
      _auction.amountToRaise,
      _auction.raisedAmount,
      _auction.forgoneCollateralReceiver
    );
  }

  function test_Revert_FinalCollateralPriceNotDefined(FastTrackAuctionStruct memory _auction) public {
    vm.expectRevert(IGlobalSettlement.GS_FinalCollateralPriceNotDefined.selector);

    globalSettlement.fastTrackAuction(_auction.collateralType, _auction.id);
  }

  function test_Revert_IntOverflow_0(FastTrackAuctionStruct memory _auction) public {
    vm.assume(_auction.finalCoinPerCollateralPrice != 0);
    vm.assume(notUnderflow(_auction.amountToRaise, _auction.raisedAmount));
    vm.assume(_auction.accumulatedRate != 0);

    uint256 _debt = (_auction.amountToRaise - _auction.raisedAmount) / _auction.accumulatedRate;

    vm.assume(notOverflowAdd(_auction.collateralTotalDebt, _debt));
    vm.assume(!notOverflowInt256(_auction.amountToSell));

    _mockValues(_auction);

    vm.expectRevert(Math.IntOverflow.selector);

    globalSettlement.fastTrackAuction(_auction.collateralType, _auction.id);
  }

  function test_Revert_IntOverflow_1(FastTrackAuctionStruct memory _auction) public {
    vm.assume(_auction.finalCoinPerCollateralPrice != 0);
    vm.assume(notUnderflow(_auction.amountToRaise, _auction.raisedAmount));
    vm.assume(_auction.accumulatedRate != 0);

    uint256 _debt = (_auction.amountToRaise - _auction.raisedAmount) / _auction.accumulatedRate;

    vm.assume(notOverflowAdd(_auction.collateralTotalDebt, _debt));
    vm.assume(notOverflowInt256(_auction.amountToSell));
    vm.assume(!notOverflowInt256(_debt));

    _mockValues(_auction);

    vm.expectRevert(Math.IntOverflow.selector);

    globalSettlement.fastTrackAuction(_auction.collateralType, _auction.id);
  }

  function test_Call_SafeEngine_CreateUnbackedDebt(FastTrackAuctionStruct memory _auction) public happyPath(_auction) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.createUnbackedDebt,
        (address(mockAccountingEngine), address(mockAccountingEngine), _auction.amountToRaise - _auction.raisedAmount)
      )
    );
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.createUnbackedDebt,
        (address(mockAccountingEngine), address(globalSettlement), _auction.bidAmount)
      )
    );

    globalSettlement.fastTrackAuction(_auction.collateralType, _auction.id);
  }

  function test_Call_SafeEngine_ApproveSAFEModification(FastTrackAuctionStruct memory _auction)
    public
    happyPath(_auction)
  {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.approveSAFEModification, (address(mockCollateralAuctionHouse)))
    );

    globalSettlement.fastTrackAuction(_auction.collateralType, _auction.id);
  }

  function test_Call_CollateralAuctionHouse_TerminateAuctionPrematurely(FastTrackAuctionStruct memory _auction)
    public
    happyPath(_auction)
  {
    vm.expectCall(
      address(mockCollateralAuctionHouse),
      abi.encodeCall(mockCollateralAuctionHouse.terminateAuctionPrematurely, (_auction.id))
    );

    globalSettlement.fastTrackAuction(_auction.collateralType, _auction.id);
  }

  function test_Set_CollateralTotalDebt(FastTrackAuctionStruct memory _auction) public {
    uint256 _debt = _assumeHappyPath(_auction);
    _mockValues(_auction);

    globalSettlement.fastTrackAuction(_auction.collateralType, _auction.id);

    assertEq(globalSettlement.collateralTotalDebt(_auction.collateralType), _auction.collateralTotalDebt + _debt);
  }

  function test_Call_SafeEngine_ConfiscateSAFECollateralAndDebt(FastTrackAuctionStruct memory _auction) public {
    uint256 _debt = _assumeHappyPath(_auction);
    _mockValues(_auction);

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.confiscateSAFECollateralAndDebt,
        (
          _auction.collateralType,
          _auction.forgoneCollateralReceiver,
          address(globalSettlement),
          address(mockAccountingEngine),
          int256(_auction.amountToSell),
          int256(_debt)
        )
      )
    );

    globalSettlement.fastTrackAuction(_auction.collateralType, _auction.id);
  }

  function test_Emit_FastTrackAuction(FastTrackAuctionStruct memory _auction) public {
    uint256 _debt = _assumeHappyPath(_auction);
    _mockValues(_auction);

    expectEmitNoIndex();
    emit FastTrackAuction(_auction.collateralType, _auction.id, _auction.collateralTotalDebt + _debt);

    globalSettlement.fastTrackAuction(_auction.collateralType, _auction.id);
  }
}

contract Unit_GlobalSettlement_ProcessSAFE is Base {
  using Math for uint256;

  struct ProcessSAFEStruct {
    bytes32 collateralType;
    uint256 finalCoinPerCollateralPrice;
    uint256 collateralShortfall;
    uint256 accumulatedRate;
    address safe;
    uint256 lockedCollateral;
    uint256 generatedDebt;
  }

  event ProcessSAFE(bytes32 indexed _cType, address indexed _safe, uint256 _collateralShortfall);

  function _assumeHappyPath(ProcessSAFEStruct memory _safeData)
    internal
    view
    returns (uint256 _amountOwed, uint256 _minCollateral)
  {
    vm.assume(_safeData.finalCoinPerCollateralPrice != 0);
    vm.assume(notOverflowMul(_safeData.generatedDebt, _safeData.accumulatedRate));
    vm.assume(
      notOverflowMul(_safeData.generatedDebt.rmul(_safeData.accumulatedRate), _safeData.finalCoinPerCollateralPrice)
    );

    _amountOwed = _safeData.generatedDebt.rmul(_safeData.accumulatedRate).rmul(_safeData.finalCoinPerCollateralPrice);
    _minCollateral = Math.min(_safeData.lockedCollateral, _amountOwed);

    vm.assume(notOverflowAdd(_safeData.collateralShortfall, _amountOwed - _minCollateral));
    vm.assume(notOverflowInt256(_minCollateral));
    vm.assume(notOverflowInt256(_safeData.generatedDebt));
  }

  function _mockValues(ProcessSAFEStruct memory _safeData) internal {
    _mockFinalCoinPerCollateralPrice(_safeData.collateralType, _safeData.finalCoinPerCollateralPrice);
    _mockCollateralShortfall(_safeData.collateralType, _safeData.collateralShortfall);
    _mockSafeEngine(address(mockSafeEngine));
    _mockAccountingEngine(address(mockAccountingEngine));
    _mockSafeEngineCollateralData(_safeData.collateralType, 0, _safeData.accumulatedRate, 0, 0);
    _mockSafeEngineSafeData(
      _safeData.collateralType, _safeData.safe, _safeData.lockedCollateral, _safeData.generatedDebt
    );
  }

  function test_Revert_FinalCollateralPriceNotDefined(ProcessSAFEStruct memory _safeData) public {
    vm.expectRevert(IGlobalSettlement.GS_FinalCollateralPriceNotDefined.selector);

    globalSettlement.processSAFE(_safeData.collateralType, _safeData.safe);
  }

  function test_Revert_IntOverflow_1(ProcessSAFEStruct memory _safeData) public {
    vm.assume(_safeData.finalCoinPerCollateralPrice != 0);
    vm.assume(notOverflowMul(_safeData.generatedDebt, _safeData.accumulatedRate));
    vm.assume(
      notOverflowMul(_safeData.generatedDebt.rmul(_safeData.accumulatedRate), _safeData.finalCoinPerCollateralPrice)
    );

    uint256 _amountOwed =
      _safeData.generatedDebt.rmul(_safeData.accumulatedRate).rmul(_safeData.finalCoinPerCollateralPrice);
    uint256 _minCollateral = Math.min(_safeData.lockedCollateral, _amountOwed);

    vm.assume(notOverflowAdd(_safeData.collateralShortfall, _amountOwed - _minCollateral));
    vm.assume(notOverflowInt256(_minCollateral));
    vm.assume(!notOverflowInt256(_safeData.generatedDebt));

    _mockValues(_safeData);

    vm.expectRevert(Math.IntOverflow.selector);

    globalSettlement.processSAFE(_safeData.collateralType, _safeData.safe);
  }

  function test_Set_CollateralShortfall(ProcessSAFEStruct memory _safeData) public {
    (uint256 _amountOwed, uint256 _minCollateral) = _assumeHappyPath(_safeData);
    _mockValues(_safeData);

    globalSettlement.processSAFE(_safeData.collateralType, _safeData.safe);

    assertEq(
      globalSettlement.collateralShortfall(_safeData.collateralType),
      _safeData.collateralShortfall + (_amountOwed - _minCollateral)
    );
  }

  function test_Call_SafeEngine_ConfiscateSAFECollateralAndDebt(ProcessSAFEStruct memory _safeData) public {
    (, uint256 _minCollateral) = _assumeHappyPath(_safeData);
    _mockValues(_safeData);

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.confiscateSAFECollateralAndDebt,
        (
          _safeData.collateralType,
          _safeData.safe,
          address(globalSettlement),
          address(mockAccountingEngine),
          -int256(_minCollateral),
          -int256(_safeData.generatedDebt)
        )
      )
    );

    globalSettlement.processSAFE(_safeData.collateralType, _safeData.safe);
  }

  function test_Emit_ProcessSAFE(ProcessSAFEStruct memory _safeData) public {
    (uint256 _amountOwed, uint256 _minCollateral) = _assumeHappyPath(_safeData);
    _mockValues(_safeData);

    expectEmitNoIndex();
    emit ProcessSAFE(
      _safeData.collateralType, _safeData.safe, _safeData.collateralShortfall + (_amountOwed - _minCollateral)
    );

    globalSettlement.processSAFE(_safeData.collateralType, _safeData.safe);
  }
}

contract Unit_GlobalSettlement_FreeCollateral is Base {
  event FreeCollateral(bytes32 indexed _cType, address indexed _sender, int256 _collateralAmount);

  modifier happyPath(bytes32 _cType, uint256 _lockedCollateral) {
    vm.startPrank(user);

    _assumeHappyPath(_lockedCollateral);
    _mockValues(_cType, _lockedCollateral, 0);
    _;
  }

  function _assumeHappyPath(uint256 _lockedCollateral) internal view {
    vm.assume(notOverflowInt256(_lockedCollateral));
  }

  function _mockValues(bytes32 _cType, uint256 _lockedCollateral, uint256 _generatedDebt) internal {
    _mockContractEnabled(0);
    _mockSafeEngine(address(mockSafeEngine));
    _mockAccountingEngine(address(mockAccountingEngine));
    _mockSafeEngineSafeData(_cType, user, _lockedCollateral, _generatedDebt);
  }

  function test_Revert_ContractIsEnabled(bytes32 _cType) public {
    vm.expectRevert(IDisableable.ContractIsEnabled.selector);

    globalSettlement.freeCollateral(_cType);
  }

  function test_Revert_SafeDebtNotZero(bytes32 _cType, uint256 _lockedCollateral, uint256 _generatedDebt) public {
    vm.startPrank(user);
    vm.assume(_generatedDebt != 0);

    _mockValues(_cType, _lockedCollateral, _generatedDebt);

    vm.expectRevert(IGlobalSettlement.GS_SafeDebtNotZero.selector);

    globalSettlement.freeCollateral(_cType);
  }

  function test_Revert_IntOverflow(bytes32 _cType, uint256 _lockedCollateral) public {
    vm.startPrank(user);
    vm.assume(!notOverflowInt256(_lockedCollateral));

    _mockValues(_cType, _lockedCollateral, 0);

    vm.expectRevert(Math.IntOverflow.selector);

    globalSettlement.freeCollateral(_cType);
  }

  function test_Call_SafeEngine_ConfiscateSAFECollateralAndDebt(
    bytes32 _cType,
    uint256 _lockedCollateral
  ) public happyPath(_cType, _lockedCollateral) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.confiscateSAFECollateralAndDebt,
        (_cType, user, user, address(mockAccountingEngine), -int256(_lockedCollateral), 0)
      )
    );

    globalSettlement.freeCollateral(_cType);
  }

  function test_Emit_FreeCollateral(
    bytes32 _cType,
    uint256 _lockedCollateral
  ) public happyPath(_cType, _lockedCollateral) {
    expectEmitNoIndex();
    emit FreeCollateral(_cType, user, -int256(_lockedCollateral));

    globalSettlement.freeCollateral(_cType);
  }
}

contract Unit_GlobalSettlement_SetOutstandingCoinSupply is Base {
  event SetOutstandingCoinSupply(uint256 _outstandingCoinSupply);

  modifier happyPath(uint256 _shutdownTime, uint256 _shutdownCooldown, uint256 _globalDebt) {
    _assumeHappyPath(_shutdownTime, _shutdownCooldown);
    _mockValues(_shutdownTime, _shutdownCooldown, 0, 0, _globalDebt);
    _;
  }

  function _assumeHappyPath(uint256 _shutdownTime, uint256 _shutdownCooldown) internal view {
    vm.assume(notOverflowAdd(_shutdownTime, _shutdownCooldown));
    vm.assume(block.timestamp >= _shutdownTime + _shutdownCooldown);
  }

  function _mockValues(
    uint256 _shutdownTime,
    uint256 _shutdownCooldown,
    uint256 _outstandingCoinSupply,
    uint256 _coinBalance,
    uint256 _globalDebt
  ) internal {
    _mockContractEnabled(0);
    _mockShutdownTime(_shutdownTime);
    _mockShutdownCooldown(_shutdownCooldown);
    _mockOutstandingCoinSupply(_outstandingCoinSupply);
    _mockSafeEngine(address(mockSafeEngine));
    _mockAccountingEngine(address(mockAccountingEngine));
    _mockCoinBalance(address(mockAccountingEngine), _coinBalance);
    _mockGlobalDebt(_globalDebt);
  }

  function test_Revert_ContractIsEnabled() public {
    vm.expectRevert(IDisableable.ContractIsEnabled.selector);

    globalSettlement.setOutstandingCoinSupply();
  }

  function test_Revert_OutstandingCoinSupplyNotZero(uint256 _outstandingCoinSupply) public {
    vm.assume(_outstandingCoinSupply != 0);

    _mockValues(0, 0, _outstandingCoinSupply, 0, 0);

    vm.expectRevert(IGlobalSettlement.GS_OutstandingCoinSupplyNotZero.selector);

    globalSettlement.setOutstandingCoinSupply();
  }

  function test_Revert_SurplusNotZero(uint256 _coinBalance) public {
    vm.assume(_coinBalance != 0);

    _mockValues(0, 0, 0, _coinBalance, 0);

    vm.expectRevert(IGlobalSettlement.GS_SurplusNotZero.selector);

    globalSettlement.setOutstandingCoinSupply();
  }

  function test_Revert_ShutdownCooldownNotFinished(uint256 _shutdownTime, uint256 _shutdownCooldown) public {
    vm.assume(notOverflowAdd(_shutdownTime, _shutdownCooldown));
    vm.assume(block.timestamp < _shutdownTime + _shutdownCooldown);

    _mockValues(_shutdownTime, _shutdownCooldown, 0, 0, 0);

    vm.expectRevert(IGlobalSettlement.GS_ShutdownCooldownNotFinished.selector);

    globalSettlement.setOutstandingCoinSupply();
  }

  function test_Set_OutstandingCoinSupply(
    uint256 _shutdownTime,
    uint256 _shutdownCooldown,
    uint256 _globalDebt
  ) public happyPath(_shutdownTime, _shutdownCooldown, _globalDebt) {
    globalSettlement.setOutstandingCoinSupply();

    assertEq(globalSettlement.outstandingCoinSupply(), _globalDebt);
  }

  function test_Emit_SetOutstandingCoinSupply(
    uint256 _shutdownTime,
    uint256 _shutdownCooldown,
    uint256 _globalDebt
  ) public happyPath(_shutdownTime, _shutdownCooldown, _globalDebt) {
    expectEmitNoIndex();
    emit SetOutstandingCoinSupply(_globalDebt);

    globalSettlement.setOutstandingCoinSupply();
  }
}

contract Unit_GlobalSettlement_CalculateCashPrice is Base {
  using Math for uint256;

  event CalculateCashPrice(bytes32 indexed _cType, uint256 _collateralCashPrice);

  function _assumeHappyPath(
    uint256 _outstandingCoinSupply,
    uint256 _finalCoinPerCollateralPrice,
    uint256 _collateralShortfall,
    uint256 _collateralTotalDebt,
    uint256 _accumulatedRate
  ) internal view returns (uint256 _redemptionAdjustedDebt) {
    vm.assume(_outstandingCoinSupply != 0);
    vm.assume(notOverflowMul(_collateralTotalDebt, _accumulatedRate));
    vm.assume(notOverflowMul(_collateralTotalDebt.rmul(_accumulatedRate), _finalCoinPerCollateralPrice));

    _redemptionAdjustedDebt = _collateralTotalDebt.rmul(_accumulatedRate).rmul(_finalCoinPerCollateralPrice);

    vm.assume(notUnderflow(_redemptionAdjustedDebt, _collateralShortfall));
    vm.assume(_outstandingCoinSupply / RAY != 0);
  }

  function _mockValues(
    bytes32 _cType,
    uint256 _outstandingCoinSupply,
    uint256 _finalCoinPerCollateralPrice,
    uint256 _collateralShortfall,
    uint256 _collateralTotalDebt,
    uint256 _collateralCashPrice,
    uint256 _accumulatedRate
  ) internal {
    _mockOutstandingCoinSupply(_outstandingCoinSupply);
    _mockFinalCoinPerCollateralPrice(_cType, _finalCoinPerCollateralPrice);
    _mockCollateralShortfall(_cType, _collateralShortfall);
    _mockCollateralTotalDebt(_cType, _collateralTotalDebt);
    _mockCollateralCashPrice(_cType, _collateralCashPrice);
    _mockSafeEngine(address(mockSafeEngine));
    _mockSafeEngineCollateralData(_cType, 0, _accumulatedRate, 0, 0);
  }

  function test_Revert_OutstandingCoinSupplyZero(bytes32 _cType) public {
    vm.expectRevert(IGlobalSettlement.GS_OutstandingCoinSupplyZero.selector);

    globalSettlement.calculateCashPrice(_cType);
  }

  function test_Revert_CollateralCashPriceAlreadyDefined(
    bytes32 _cType,
    uint256 _outstandingCoinSupply,
    uint256 _collateralCashPrice
  ) public {
    vm.assume(_outstandingCoinSupply != 0);
    vm.assume(_collateralCashPrice != 0);

    _mockValues(_cType, _outstandingCoinSupply, 0, 0, 0, _collateralCashPrice, 0);

    vm.expectRevert(IGlobalSettlement.GS_CollateralCashPriceAlreadyDefined.selector);

    globalSettlement.calculateCashPrice(_cType);
  }

  function test_Set_CollateralCashPrice(
    bytes32 _cType,
    uint256 _outstandingCoinSupply,
    uint256 _finalCoinPerCollateralPrice,
    uint256 _collateralShortfall,
    uint256 _collateralTotalDebt,
    uint256 _accumulatedRate
  ) public {
    uint256 _redemptionAdjustedDebt = _assumeHappyPath(
      _outstandingCoinSupply, _finalCoinPerCollateralPrice, _collateralShortfall, _collateralTotalDebt, _accumulatedRate
    );
    _mockValues(
      _cType,
      _outstandingCoinSupply,
      _finalCoinPerCollateralPrice,
      _collateralShortfall,
      _collateralTotalDebt,
      0,
      _accumulatedRate
    );

    globalSettlement.calculateCashPrice(_cType);

    assertEq(
      globalSettlement.collateralCashPrice(_cType),
      (_redemptionAdjustedDebt - _collateralShortfall) * RAY / (_outstandingCoinSupply / RAY)
    );
  }

  function test_Emit_CalculateCashPrice(
    bytes32 _cType,
    uint256 _outstandingCoinSupply,
    uint256 _finalCoinPerCollateralPrice,
    uint256 _collateralShortfall,
    uint256 _collateralTotalDebt,
    uint256 _accumulatedRate
  ) public {
    uint256 _redemptionAdjustedDebt = _assumeHappyPath(
      _outstandingCoinSupply, _finalCoinPerCollateralPrice, _collateralShortfall, _collateralTotalDebt, _accumulatedRate
    );
    _mockValues(
      _cType,
      _outstandingCoinSupply,
      _finalCoinPerCollateralPrice,
      _collateralShortfall,
      _collateralTotalDebt,
      0,
      _accumulatedRate
    );

    expectEmitNoIndex();
    emit CalculateCashPrice(
      _cType, (_redemptionAdjustedDebt - _collateralShortfall) * RAY / (_outstandingCoinSupply / RAY)
    );

    globalSettlement.calculateCashPrice(_cType);
  }
}

contract Unit_GlobalSettlement_PrepareCoinsForRedeeming is Base {
  event PrepareCoinsForRedeeming(address indexed _sender, uint256 _coinBag);

  modifier happyPath(uint256 _coinAmount, uint256 _outstandingCoinSupply, uint256 _coinBag) {
    vm.startPrank(user);

    _assumeHappyPath(_coinAmount, _outstandingCoinSupply, _coinBag);
    _mockValues(_outstandingCoinSupply, _coinBag);
    _;
  }

  function _assumeHappyPath(uint256 _coinAmount, uint256 _outstandingCoinSupply, uint256 _coinBag) internal view {
    vm.assume(_outstandingCoinSupply != 0);
    vm.assume(notOverflowMul(_coinAmount, RAY));
    vm.assume(notOverflowAdd(_coinBag, _coinAmount));
  }

  function _mockValues(uint256 _outstandingCoinSupply, uint256 _coinBag) internal {
    _mockOutstandingCoinSupply(_outstandingCoinSupply);
    _mockCoinBag(user, _coinBag);
    _mockSafeEngine(address(mockSafeEngine));
    _mockAccountingEngine(address(mockAccountingEngine));
  }

  function test_Revert_OutstandingCoinSupplyZero(uint256 _coinAmount) public {
    vm.expectRevert(IGlobalSettlement.GS_OutstandingCoinSupplyZero.selector);

    globalSettlement.prepareCoinsForRedeeming(_coinAmount);
  }

  function test_Call_SafeEngine_TransferInternalCoins(
    uint256 _coinAmount,
    uint256 _outstandingCoinSupply,
    uint256 _coinBag
  ) public happyPath(_coinAmount, _outstandingCoinSupply, _coinBag) {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.transferInternalCoins, (user, address(mockAccountingEngine), _coinAmount * RAY))
    );

    globalSettlement.prepareCoinsForRedeeming(_coinAmount);
  }

  function test_Set_CoinBag(
    uint256 _coinAmount,
    uint256 _outstandingCoinSupply,
    uint256 _coinBag
  ) public happyPath(_coinAmount, _outstandingCoinSupply, _coinBag) {
    globalSettlement.prepareCoinsForRedeeming(_coinAmount);

    assertEq(globalSettlement.coinBag(user), _coinBag + _coinAmount);
  }

  function test_Emit_PrepareCoinsForRedeeming(
    uint256 _coinAmount,
    uint256 _outstandingCoinSupply,
    uint256 _coinBag
  ) public happyPath(_coinAmount, _outstandingCoinSupply, _coinBag) {
    expectEmitNoIndex();
    emit PrepareCoinsForRedeeming(user, _coinBag + _coinAmount);

    globalSettlement.prepareCoinsForRedeeming(_coinAmount);
  }
}

contract Unit_GlobalSettlement_RedeemCollateral is Base {
  using Math for uint256;

  struct RedeemCollateralStruct {
    bytes32 collateralType;
    uint256 collateralCashPrice;
    uint256 coinsAmount;
    uint256 coinBag;
    uint256 coinsUsedToRedeem;
  }

  event RedeemCollateral(
    bytes32 indexed _cType, address indexed _sender, uint256 _coinsAmount, uint256 _collateralAmount
  );

  modifier happyPath(RedeemCollateralStruct memory _collateralData) {
    vm.startPrank(user);

    _assumeHappyPath(_collateralData);
    _mockValues(_collateralData);
    _;
  }

  function _assumeHappyPath(RedeemCollateralStruct memory _collateralData) internal view {
    vm.assume(_collateralData.collateralCashPrice != 0);
    vm.assume(notOverflowMul(_collateralData.coinsAmount, _collateralData.collateralCashPrice));
    vm.assume(notOverflowAdd(_collateralData.coinsUsedToRedeem, _collateralData.coinsAmount));
    vm.assume(_collateralData.coinsUsedToRedeem + _collateralData.coinsAmount <= _collateralData.coinBag);
  }

  function _mockValues(RedeemCollateralStruct memory _collateralData) internal {
    _mockCollateralCashPrice(_collateralData.collateralType, _collateralData.collateralCashPrice);
    _mockCoinBag(user, _collateralData.coinBag);
    _mockCoinsUsedToRedeem(_collateralData.collateralType, user, _collateralData.coinsUsedToRedeem);
    _mockSafeEngine(address(mockSafeEngine));
  }

  function test_Revert_CollateralCashPriceNotDefined(RedeemCollateralStruct memory _collateralData) public {
    vm.expectRevert(IGlobalSettlement.GS_CollateralCashPriceNotDefined.selector);

    globalSettlement.redeemCollateral(_collateralData.collateralType, _collateralData.coinsAmount);
  }

  function test_Revert_InsufficientBagBalance(RedeemCollateralStruct memory _collateralData) public {
    vm.startPrank(user);
    vm.assume(_collateralData.collateralCashPrice != 0);
    vm.assume(notOverflowMul(_collateralData.coinsAmount, _collateralData.collateralCashPrice));
    vm.assume(notOverflowAdd(_collateralData.coinsUsedToRedeem, _collateralData.coinsAmount));
    vm.assume(_collateralData.coinsUsedToRedeem + _collateralData.coinsAmount > _collateralData.coinBag);

    _mockValues(_collateralData);

    vm.expectRevert(IGlobalSettlement.GS_InsufficientBagBalance.selector);

    globalSettlement.redeemCollateral(_collateralData.collateralType, _collateralData.coinsAmount);
  }

  function test_Call_SafeEngine_TransferCollateral(RedeemCollateralStruct memory _collateralData)
    public
    happyPath(_collateralData)
  {
    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(
        mockSafeEngine.transferCollateral,
        (
          _collateralData.collateralType,
          address(globalSettlement),
          user,
          _collateralData.coinsAmount.rmul(_collateralData.collateralCashPrice)
        )
      )
    );

    globalSettlement.redeemCollateral(_collateralData.collateralType, _collateralData.coinsAmount);
  }

  function test_Set_CoinsUsedToRedeem(RedeemCollateralStruct memory _collateralData) public happyPath(_collateralData) {
    globalSettlement.redeemCollateral(_collateralData.collateralType, _collateralData.coinsAmount);

    assertEq(
      globalSettlement.coinsUsedToRedeem(_collateralData.collateralType, user),
      _collateralData.coinsUsedToRedeem + _collateralData.coinsAmount
    );
  }

  function test_Emit_RedeemCollateral(RedeemCollateralStruct memory _collateralData) public happyPath(_collateralData) {
    expectEmitNoIndex();
    emit RedeemCollateral(
      _collateralData.collateralType,
      user,
      _collateralData.coinsAmount,
      _collateralData.coinsAmount.rmul(_collateralData.collateralCashPrice)
    );

    globalSettlement.redeemCollateral(_collateralData.collateralType, _collateralData.coinsAmount);
  }
}

contract Unit_GlobalSettlement_ModifyParameters is Base {
  event ModifyParameters(bytes32 indexed _param, bytes32 indexed _cType, bytes _data);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized(bytes32 _param, bytes memory _data) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    globalSettlement.modifyParameters(_param, _data);
  }

  function test_Revert_ContractIsDisabled(bytes32 _param, bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    _mockContractEnabled(0);

    vm.expectRevert(IDisableable.ContractIsDisabled.selector);

    globalSettlement.modifyParameters(_param, _data);
  }

  function test_Set_SafeEngine(address _safeEngine) public happyPath {
    globalSettlement.modifyParameters('safeEngine', abi.encode(_safeEngine));

    assertEq(address(globalSettlement.safeEngine()), _safeEngine);
  }

  function test_Set_LiquidationEngine(address _liquidationEngine) public happyPath {
    globalSettlement.modifyParameters('liquidationEngine', abi.encode(_liquidationEngine));

    assertEq(address(globalSettlement.liquidationEngine()), _liquidationEngine);
  }

  function test_Set_AccountingEngine(address _accountingEngine) public happyPath {
    globalSettlement.modifyParameters('accountingEngine', abi.encode(_accountingEngine));

    assertEq(address(globalSettlement.accountingEngine()), _accountingEngine);
  }

  function test_Set_OracleRelayer(address _oracleRelayer) public happyPath {
    globalSettlement.modifyParameters('oracleRelayer', abi.encode(_oracleRelayer));

    assertEq(address(globalSettlement.oracleRelayer()), _oracleRelayer);
  }

  function test_Set_StabilityFeeTreasury(address _stabilityFeeTreasury) public happyPath {
    globalSettlement.modifyParameters('stabilityFeeTreasury', abi.encode(_stabilityFeeTreasury));

    assertEq(address(globalSettlement.stabilityFeeTreasury()), _stabilityFeeTreasury);
  }

  function test_Set_ShutdownCooldown(uint256 _shutdownCooldown) public happyPath {
    globalSettlement.modifyParameters('shutdownCooldown', abi.encode(_shutdownCooldown));

    assertEq(globalSettlement.shutdownCooldown(), _shutdownCooldown);
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    globalSettlement.modifyParameters('unrecognizedParam', _data);
  }

  function test_Emit_ModifyParameters(uint256 _shutdownCooldown) public happyPath {
    expectEmitNoIndex();
    emit ModifyParameters('shutdownCooldown', GLOBAL_PARAM, abi.encode(_shutdownCooldown));

    globalSettlement.modifyParameters('shutdownCooldown', abi.encode(_shutdownCooldown));
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {TaxCollectorForTest, ITaxCollector} from '@test/mocks/TaxCollectorForTest.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IModifiablePerCollateral} from '@interfaces/utils/IModifiablePerCollateral.sol';

import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

import {Math, RAY, WAD} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is HaiTest {
  using Math for uint256;
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  ISAFEEngine mockSafeEngine = ISAFEEngine(mockContract('SAFEEngine'));

  TaxCollectorForTest taxCollector;

  // SafeEngine storage
  uint256 coinBalance = RAY;
  uint256 debtAmount = 1e25;
  uint256 lastAccumulatedRate = 1e15;

  // TaxCollector storage
  bytes32 collateralTypeA = 'collateralTypeA';
  bytes32 collateralTypeB = 'collateralTypeB';
  bytes32 collateralTypeC = 'collateralTypeC';
  address primaryTaxReceiver = newAddress();
  address secondaryReceiverA = newAddress();
  address secondaryReceiverB = newAddress();
  address secondaryReceiverC = newAddress();
  uint256 maxStabilityFeeRange = RAY - 1;
  uint256 globalStabilityFee = RAY;
  uint256 stabilityFee = 1e5;
  uint256 nextStabilityFee = 1e10;
  uint256 updateTime = block.timestamp - 100;
  uint256 secondaryReceiverAllotedTax = WAD / 2;
  uint256 taxPercentage = WAD / 4;
  bool canTakeBackTax = true;

  // Input parameters
  address receiver;

  ITaxCollector.TaxCollectorParams taxCollectorParams = ITaxCollector.TaxCollectorParams({
    primaryTaxReceiver: primaryTaxReceiver,
    globalStabilityFee: globalStabilityFee,
    maxStabilityFeeRange: maxStabilityFeeRange,
    maxSecondaryReceivers: 0
  });

  ITaxCollector.TaxCollectorCollateralParams taxCollectorCollateralParams =
    ITaxCollector.TaxCollectorCollateralParams({stabilityFee: stabilityFee});

  function setUp() public virtual {
    vm.startPrank(deployer);

    taxCollector = new TaxCollectorForTest(address(mockSafeEngine), taxCollectorParams);
    label(address(taxCollector), 'TaxCollector');

    taxCollector.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function setUpTaxManyOutcome() public {
    setUpTaxSingleOutcome(collateralTypeA);
    setUpTaxSingleOutcome(collateralTypeB);
    setUpTaxSingleOutcome(collateralTypeC);

    // SafeEngine storage
    _mockCoinBalance(primaryTaxReceiver, coinBalance);

    // TaxCollector storage
    _mockCollateralList(collateralTypeA);
    _mockCollateralList(collateralTypeB);
    _mockCollateralList(collateralTypeC);
  }

  function setUpTaxSingleOutcome(bytes32 _cType) public {
    // SafeEngine storage
    _mockSafeEngineCData(_cType, debtAmount, 0, lastAccumulatedRate, 0, 0);

    // TaxCollector storage
    _mockNextStabilityFee(_cType, nextStabilityFee);
    _mockUpdateTime(_cType, updateTime);
  }

  function setUpTaxMany() public {
    setUpTaxManyOutcome();

    setUpSplitTaxIncome(collateralTypeA);
    setUpSplitTaxIncome(collateralTypeB);
    setUpSplitTaxIncome(collateralTypeC);

    // TaxCollector storage
    _mockStabilityFee(collateralTypeA, stabilityFee);
    _mockStabilityFee(collateralTypeB, stabilityFee);
    _mockStabilityFee(collateralTypeC, stabilityFee);
  }

  function setUpTaxSingle(bytes32 _cType) public {
    setUpTaxSingleOutcome(_cType);

    setUpSplitTaxIncome(_cType);

    // TaxCollector storage
    _mockStabilityFee(_cType, stabilityFee);
  }

  function setUpSplitTaxIncome(bytes32 _cType) public {
    setUpDistributeTax(_cType);

    // SafeEngine storage
    _mockCoinBalance(secondaryReceiverB, coinBalance);
    _mockCoinBalance(secondaryReceiverC, coinBalance);

    // TaxCollector storage
    _mockSecondaryReceiver(secondaryReceiverA);
    _mockSecondaryReceiver(secondaryReceiverB);
    _mockSecondaryReceiver(secondaryReceiverC);
    _mockSecondaryTaxReceiver(_cType, secondaryReceiverB, canTakeBackTax, 0);
    _mockSecondaryTaxReceiver(_cType, secondaryReceiverC, canTakeBackTax, taxPercentage);
  }

  function setUpDistributeTax(bytes32 _cType) public {
    // SafeEngine storage
    _mockCoinBalance(primaryTaxReceiver, coinBalance);
    _mockCoinBalance(secondaryReceiverA, coinBalance);

    // TaxCollector storage
    _mockSecondaryReceiverAllotedTax(_cType, secondaryReceiverAllotedTax);
    _mockSecondaryTaxReceiver(_cType, secondaryReceiverA, canTakeBackTax, taxPercentage);
  }

  function _mockCoinBalance(address _coinAddress, uint256 _coinBalance) internal {
    vm.mockCall(
      address(mockSafeEngine), abi.encodeCall(mockSafeEngine.coinBalance, (_coinAddress)), abi.encode(_coinBalance)
    );
  }

  function _mockSafeEngineCData(
    bytes32 _cType,
    uint256 _debtAmount,
    uint256 _lockedAmount,
    uint256 _accumulatedRate,
    uint256 _safetyPrice,
    uint256 _liquidationPrice
  ) internal {
    vm.mockCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.cData, (_cType)),
      abi.encode(_debtAmount, _lockedAmount, _accumulatedRate, _safetyPrice, _liquidationPrice)
    );
  }

  // params
  function _mockGlobalStabilityFee(uint256 _globalStabilityFee) internal {
    stdstore.target(address(taxCollector)).sig(ITaxCollector.params.selector).depth(1).checked_write(
      _globalStabilityFee
    );
  }

  function _mockMaxStabilityFeeRange(uint256 _maxStabilityFeeRange) internal {
    stdstore.target(address(taxCollector)).sig(ITaxCollector.params.selector).depth(2).checked_write(
      _maxStabilityFeeRange
    );
  }

  // cParams
  function _mockStabilityFee(bytes32 _cType, uint256 _stabilityFee) internal {
    stdstore.target(address(taxCollector)).sig(ITaxCollector.cParams.selector).with_key(_cType).depth(0).checked_write(
      _stabilityFee
    );
  }

  // cData
  function _mockNextStabilityFee(bytes32 _cType, uint256 _nextStabilityFee) internal {
    stdstore.target(address(taxCollector)).sig(ITaxCollector.cData.selector).with_key(_cType).depth(0).checked_write(
      _nextStabilityFee
    );
  }

  function _mockUpdateTime(bytes32 _cType, uint256 _updateTime) internal {
    stdstore.target(address(taxCollector)).sig(ITaxCollector.cData.selector).with_key(_cType).depth(1).checked_write(
      _updateTime
    );
  }

  function _mockSecondaryReceiverAllotedTax(bytes32 _cType, uint256 _secondaryReceiverAllotedTax) internal {
    stdstore.target(address(taxCollector)).sig(ITaxCollector.cData.selector).with_key(_cType).depth(2).checked_write(
      _secondaryReceiverAllotedTax
    );
  }

  function _mockSecondaryTaxReceiver(
    bytes32 _cType,
    address _receiver,
    bool _canTakeBackTax,
    uint256 _taxPercentage
  ) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    taxCollector.addSecondaryTaxReceiver(_cType, _receiver, _canTakeBackTax, _taxPercentage);
  }

  function _mockCollateralList(bytes32 _cType) internal {
    taxCollector.addToCollateralList(_cType);
  }

  function _mockSecondaryReceiver(address _receiver) internal {
    taxCollector.addSecondaryReceiver(_receiver);
  }

  function _assumeCurrentTaxCut(
    uint256 _debtAmount,
    int256 _deltaRate,
    bool _isPrimaryTaxReceiver,
    bool _isAbsorbable
  ) internal returns (int256 _currentTaxCut) {
    if (_isPrimaryTaxReceiver) {
      receiver = primaryTaxReceiver;
      if (!_isAbsorbable) {
        vm.assume(_deltaRate <= -int256(WAD / secondaryReceiverAllotedTax) && _deltaRate >= -int256(WAD));
        _currentTaxCut = (WAD - secondaryReceiverAllotedTax).wmul(_deltaRate);
        vm.assume(_debtAmount <= coinBalance);
        vm.assume(-int256(coinBalance) > _debtAmount.mul(_currentTaxCut));
        _currentTaxCut = -int256(coinBalance) / int256(_debtAmount);
      } else {
        vm.assume(
          _deltaRate <= -int256(WAD / secondaryReceiverAllotedTax) && _deltaRate >= -int256(WAD)
            || _deltaRate >= int256(WAD / secondaryReceiverAllotedTax) && _deltaRate <= int256(WAD)
        );
        _currentTaxCut = (WAD - secondaryReceiverAllotedTax).wmul(_deltaRate);
        vm.assume(_debtAmount == 0);
      }
    } else {
      receiver = secondaryReceiverA;
      if (!_isAbsorbable) {
        vm.assume(_deltaRate <= -int256(WAD / taxPercentage) && _deltaRate >= -int256(WAD));
        _currentTaxCut = taxPercentage.wmul(_deltaRate);
        vm.assume(_debtAmount <= coinBalance);
        vm.assume(-int256(coinBalance) > _debtAmount.mul(_currentTaxCut));
        _currentTaxCut = -int256(coinBalance) / int256(_debtAmount);
      } else {
        vm.assume(
          _deltaRate <= -int256(WAD / taxPercentage) && _deltaRate >= -int256(WAD)
            || _deltaRate >= int256(WAD / taxPercentage) && _deltaRate <= int256(WAD)
        );
        _currentTaxCut = taxPercentage.wmul(_deltaRate);
        vm.assume(_debtAmount <= WAD && -int256(coinBalance) <= _debtAmount.mul(_currentTaxCut));
      }
    }
  }
}

contract Unit_TaxCollector_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new TaxCollectorForTest(address(mockSafeEngine), taxCollectorParams);
  }

  function test_Set_SafeEngine(address _safeEngine) public happyPath {
    vm.assume(_safeEngine != address(0));

    taxCollector = new TaxCollectorForTest(_safeEngine, taxCollectorParams);

    assertEq(address(taxCollector.safeEngine()), _safeEngine);
  }

  function test_Set_TaxCollectorParams(ITaxCollector.TaxCollectorParams memory _taxCollectorParams) public happyPath {
    vm.assume(_taxCollectorParams.primaryTaxReceiver != address(0));
    vm.assume(_taxCollectorParams.maxStabilityFeeRange > 0 && _taxCollectorParams.maxStabilityFeeRange < RAY);
    vm.assume(
      _taxCollectorParams.globalStabilityFee >= RAY - _taxCollectorParams.maxStabilityFeeRange
        && _taxCollectorParams.globalStabilityFee <= RAY + _taxCollectorParams.maxStabilityFeeRange
    );

    taxCollector = new TaxCollectorForTest(address(mockSafeEngine), _taxCollectorParams);

    assertEq(abi.encode(taxCollector.params()), abi.encode(_taxCollectorParams));
  }

  function test_Revert_NullAddress_SafeEngine() public {
    vm.expectRevert(Assertions.NullAddress.selector);

    new TaxCollectorForTest(address(0), taxCollectorParams);
  }

  function test_Revert_NullAddress_PrimaryTaxReceiver(ITaxCollector.TaxCollectorParams memory _taxCollectorParams)
    public
  {
    _taxCollectorParams.primaryTaxReceiver = address(0);

    vm.expectRevert(Assertions.NullAddress.selector);

    new TaxCollectorForTest(address(mockSafeEngine), _taxCollectorParams);
  }

  function test_Revert_NotGreaterThan_MaxStabilityFeeRange(ITaxCollector.TaxCollectorParams memory _taxCollectorParams)
    public
  {
    vm.assume(_taxCollectorParams.primaryTaxReceiver != address(0));
    _taxCollectorParams.maxStabilityFeeRange = 0;

    vm.expectRevert(
      abi.encodeWithSelector(Assertions.NotGreaterThan.selector, _taxCollectorParams.maxStabilityFeeRange, 0)
    );

    new TaxCollectorForTest(address(mockSafeEngine), _taxCollectorParams);
  }

  function test_Revert_NotLesserThan_MaxStabilityFeeRange(ITaxCollector.TaxCollectorParams memory _taxCollectorParams)
    public
  {
    vm.assume(_taxCollectorParams.primaryTaxReceiver != address(0));
    vm.assume(_taxCollectorParams.maxStabilityFeeRange >= RAY);

    vm.expectRevert(
      abi.encodeWithSelector(Assertions.NotLesserThan.selector, _taxCollectorParams.maxStabilityFeeRange, RAY)
    );

    new TaxCollectorForTest(address(mockSafeEngine), _taxCollectorParams);
  }

  function test_Revert_NotGreaterOrEqualThan_GlobalStabilityFee(
    ITaxCollector.TaxCollectorParams memory _taxCollectorParams
  ) public {
    vm.assume(_taxCollectorParams.primaryTaxReceiver != address(0));
    vm.assume(_taxCollectorParams.maxStabilityFeeRange > 0 && _taxCollectorParams.maxStabilityFeeRange < RAY);
    vm.assume(_taxCollectorParams.globalStabilityFee < RAY - _taxCollectorParams.maxStabilityFeeRange);

    vm.expectRevert(
      abi.encodeWithSelector(
        Assertions.NotGreaterOrEqualThan.selector,
        _taxCollectorParams.globalStabilityFee,
        RAY - _taxCollectorParams.maxStabilityFeeRange
      )
    );

    new TaxCollectorForTest(address(mockSafeEngine), _taxCollectorParams);
  }

  function test_Revert_NotLesserOrEqualThan_GlobalStabilityFee(
    ITaxCollector.TaxCollectorParams memory _taxCollectorParams
  ) public {
    vm.assume(_taxCollectorParams.primaryTaxReceiver != address(0));
    vm.assume(_taxCollectorParams.maxStabilityFeeRange > 0 && _taxCollectorParams.maxStabilityFeeRange < RAY);
    vm.assume(_taxCollectorParams.globalStabilityFee > RAY + _taxCollectorParams.maxStabilityFeeRange);

    vm.expectRevert(
      abi.encodeWithSelector(
        Assertions.NotLesserOrEqualThan.selector,
        _taxCollectorParams.globalStabilityFee,
        RAY + _taxCollectorParams.maxStabilityFeeRange
      )
    );

    new TaxCollectorForTest(address(mockSafeEngine), _taxCollectorParams);
  }
}

contract Unit_TaxCollector_InitializeCollateralType is Base {
  event InitializeCollateralType(bytes32 _cType);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Revert_Unauthorized(bytes32 _cType) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    taxCollector.initializeCollateralType(_cType, abi.encode(taxCollectorCollateralParams));
  }

  function test_Revert_CollateralTypeAlreadyInit(bytes32 _cType) public {
    vm.startPrank(authorizedAccount);
    _mockCollateralList(_cType);

    vm.expectRevert(IModifiablePerCollateral.CollateralTypeAlreadyInitialized.selector);

    taxCollector.initializeCollateralType(_cType, abi.encode(taxCollectorCollateralParams));
  }

  function test_Revert_NotGreaterOrEqualThan_StabilityFee(
    bytes32 _cType,
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCParams
  ) public {
    vm.startPrank(authorizedAccount);
    vm.assume(_taxCollectorCParams.stabilityFee < RAY - maxStabilityFeeRange);

    vm.expectRevert(
      abi.encodeWithSelector(
        Assertions.NotGreaterOrEqualThan.selector, _taxCollectorCParams.stabilityFee, RAY - maxStabilityFeeRange
      )
    );

    taxCollector.initializeCollateralType(_cType, abi.encode(_taxCollectorCParams));
  }

  function test_Revert_NotLesserOrEqualThan_StabilityFee(
    bytes32 _cType,
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCParams
  ) public {
    vm.startPrank(authorizedAccount);
    vm.assume(_taxCollectorCParams.stabilityFee > RAY + maxStabilityFeeRange);

    vm.expectRevert(
      abi.encodeWithSelector(
        Assertions.NotLesserOrEqualThan.selector, _taxCollectorCParams.stabilityFee, RAY + maxStabilityFeeRange
      )
    );

    taxCollector.initializeCollateralType(_cType, abi.encode(_taxCollectorCParams));
  }

  function test_Set_CollateralList(bytes32 _cType) public happyPath {
    taxCollector.initializeCollateralType(_cType, abi.encode(taxCollectorCollateralParams));

    assertEq(taxCollector.collateralList()[0], _cType);
  }

  function test_Set_NextStabilityFee(bytes32 _cType) public happyPath {
    taxCollector.initializeCollateralType(_cType, abi.encode(taxCollectorCollateralParams));

    assertEq(taxCollector.cData(_cType).nextStabilityFee, RAY);
  }

  function test_Set_UpdateTime(bytes32 _cType) public happyPath {
    taxCollector.initializeCollateralType(_cType, abi.encode(taxCollectorCollateralParams));

    assertEq(taxCollector.cData(_cType).updateTime, block.timestamp);
  }

  function test_Set_StabilityFee(bytes32 _cType) public happyPath {
    taxCollector.initializeCollateralType(_cType, abi.encode(taxCollectorCollateralParams));

    assertEq(taxCollector.cParams(_cType).stabilityFee, stabilityFee);
  }

  function test_Emit_InitializeCollateralType(bytes32 _cType) public happyPath {
    vm.expectEmit();
    emit InitializeCollateralType(_cType);

    taxCollector.initializeCollateralType(_cType, abi.encode(taxCollectorCollateralParams));
  }
}

contract Unit_TaxCollector_CollectedManyTax is Base {
  function setUp() public override {
    Base.setUp();

    Base.setUpTaxManyOutcome();
  }

  function test_Revert_InvalidIndexes_0(uint256 _start, uint256 _end) public {
    vm.assume(_start > _end);

    vm.expectRevert(ITaxCollector.TaxCollector_InvalidIndexes.selector);

    taxCollector.collectedManyTax(_start, _end);
  }

  function test_Revert_InvalidIndexes_1(uint256 _start, uint256 _end) public {
    vm.assume(_start <= _end);
    vm.assume(_end >= taxCollector.collateralListLength());

    vm.expectRevert(ITaxCollector.TaxCollector_InvalidIndexes.selector);

    taxCollector.collectedManyTax(_start, _end);
  }

  function test_Return_Ok_False() public {
    bool _ok = taxCollector.collectedManyTax(0, 2);

    assertEq(_ok, false);
  }

  function test_Return_Ok_True(uint256 _updateTime) public {
    vm.assume(_updateTime >= block.timestamp);

    _mockCollateralList(collateralTypeA);
    _mockCollateralList(collateralTypeB);
    _mockCollateralList(collateralTypeC);
    _mockUpdateTime(collateralTypeA, _updateTime);
    _mockUpdateTime(collateralTypeB, _updateTime);
    _mockUpdateTime(collateralTypeC, _updateTime);

    bool _ok = taxCollector.collectedManyTax(0, 2);

    assertEq(_ok, true);
  }
}

contract Unit_TaxCollector_TaxManyOutcome is Base {
  using Math for uint256;

  function setUp() public override {
    Base.setUp();

    Base.setUpTaxManyOutcome();
  }

  function test_Revert_InvalidIndexes_0(uint256 _start, uint256 _end) public {
    vm.assume(_start > _end);

    vm.expectRevert(ITaxCollector.TaxCollector_InvalidIndexes.selector);

    taxCollector.taxManyOutcome(_start, _end);
  }

  function test_Revert_InvalidIndexes_1(uint256 _start, uint256 _end) public {
    vm.assume(_start <= _end);
    vm.assume(_end >= taxCollector.collateralListLength());

    vm.expectRevert(ITaxCollector.TaxCollector_InvalidIndexes.selector);

    taxCollector.taxManyOutcome(_start, _end);
  }

  function test_Revert_IntOverflow(uint256 _coinBalance) public {
    vm.assume(!notOverflowInt256(_coinBalance));

    _mockCoinBalance(primaryTaxReceiver, _coinBalance);

    vm.expectRevert(Math.IntOverflow.selector);

    taxCollector.taxManyOutcome(0, 2);
  }

  function test_Return_Ok_False() public {
    (bool _ok,) = taxCollector.taxManyOutcome(0, 2);

    assertEq(_ok, false);
  }

  function test_Return_Ok_True_0(uint256 _coinBalance) public {
    (, int256 _deltaRate) = taxCollector.taxSingleOutcome(collateralTypeA);
    int256 _rad = debtAmount.mul(_deltaRate) * 3;

    vm.assume(notOverflowInt256(_coinBalance) && -int256(_coinBalance) <= _rad);

    _mockCoinBalance(primaryTaxReceiver, _coinBalance);

    (bool _ok,) = taxCollector.taxManyOutcome(0, 2);

    assertEq(_ok, true);
  }

  function test_Return_Ok_True_1(uint256 _lastAccumulatedRate) public {
    (uint256 _newlyAccumulatedRate,) = taxCollector.taxSingleOutcome(collateralTypeA);

    vm.assume(_lastAccumulatedRate <= _newlyAccumulatedRate);

    _mockSafeEngineCData(collateralTypeA, debtAmount, 0, _lastAccumulatedRate, 0, 0);
    _mockSafeEngineCData(collateralTypeB, debtAmount, 0, _lastAccumulatedRate, 0, 0);
    _mockSafeEngineCData(collateralTypeC, debtAmount, 0, _lastAccumulatedRate, 0, 0);

    (bool _ok,) = taxCollector.taxManyOutcome(0, 2);

    assertEq(_ok, true);
  }

  function test_Return_Rad(uint256 _updateTime) public {
    vm.assume(_updateTime >= block.timestamp);

    _mockCollateralList(collateralTypeB);
    _mockNextStabilityFee(collateralTypeB, nextStabilityFee);
    _mockUpdateTime(collateralTypeB, _updateTime);

    (, int256 _deltaRate) = taxCollector.taxSingleOutcome(collateralTypeA);
    int256 _expectedRad = debtAmount.mul(_deltaRate) * 2;

    (, int256 _rad) = taxCollector.taxManyOutcome(0, 2);

    assertEq(_rad, _expectedRad);
  }
}

contract Unit_TaxCollector_TaxSingleOutcome is Base {
  using Math for uint256;

  function setUp() public override {
    Base.setUp();

    Base.setUpTaxSingleOutcome(collateralTypeA);
  }

  function test_Return_NewlyAccumulatedRate() public {
    uint256 _expectedNewlyAccumulatedRate =
      nextStabilityFee.rpow(block.timestamp - updateTime).rmul(lastAccumulatedRate);

    (uint256 _newlyAccumulatedRate,) = taxCollector.taxSingleOutcome(collateralTypeA);

    assertEq(_newlyAccumulatedRate, _expectedNewlyAccumulatedRate);
  }

  function test_Return_DeltaRate() public {
    uint256 _newlyAccumulatedRate = nextStabilityFee.rpow(block.timestamp - updateTime).rmul(lastAccumulatedRate);
    int256 _expectedDeltaRate = _newlyAccumulatedRate.sub(lastAccumulatedRate);

    (, int256 _deltaRate) = taxCollector.taxSingleOutcome(collateralTypeA);

    assertEq(_deltaRate, _expectedDeltaRate);
  }
}

contract Unit_TaxCollector_TaxMany is Base {
  event CollectTax(bytes32 indexed _cType, uint256 _latestAccumulatedRate, int256 _deltaRate);

  function setUp() public override {
    Base.setUp();

    Base.setUpTaxMany();
  }

  function test_Revert_InvalidIndexes_0(uint256 _start, uint256 _end) public {
    vm.assume(_start > _end);

    vm.expectRevert(ITaxCollector.TaxCollector_InvalidIndexes.selector);

    taxCollector.taxMany(_start, _end);
  }

  function test_Revert_InvalidIndexes_1(uint256 _start, uint256 _end) public {
    vm.assume(_start <= _end);
    vm.assume(_end >= taxCollector.collateralListLength());

    vm.expectRevert(ITaxCollector.TaxCollector_InvalidIndexes.selector);

    taxCollector.taxMany(_start, _end);
  }

  function test_Emit_CollectTax() public {
    (, int256 _deltaRate) = taxCollector.taxSingleOutcome(collateralTypeA);

    vm.expectEmit();
    emit CollectTax(collateralTypeA, lastAccumulatedRate, _deltaRate);
    vm.expectEmit();
    emit CollectTax(collateralTypeB, lastAccumulatedRate, _deltaRate);
    vm.expectEmit();
    emit CollectTax(collateralTypeC, lastAccumulatedRate, _deltaRate);

    taxCollector.taxMany(0, 2);
  }
}

contract Unit_TaxCollector_TaxSingle is Base {
  using Math for uint256;

  event CollectTax(bytes32 indexed _cType, uint256 _latestAccumulatedRate, int256 _deltaRate);
  event DistributeTax(bytes32 indexed _cType, address indexed _target, int256 _taxCut);

  function setUp() public override {
    Base.setUp();

    Base.setUpTaxSingle(collateralTypeA);
  }

  function test_Set_NextStabilityFee(uint256 _globalStabilityFee, uint256 _stabilityFee, uint256 _updateTime) public {
    vm.assume(notOverflowMul(_globalStabilityFee, _stabilityFee));
    vm.assume(_updateTime <= block.timestamp);
    _mockGlobalStabilityFee(_globalStabilityFee);
    _mockStabilityFee(collateralTypeA, _stabilityFee);
    _mockUpdateTime(collateralTypeA, _updateTime);

    taxCollector.taxSingle(collateralTypeA);

    uint256 _nextStabilityFee = _globalStabilityFee.rmul(_stabilityFee);
    if (_nextStabilityFee < RAY - maxStabilityFeeRange) _nextStabilityFee = RAY - maxStabilityFeeRange;
    if (_nextStabilityFee > RAY + maxStabilityFeeRange) _nextStabilityFee = RAY + maxStabilityFeeRange;

    assertEq(taxCollector.cData(collateralTypeA).nextStabilityFee, _nextStabilityFee);
  }

  function test_Set_UpdateTime() public {
    taxCollector.taxSingle(collateralTypeA);

    assertEq(taxCollector.cData(collateralTypeA).updateTime, block.timestamp);
  }

  function test_Emit_DistributeTax() public {
    (, int256 _deltaRate) = taxCollector.taxSingleOutcome(collateralTypeA);
    int256 _currentTaxCut = _assumeCurrentTaxCut(debtAmount, _deltaRate, false, false);

    vm.expectEmit();
    emit DistributeTax(collateralTypeA, secondaryReceiverA, _currentTaxCut);
    vm.expectEmit();
    emit DistributeTax(collateralTypeA, secondaryReceiverC, _currentTaxCut);
    vm.expectEmit();
    emit DistributeTax(collateralTypeA, primaryTaxReceiver, _currentTaxCut);

    taxCollector.taxSingle(collateralTypeA);
  }

  function test_Emit_CollectTax() public {
    (, int256 _deltaRate) = taxCollector.taxSingleOutcome(collateralTypeA);

    vm.expectEmit();
    emit CollectTax(collateralTypeA, lastAccumulatedRate, _deltaRate);

    taxCollector.taxSingle(collateralTypeA);
  }

  function test_Return_LatestAccumulatedRate(uint256 _updateTime) public {
    vm.assume(_updateTime <= block.timestamp);
    _mockUpdateTime(collateralTypeA, _updateTime);

    assertEq(taxCollector.taxSingle(collateralTypeA), lastAccumulatedRate);
  }

  function testFail_AlreadyLatestAccumulatedRate() public {
    _mockUpdateTime(collateralTypeA, block.timestamp);

    (, int256 _deltaRate) = taxCollector.taxSingleOutcome(collateralTypeA);

    vm.expectEmit(false, false, false, false);
    emit CollectTax(collateralTypeA, lastAccumulatedRate, _deltaRate);

    taxCollector.taxSingle(collateralTypeA);
  }
}

contract Unit_TaxCollector_SplitTaxIncome is Base {
  event DistributeTax(bytes32 indexed _cType, address indexed _target, int256 _taxCut);

  function setUp() public override {
    Base.setUp();

    Base.setUpSplitTaxIncome(collateralTypeA);
  }

  function test_Emit_DistributeTax(uint256 _debtAmount, int256 _deltaRate) public {
    int256 _currentTaxCut = _assumeCurrentTaxCut(_debtAmount, _deltaRate, false, false);

    vm.expectEmit();
    emit DistributeTax(collateralTypeA, secondaryReceiverA, _currentTaxCut);
    vm.expectEmit();
    emit DistributeTax(collateralTypeA, secondaryReceiverC, _currentTaxCut);
    vm.expectEmit();
    emit DistributeTax(collateralTypeA, primaryTaxReceiver, _currentTaxCut);

    taxCollector.splitTaxIncome(collateralTypeA, _debtAmount, _deltaRate);
  }

  function testFail_ShouldNotDistributeTax(uint256 _debtAmount, int256 _deltaRate) public {
    int256 _currentTaxCut = _assumeCurrentTaxCut(_debtAmount, _deltaRate, false, false);

    vm.expectEmit();
    emit DistributeTax(collateralTypeA, secondaryReceiverB, _currentTaxCut);

    taxCollector.splitTaxIncome(collateralTypeA, _debtAmount, _deltaRate);
  }
}

contract Unit_TaxCollector_DistributeTax is Base {
  event DistributeTax(bytes32 indexed _cType, address indexed _target, int256 _taxCut);

  function setUp() public override {
    Base.setUp();

    Base.setUpDistributeTax(collateralTypeA);
  }

  function test_Revert_IntOverflow(
    bytes32 _cType,
    address _receiver,
    uint256 _debtAmount,
    int256 _deltaRate,
    uint256 _coinBalance
  ) public {
    vm.assume(!notOverflowInt256(_coinBalance));

    _mockCoinBalance(_receiver, _coinBalance);

    vm.expectRevert(Math.IntOverflow.selector);

    taxCollector.distributeTax(_cType, _receiver, _debtAmount, _deltaRate);
  }

  function test_Call_SafeEngine_UpdateAccumulatedRate(
    uint256 _debtAmount,
    int256 _deltaRate,
    bool _isPrimaryTaxReceiver,
    bool _isAbsorbable
  ) public {
    int256 _currentTaxCut = _assumeCurrentTaxCut(_debtAmount, _deltaRate, _isPrimaryTaxReceiver, _isAbsorbable);

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(mockSafeEngine.updateAccumulatedRate, (collateralTypeA, receiver, _currentTaxCut)),
      1
    );

    taxCollector.distributeTax(collateralTypeA, receiver, _debtAmount, _deltaRate);
  }

  function test_Emit_DistributeTax(
    uint256 _debtAmount,
    int256 _deltaRate,
    bool _isPrimaryTaxReceiver,
    bool _isAbsorbable
  ) public {
    int256 _currentTaxCut = _assumeCurrentTaxCut(_debtAmount, _deltaRate, _isPrimaryTaxReceiver, _isAbsorbable);

    vm.expectEmit();
    emit DistributeTax(collateralTypeA, receiver, _currentTaxCut);

    taxCollector.distributeTax(collateralTypeA, receiver, _debtAmount, _deltaRate);
  }

  function testFail_ZeroTaxCut(uint256 _debtAmount) public {
    int256 _deltaRate = 0;
    int256 _currentTaxCut = 0;

    vm.expectEmit();
    emit DistributeTax(collateralTypeA, receiver, _currentTaxCut);

    taxCollector.distributeTax(collateralTypeA, receiver, _debtAmount, _deltaRate);
  }

  function testFail_CanNotTakeBackTax(uint256 _debtAmount, int256 _deltaRate) public {
    int256 _currentTaxCut = _assumeCurrentTaxCut(_debtAmount, _deltaRate, false, false);

    _mockSecondaryTaxReceiver(collateralTypeA, receiver, !canTakeBackTax, taxPercentage);

    vm.expectEmit();
    emit DistributeTax(collateralTypeA, receiver, _currentTaxCut);

    taxCollector.distributeTax(collateralTypeA, receiver, _debtAmount, _deltaRate);
  }
}

contract Unit_TaxCollector_ModifyParameters is Base {
  event SetPrimaryReceiver(bytes32 indexed _cType, address indexed _receiver);

  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_Parameters(ITaxCollector.TaxCollectorParams memory _fuzz) public happyPath {
    vm.assume(_fuzz.primaryTaxReceiver != address(0));
    vm.assume(_fuzz.maxStabilityFeeRange > 0 && _fuzz.maxStabilityFeeRange < RAY);
    vm.assume(
      _fuzz.globalStabilityFee >= RAY - _fuzz.maxStabilityFeeRange
        && _fuzz.globalStabilityFee <= RAY + _fuzz.maxStabilityFeeRange
    );

    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(_fuzz.primaryTaxReceiver));
    taxCollector.modifyParameters('globalStabilityFee', abi.encode(_fuzz.globalStabilityFee));
    taxCollector.modifyParameters('maxStabilityFeeRange', abi.encode(_fuzz.maxStabilityFeeRange));
    taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(_fuzz.maxSecondaryReceivers));

    ITaxCollector.TaxCollectorParams memory _params = taxCollector.params();

    assertEq(abi.encode(_params), abi.encode(_fuzz));
  }

  function test_Emit_SetPrimaryReceiver(address _primaryTaxReceiver) public happyPath {
    vm.assume(_primaryTaxReceiver != address(0));

    vm.expectEmit();
    emit SetPrimaryReceiver(bytes32(0), _primaryTaxReceiver);

    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(_primaryTaxReceiver));
  }

  function test_Revert_NullAddress_PrimaryTaxReceiver() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(Assertions.NullAddress.selector);

    taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(0));
  }

  function test_Revert_NotGreaterOrEqualThan_GlobalStabilityFee(uint256 _globalStabilityFee) public {
    vm.startPrank(authorizedAccount);
    vm.assume(_globalStabilityFee < RAY - maxStabilityFeeRange);

    vm.expectRevert(
      abi.encodeWithSelector(Assertions.NotGreaterOrEqualThan.selector, _globalStabilityFee, RAY - maxStabilityFeeRange)
    );

    taxCollector.modifyParameters('globalStabilityFee', abi.encode(_globalStabilityFee));
  }

  function test_Revert_NotLesserOrEqualThan_GlobalStabilityFee(uint256 _globalStabilityFee) public {
    vm.startPrank(authorizedAccount);
    vm.assume(_globalStabilityFee > RAY + maxStabilityFeeRange);

    vm.expectRevert(
      abi.encodeWithSelector(Assertions.NotLesserOrEqualThan.selector, _globalStabilityFee, RAY + maxStabilityFeeRange)
    );

    taxCollector.modifyParameters('globalStabilityFee', abi.encode(_globalStabilityFee));
  }

  function test_Revert_NotGreaterThan_MaxStabilityFeeRange(uint256 _maxStabilityFeeRange) public {
    vm.startPrank(authorizedAccount);
    _maxStabilityFeeRange = 0;

    vm.expectRevert(abi.encodeWithSelector(Assertions.NotGreaterThan.selector, _maxStabilityFeeRange, 0));

    taxCollector.modifyParameters('maxStabilityFeeRange', abi.encode(_maxStabilityFeeRange));
  }

  function test_Revert_NotLesserThan_MaxStabilityFeeRange(uint256 _maxStabilityFeeRange) public {
    vm.startPrank(authorizedAccount);
    vm.assume(_maxStabilityFeeRange >= RAY);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NotLesserThan.selector, _maxStabilityFeeRange, RAY));

    taxCollector.modifyParameters('maxStabilityFeeRange', abi.encode(_maxStabilityFeeRange));
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    taxCollector.modifyParameters('unrecognizedParam', _data);
  }
}

contract Unit_TaxCollector_ModifyParametersPerCollateral is Base {
  modifier happyPath(bytes32 _cType) {
    vm.startPrank(authorizedAccount);

    _mockValues(_cType);
    _;
  }

  function _mockValues(bytes32 _cType) internal {
    _mockCollateralList(_cType);
  }

  function test_Set_StabilityFee(bytes32 _cType, uint256 _stabilityFee) public happyPath(_cType) {
    vm.assume(_stabilityFee > RAY - maxStabilityFeeRange && _stabilityFee < RAY + maxStabilityFeeRange);

    taxCollector.modifyParameters(_cType, 'stabilityFee', abi.encode(_stabilityFee));

    assertEq(taxCollector.cParams(_cType).stabilityFee, _stabilityFee);
  }

  function test_Revert_NotGreaterOrEqualThan_StabilityFee(bytes32 _cType, uint256 _stabilityFee) public {
    vm.startPrank(authorizedAccount);
    _mockCollateralList(_cType);

    vm.assume(_stabilityFee < RAY - maxStabilityFeeRange);

    vm.expectRevert(
      abi.encodeWithSelector(Assertions.NotGreaterOrEqualThan.selector, _stabilityFee, RAY - maxStabilityFeeRange)
    );

    taxCollector.modifyParameters(_cType, 'stabilityFee', abi.encode(_stabilityFee));
  }

  function test_Revert_NotLesserOrEqualThan_StabilityFee(bytes32 _cType, uint256 _stabilityFee) public {
    vm.startPrank(authorizedAccount);
    _mockCollateralList(_cType);

    vm.assume(_stabilityFee > RAY + maxStabilityFeeRange);

    vm.expectRevert(
      abi.encodeWithSelector(Assertions.NotLesserOrEqualThan.selector, _stabilityFee, RAY + maxStabilityFeeRange)
    );

    taxCollector.modifyParameters(_cType, 'stabilityFee', abi.encode(_stabilityFee));
  }

  function test_Revert_UnrecognizedParam(bytes32 _cType, bytes memory _data) public {
    vm.startPrank(authorizedAccount);
    _mockCollateralList(_cType);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    taxCollector.modifyParameters(_cType, 'unrecognizedParam', _data);
  }

  function test_Revert_UnrecognizedCType(bytes32 _cType, bytes32 _param, bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedCType.selector);

    taxCollector.modifyParameters(_cType, _param, _data);
  }
}

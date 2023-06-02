// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Math, RAY, WAD} from '@libraries/Math.sol';
import {StdStorage, stdStorage} from 'forge-std/StdStorage.sol';

import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {OracleRelayer} from '@contracts/OracleRelayer.sol';
import {SAFEEngine} from '@contracts/SAFEEngine.sol';
import {OracleForTest} from '@contracts/for-test/OracleForTest.sol';
import {OracleRelayerForTest, OracleRelayerForInternalCallsTest} from '@contracts/for-test/OracleRelayerForTest.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  IOracleRelayer oracleRelayer;
  SAFEEngineForTest mockSafeEngine;
  OracleForTest mockOracle;
  bytes32 collateralType = 'ETH-A';
  address deployer = label('deployer');

  function setUp() public virtual {
    vm.startPrank(deployer);
    mockSafeEngine = new SAFEEngineForTest();
    oracleRelayer = new OracleRelayerForTest(address(mockSafeEngine));
    mockOracle = new OracleForTest(1 ether);
    vm.stopPrank();
  }

  modifier authorized() {
    vm.startPrank(deployer);
    _;
  }

  function _mockRedemptionRate(uint256 _redemptionRate) internal {
    stdstore.target(address(oracleRelayer)).sig(IOracleRelayer.redemptionRate.selector).checked_write(_redemptionRate);
  }

  function _mockCTypeSafetyCRatio(bytes32 _collateralType, uint256 _safetyCRatio) internal {
    stdstore.target(address(oracleRelayer)).sig(IOracleRelayer.cParams.selector).with_key(_collateralType).depth(1)
      .checked_write(_safetyCRatio);
  }

  function _mockCTypeLiquidationCRatio(bytes32 _collateralType, uint256 _liquidationCRatio) internal {
    stdstore.target(address(oracleRelayer)).sig(IOracleRelayer.cParams.selector).with_key(_collateralType).depth(2)
      .checked_write(_liquidationCRatio);
  }

  function _mockRedemptionPrice(uint256 _redemptionPrice) internal {
    (OracleRelayerForTest(address(oracleRelayer))).setRedemptionPrice(_redemptionPrice);
  }

  function _mockRedemptionPriceUpdateTime(uint256 _redemptionPriceUpdateTime) internal {
    stdstore.target(address(oracleRelayer)).sig(IOracleRelayer.redemptionPriceUpdateTime.selector).checked_write(
      _redemptionPriceUpdateTime
    );
  }

  function _mockRedemptionRateUpperBound(uint256 _redemptionRateUpperBound) internal {
    stdstore.target(address(oracleRelayer)).sig(IOracleRelayer.params.selector).depth(0).checked_write(
      _redemptionRateUpperBound
    );
  }

  function _mockRedemptionRateLowerBound(uint256 _redemptionRateLowerBound) internal {
    stdstore.target(address(oracleRelayer)).sig(IOracleRelayer.params.selector).depth(1).checked_write(
      _redemptionRateLowerBound
    );
  }
}

contract SAFEEngineForTest {
  function updateCollateralPrice(bytes32 _collateralType, uint256 _safetyPrice, uint256 _liquidationPrice) external {}
}

contract Unit_OracleRelayer_Constructor is Base {
  function test_Set_SafeEngine() public {
    assertEq(address(oracleRelayer.safeEngine()), address(mockSafeEngine));
  }

  function test_Set_RedemptionPrice() public {
    assertEq(oracleRelayer.redemptionPrice(), RAY);
  }

  function test_Set_RedemptionRate() public {
    assertEq(oracleRelayer.redemptionRate(), RAY);
  }

  function test_Set_RedemptionPriceUpdateTime() public {
    assertEq(oracleRelayer.redemptionPriceUpdateTime(), block.timestamp);
  }

  function test_Set_RedemptionRateUpperBound() public {
    assertEq(oracleRelayer.params().redemptionRateUpperBound, RAY * WAD);
  }

  function test_Set_RedemptionRateLowerBound() public {
    assertEq(oracleRelayer.params().redemptionRateLowerBound, 1);
  }

  function test_Set_Authorizable() public {
    assertEq(IAuthorizable(address(oracleRelayer)).authorizedAccounts(deployer), 1);
  }
}

contract Unit_OracleRelayer_DisableContract is Base {
  function test_Set_RedemptionRate() public authorized {
    _mockRedemptionRate(0);
    oracleRelayer.disableContract();

    assertEq(oracleRelayer.redemptionRate(), RAY);
  }
}

contract Unit_OracleRelayer_SafetyCRatio is Base {
  function test_Get_SafetyCRatio(bytes32 _collateralType, uint256 _safetyCRatioSet) public {
    _mockCTypeSafetyCRatio(_collateralType, _safetyCRatioSet);

    assertEq(oracleRelayer.cParams(_collateralType).safetyCRatio, _safetyCRatioSet);
  }
}

contract Unit_OracleRelayer_LiquidationCRatio is Base {
  function test_Get_LiquidationCRatio(bytes32 _collateralType, uint256 _liquidationCRatioSet) public {
    _mockCTypeLiquidationCRatio(_collateralType, _liquidationCRatioSet);

    assertEq(oracleRelayer.cParams(_collateralType).liquidationCRatio, _liquidationCRatioSet);
  }
}

contract Unit_OracleRelayer_Orcl is Base {
  function test_Get_Orcl(bytes32 _collateralType, address _oracleSet) public {
    OracleRelayerForTest(address(oracleRelayer)).setCTypeOracle(_collateralType, _oracleSet);

    assertEq(address(oracleRelayer.cParams(_collateralType).oracle), _oracleSet);
  }
}

contract Unit_OracleRelayer_RedemptionPrice is Base {
  event UpdateRedemptionPriceCalled();

  function setUp() public virtual override {
    vm.prank(deployer);
    oracleRelayer = new OracleRelayerForInternalCallsTest(address(mockSafeEngine));
  }

  function test_Get_RedemptionPrice_Call_Internal_UpdateRedemptionPrice(
    uint256 _timestamp,
    uint256 _redemptionPriceUpdateTime
  ) public {
    // The redemption price changes impact will be tested in the _updateRedemptionPrice method unit test
    vm.assume(_timestamp > _redemptionPriceUpdateTime);
    _mockRedemptionPriceUpdateTime(_redemptionPriceUpdateTime);
    vm.warp(_timestamp);

    expectEmitNoIndex();
    emit UpdateRedemptionPriceCalled();

    oracleRelayer.redemptionPrice();
  }

  function testFail_Get_RedemptionPrice_Call_Internal_UpdateRedemptionPrice(
    uint256 _timestamp,
    uint256 _redemptionPriceUpdateTime
  ) public {
    vm.assume(_timestamp <= _redemptionPriceUpdateTime);
    _mockRedemptionPriceUpdateTime(_redemptionPriceUpdateTime);
    vm.warp(_timestamp);

    expectEmitNoIndex();
    emit UpdateRedemptionPriceCalled();

    oracleRelayer.redemptionPrice();
  }

  function test_Get_RedemptionPrice_NoUpdateRedemptionPrice(
    uint256 _redemptionPrice,
    uint256 _timestamp,
    uint256 _redemptionPriceUpdateTime
  ) public {
    vm.assume(_redemptionPrice > 0);
    vm.assume(_timestamp <= _redemptionPriceUpdateTime);
    _mockRedemptionPrice(_redemptionPrice);
    _mockRedemptionPriceUpdateTime(_redemptionPriceUpdateTime);
    vm.warp(_timestamp);

    assertEq(oracleRelayer.redemptionPrice(), _redemptionPrice);
  }
}

contract Unit_OracleRelayer_Internal_UpdateRedemptionPrice is Base {
  using Math for uint256;

  event UpdateRedemptionPrice(uint256 _redemptionPrice);

  function setUp() public virtual override {
    vm.prank(deployer);
    oracleRelayer = new OracleRelayerForTest(address(mockSafeEngine));
  }

  struct UpdateRedemptionPriceScenario {
    uint256 redemptionRate;
    uint256 redemptionPrice;
    uint256 timestamp;
    uint256 redemptionPriceUpdateTime;
  }

  function _assumeHappyPath(UpdateRedemptionPriceScenario memory _scenario) internal view {
    vm.assume(_scenario.timestamp > _scenario.redemptionPriceUpdateTime);
    vm.assume(notOverflowRPow(_scenario.redemptionRate, _scenario.timestamp - _scenario.redemptionPriceUpdateTime));
    uint256 _rpowResult = _scenario.redemptionRate.rpow(_scenario.timestamp - _scenario.redemptionPriceUpdateTime);
    vm.assume(notOverflowMul(_rpowResult, _scenario.redemptionPrice));
  }

  function _mockValues(UpdateRedemptionPriceScenario memory _scenario) internal {
    _mockRedemptionRate(_scenario.redemptionRate);
    _mockRedemptionPrice(_scenario.redemptionPrice);
    _mockRedemptionPriceUpdateTime(_scenario.redemptionPriceUpdateTime);
    vm.warp(_scenario.timestamp);
  }

  modifier happyPath(UpdateRedemptionPriceScenario memory _scenario) {
    _assumeHappyPath(_scenario);
    _mockValues(_scenario);
    _;
  }

  function test_Set_RedemptionPriceUpdateTime(UpdateRedemptionPriceScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    OracleRelayerForTest(address(oracleRelayer)).callUpdateRedemptionPrice();

    assertEq(oracleRelayer.redemptionPriceUpdateTime(), block.timestamp);
  }

  function test_Set_RedemptionPrice(UpdateRedemptionPriceScenario memory _scenario) public happyPath(_scenario) {
    uint256 _updatedPrice = _scenario.redemptionRate.rpow(_scenario.timestamp - _scenario.redemptionPriceUpdateTime)
      .rmul(_scenario.redemptionPrice);
    _updatedPrice = _updatedPrice == 0 ? 1 : _updatedPrice;

    uint256 _redemptionPrice = OracleRelayerForTest(address(oracleRelayer)).callUpdateRedemptionPrice();

    assertEq(_redemptionPrice, _updatedPrice);
  }

  function test_Emit_UpdateRedemptionPrice(UpdateRedemptionPriceScenario memory _scenario) public happyPath(_scenario) {
    uint256 _updatedPrice = _scenario.redemptionRate.rpow(_scenario.timestamp - _scenario.redemptionPriceUpdateTime)
      .rmul(_scenario.redemptionPrice);
    _updatedPrice = _updatedPrice == 0 ? 1 : _updatedPrice;

    expectEmitNoIndex();

    emit UpdateRedemptionPrice(_updatedPrice);

    OracleRelayerForTest(address(oracleRelayer)).callUpdateRedemptionPrice();
  }
}

contract Unit_OracleRelayer_UpdateCollateralPrice is Base {
  using Math for uint256;

  event GetRedemptionPriceCalled();
  event UpdateCollateralPrice(
    bytes32 indexed _collateralType, uint256 _priceFeedValueValue, uint256 _safetyPrice, uint256 _liquidationPrice
  );

  struct UpdateCollateralPriceScenario {
    uint256 priceFeedValue;
    uint256 safetyCRatio;
    uint256 liquidationCRatio;
    uint256 redemptionRate;
    uint256 redemptionPrice;
    uint256 timestamp;
    uint256 redemptionPriceUpdateTime;
  }

  function setUp() public virtual override {
    super.setUp();
    OracleRelayerForTest(address(oracleRelayer)).setCTypeOracle(collateralType, address(mockOracle));
  }

  function _assumeHappyPathValidatyWithoutUpdateRedemptionPrice(UpdateCollateralPriceScenario memory _scenario)
    internal
    pure
  {
    vm.assume(_scenario.timestamp <= _scenario.redemptionPriceUpdateTime);
    vm.assume(_scenario.redemptionPrice > 0);
    vm.assume(_scenario.safetyCRatio > 0);
    vm.assume(_scenario.liquidationCRatio > 0);
    vm.assume(notOverflowMul(_scenario.priceFeedValue, 10 ** 9));
    vm.assume(notOverflowMul(_scenario.priceFeedValue * 10 ** 9, RAY));
    vm.assume(notOverflowMul((_scenario.priceFeedValue * 10 ** 9).rdiv(_scenario.redemptionPrice), RAY));
  }

  function _assumeHappyPathValidatyWithUpdateRedemptionPrice(UpdateCollateralPriceScenario memory _scenario)
    internal
    view
  {
    vm.assume(_scenario.timestamp > _scenario.redemptionPriceUpdateTime);
    vm.assume(_scenario.redemptionPrice > 0);
    vm.assume(_scenario.safetyCRatio > 0);
    vm.assume(_scenario.liquidationCRatio > 0);

    vm.assume(notOverflowRPow(_scenario.redemptionRate, _scenario.timestamp - _scenario.redemptionPriceUpdateTime));
    uint256 _rpowResult = _scenario.redemptionRate.rpow(_scenario.timestamp - _scenario.redemptionPriceUpdateTime);
    vm.assume(notOverflowMul(_rpowResult, _scenario.redemptionPrice));

    uint256 _updatedRedemptionPrice = _scenario.redemptionRate.rpow(
      _scenario.timestamp - _scenario.redemptionPriceUpdateTime
    ).rmul(_scenario.redemptionPrice);
    _updatedRedemptionPrice = _updatedRedemptionPrice == 0 ? 1 : _updatedRedemptionPrice;

    vm.assume(notOverflowMul(_scenario.priceFeedValue, 10 ** 9));
    vm.assume(notOverflowMul(_scenario.priceFeedValue * 10 ** 9, RAY));
    vm.assume(notOverflowMul((_scenario.priceFeedValue * 10 ** 9).rdiv(_updatedRedemptionPrice), RAY));
  }

  function _mockValues(UpdateCollateralPriceScenario memory _scenario, bool _validity) internal {
    _mockRedemptionRate(_scenario.redemptionRate);
    _mockRedemptionPrice(_scenario.redemptionPrice);
    _mockRedemptionPriceUpdateTime(_scenario.redemptionPriceUpdateTime);
    _mockCTypeSafetyCRatio(collateralType, _scenario.safetyCRatio);
    _mockCTypeLiquidationCRatio(collateralType, _scenario.liquidationCRatio);

    mockOracle.setPriceAndValidity(_scenario.priceFeedValue, _validity);
    vm.warp(_scenario.timestamp);
  }

  modifier happyPathValidityNoUpdate(UpdateCollateralPriceScenario memory _scenario) {
    _assumeHappyPathValidatyWithoutUpdateRedemptionPrice(_scenario);
    _mockValues(_scenario, true);
    _;
  }

  modifier happyPathValidityWithUpdate(UpdateCollateralPriceScenario memory _scenario) {
    _assumeHappyPathValidatyWithUpdateRedemptionPrice(_scenario);
    _mockValues(_scenario, true);
    _;
  }

  modifier happyPathNoValidity(UpdateCollateralPriceScenario memory _scenario) {
    _assumeHappyPathValidatyWithUpdateRedemptionPrice(_scenario);
    _mockValues(_scenario, false);
    _;
  }

  function _getSafeEngineNewParameters(
    UpdateCollateralPriceScenario memory _scenario,
    bool _updateRedemptionPrice
  ) internal pure returns (uint256 _safetyPrice, uint256 _liquidationPrice) {
    uint256 _redemptionPrice = _scenario.redemptionPrice;

    if (_updateRedemptionPrice) {
      _redemptionPrice = _scenario.redemptionRate.rpow(_scenario.timestamp - _scenario.redemptionPriceUpdateTime).rmul(
        _scenario.redemptionPrice
      );
      _redemptionPrice = _redemptionPrice == 0 ? 1 : _redemptionPrice;
    }

    _safetyPrice =
      (uint256(_scenario.priceFeedValue) * uint256(10 ** 9)).rdiv(_redemptionPrice).rdiv(_scenario.safetyCRatio);

    _liquidationPrice =
      (uint256(_scenario.priceFeedValue) * uint256(10 ** 9)).rdiv(_redemptionPrice).rdiv(_scenario.liquidationCRatio);
  }

  function test_Call_Orcl_GetResultWithValidity_ValidityNoPriceUpdate(UpdateCollateralPriceScenario memory _scenario)
    public
    happyPathValidityNoUpdate(_scenario)
  {
    vm.expectCall(address(mockOracle), abi.encodeWithSelector(IBaseOracle.getResultWithValidity.selector));

    oracleRelayer.updateCollateralPrice(collateralType);
  }

  function test_Call_Orcl_GetResultWithValidity_ValidityWithPriceUpdate(UpdateCollateralPriceScenario memory _scenario)
    public
    happyPathValidityWithUpdate(_scenario)
  {
    vm.expectCall(address(mockOracle), abi.encodeWithSelector(IBaseOracle.getResultWithValidity.selector));

    oracleRelayer.updateCollateralPrice(collateralType);
  }

  function test_Call_Internal_GetRedemptionPrice_ValidityNoPriceUpdate(UpdateCollateralPriceScenario memory _scenario)
    public
    happyPathValidityNoUpdate(_scenario)
  {
    oracleRelayer = new OracleRelayerForInternalCallsTest(address(mockSafeEngine));
    OracleRelayerForInternalCallsTest(address(oracleRelayer)).setCTypeOracle(collateralType, address(mockOracle));

    _assumeHappyPathValidatyWithoutUpdateRedemptionPrice(_scenario);
    _mockValues(_scenario, true);

    expectEmitNoIndex();
    emit GetRedemptionPriceCalled();

    oracleRelayer.updateCollateralPrice(collateralType);
  }

  function test_Call_Internal_GetRedemptionPrice_ValidityWithPriceUpdate(UpdateCollateralPriceScenario memory _scenario)
    public
  {
    oracleRelayer = new OracleRelayerForInternalCallsTest(address(mockSafeEngine));
    OracleRelayerForInternalCallsTest(address(oracleRelayer)).setCTypeOracle(collateralType, address(mockOracle));

    _assumeHappyPathValidatyWithUpdateRedemptionPrice(_scenario);
    _mockValues(_scenario, true);

    expectEmitNoIndex();
    emit GetRedemptionPriceCalled();

    oracleRelayer.updateCollateralPrice(collateralType);
  }

  function test_Call_SafeEngine_UpdateCollateralPrice(UpdateCollateralPriceScenario memory _scenario)
    public
    happyPathValidityNoUpdate(_scenario)
  {
    (uint256 _safetyPrice, uint256 _liquidationPrice) = _getSafeEngineNewParameters(_scenario, false);

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(ISAFEEngine.updateCollateralPrice, (collateralType, _safetyPrice, _liquidationPrice))
    );

    oracleRelayer.updateCollateralPrice(collateralType);
  }

  function test_Call_SafeEngine_UpdateCollateralPrice_WithPriceUpdate(UpdateCollateralPriceScenario memory _scenario)
    public
    happyPathValidityWithUpdate(_scenario)
  {
    (uint256 _safetyPrice, uint256 _liquidationPrice) = _getSafeEngineNewParameters(_scenario, true);

    vm.expectCall(
      address(mockSafeEngine),
      abi.encodeCall(ISAFEEngine.updateCollateralPrice, (collateralType, _safetyPrice, _liquidationPrice))
    );

    oracleRelayer.updateCollateralPrice(collateralType);
  }

  function test_Call_SafeEngine_UpdateCollateralPrice_NoValidity(UpdateCollateralPriceScenario memory _scenario)
    public
    happyPathNoValidity(_scenario)
  {
    vm.expectCall(address(mockSafeEngine), abi.encodeCall(ISAFEEngine.updateCollateralPrice, (collateralType, 0, 0)));

    oracleRelayer.updateCollateralPrice(collateralType);
  }

  function test_Emit_UpdateCollateralPrice(UpdateCollateralPriceScenario memory _scenario)
    public
    happyPathValidityNoUpdate(_scenario)
  {
    (uint256 _safetyPrice, uint256 _liquidationPrice) = _getSafeEngineNewParameters(_scenario, false);

    vm.expectEmit(true, true, false, false);
    emit UpdateCollateralPrice(collateralType, _scenario.priceFeedValue, _safetyPrice, _liquidationPrice);

    oracleRelayer.updateCollateralPrice(collateralType);
  }

  function test_Emit_UpdateCollateralPrice_WithUpdate(UpdateCollateralPriceScenario memory _scenario)
    public
    happyPathValidityWithUpdate(_scenario)
  {
    (uint256 _safetyPrice, uint256 _liquidationPrice) = _getSafeEngineNewParameters(_scenario, true);

    vm.expectEmit(true, true, false, false);
    emit UpdateCollateralPrice(collateralType, _scenario.priceFeedValue, _safetyPrice, _liquidationPrice);

    oracleRelayer.updateCollateralPrice(collateralType);
  }

  function test_Emit_UpdateCollateralPrice_NoValidity(UpdateCollateralPriceScenario memory _scenario)
    public
    happyPathNoValidity(_scenario)
  {
    vm.expectEmit(true, true, false, false);
    emit UpdateCollateralPrice(collateralType, _scenario.priceFeedValue, 0, 0);

    oracleRelayer.updateCollateralPrice(collateralType);
  }
}

contract Unit_OracleRelayer_UpdateRedemptionRate is Base {
  using Math for uint256;

  function _mockValues(uint256 _redemptionRateUpperBound, uint256 _redemptionRateLowerBound) internal {
    _mockRedemptionRateUpperBound(_redemptionRateUpperBound);
    _mockRedemptionRateLowerBound(_redemptionRateLowerBound);
  }

  modifier happyPath(uint256 _redemptionRate, uint256 _redemptionRateUpperBound, uint256 _redemptionRateLowerBound) {
    _mockRedemptionPriceUpdateTime(block.timestamp);
    vm.assume(_redemptionRateLowerBound <= _redemptionRateUpperBound);
    _mockValues(_redemptionRateUpperBound, _redemptionRateLowerBound);
    _;
  }

  function test_Set_RedemptionRate(
    uint256 _redemptionRate,
    uint256 _redemptionRateUpperBound,
    uint256 _redemptionRateLowerBound
  ) public authorized happyPath(_redemptionRate, _redemptionRateUpperBound, _redemptionRateLowerBound) {
    vm.assume(_redemptionRate <= _redemptionRateUpperBound);
    vm.assume(_redemptionRate >= _redemptionRateLowerBound);

    oracleRelayer.updateRedemptionRate(_redemptionRate);

    assertEq(oracleRelayer.redemptionRate(), _redemptionRate);
  }

  function test_Set_RedemptionRateUpperBound(
    uint256 _redemptionRate,
    uint256 _redemptionRateUpperBound,
    uint256 _redemptionRateLowerBound
  ) public authorized happyPath(_redemptionRate, _redemptionRateUpperBound, _redemptionRateLowerBound) {
    vm.assume(_redemptionRate > _redemptionRateUpperBound);

    oracleRelayer.updateRedemptionRate(_redemptionRate);

    assertEq(oracleRelayer.redemptionRate(), _redemptionRateUpperBound);
  }

  function test_Set_RedemptionRateLowerBound(
    uint256 _redemptionRate,
    uint256 _redemptionRateUpperBound,
    uint256 _redemptionRateLowerBound
  ) public authorized happyPath(_redemptionRate, _redemptionRateUpperBound, _redemptionRateLowerBound) {
    vm.assume(_redemptionRate < _redemptionRateLowerBound);

    oracleRelayer.updateRedemptionRate(_redemptionRate);

    assertEq(oracleRelayer.redemptionRate(), _redemptionRateLowerBound);
  }

  function test_Revert_WithoutUpdateRedemptionPrice(
    uint256 _timeSinceLastRedemptionPriceUpdate,
    uint256 _redemptionRate,
    uint256 _redemptionRateUpperBound,
    uint256 _redemptionRateLowerBound
  ) public authorized happyPath(_redemptionRate, _redemptionRateUpperBound, _redemptionRateLowerBound) {
    vm.assume(notUnderflow(block.timestamp, _timeSinceLastRedemptionPriceUpdate));
    vm.assume(_timeSinceLastRedemptionPriceUpdate > 0);
    vm.warp(block.timestamp + _timeSinceLastRedemptionPriceUpdate);

    vm.expectRevert(IOracleRelayer.RedemptionPriceNotUpdated.selector);

    oracleRelayer.updateRedemptionRate(_redemptionRate);
  }
}

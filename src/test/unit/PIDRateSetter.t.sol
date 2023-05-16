// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Math, RAY} from '@libraries/Math.sol';
import {IOracle} from '@interfaces/IOracle.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IPIDController} from '@interfaces/IPIDController.sol';
import {IPIDRateSetter} from '@interfaces/IPIDRateSetter.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

import {PIDRateSetter} from '@contracts/PIDRateSetter.sol';

import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = address(deployer);
  uint256 periodSize = 3600;
  IPIDRateSetter pidRateSetter;
  IOracleRelayer mockOracleRelayer = IOracleRelayer(mockContract('mockOracleRelayer'));
  IOracle mockOracle = IOracle(mockContract('mockOracle'));
  IPIDController mockPIDController = IPIDController(mockContract('mockPIDController'));

  function _createDefaulPIDRateSetter() internal returns (PIDRateSetter _pidRateSetter) {
    vm.prank(deployer);
    _pidRateSetter =
      new PIDRateSetter(address(mockOracleRelayer), address(mockOracle), address(mockPIDController), periodSize);
  }

  function setUp() public virtual {
    pidRateSetter = _createDefaulPIDRateSetter();
  }

  function _mockOrclGetResultWithValidity(uint256 _result, bool _valid) internal {
    vm.mockCall(
      address(mockOracle), abi.encodeWithSelector(IOracle.getResultWithValidity.selector), abi.encode(_result, _valid)
    );
  }

  function _mockOracleRelayerRedemptionPrice(uint256 _redemptionPrice) internal {
    vm.mockCall(
      address(mockOracleRelayer),
      abi.encodeWithSelector(IOracleRelayer.redemptionPrice.selector),
      abi.encode(_redemptionPrice)
    );
  }

  function _mockOracleRelayerUpdateRedemptionRate() internal {
    vm.mockCall(
      address(mockOracleRelayer), abi.encodeWithSelector(IOracleRelayer.updateRedemptionRate.selector), abi.encode()
    );
  }

  function _mockPIDControllerPsl(uint256 _pscl) internal {
    vm.mockCall(address(mockPIDController), abi.encodeWithSelector(IPIDController.pscl.selector), abi.encode(_pscl));
  }

  function _mockPIDControllertlv(uint256 _tlv) internal {
    vm.mockCall(address(mockPIDController), abi.encodeWithSelector(IPIDController.tlv.selector), abi.encode(_tlv));
  }

  function _mockDefaultLeak(uint256 _defaultLeak) internal {
    stdstore.target(address(pidRateSetter)).sig(IPIDRateSetter.defaultLeak.selector).checked_write(_defaultLeak);
  }

  function _mockLastUpdateTime(uint256 _lastUpdateTime) internal {
    stdstore.target(address(pidRateSetter)).sig(IPIDRateSetter.lastUpdateTime.selector).checked_write(_lastUpdateTime);
  }

  function _mockUpdateRateDelay(uint256 _updateRateDelay) internal {
    stdstore.target(address(pidRateSetter)).sig(IPIDRateSetter.updateRateDelay.selector).checked_write(_updateRateDelay);
  }

  function _mockPIDControllerComputeRate(
    uint256 _marketPrice,
    uint256 _redemptionPrice,
    uint256 _accumulatedLeak,
    uint256 _computedRate
  ) internal {
    vm.mockCall(
      address(mockPIDController),
      abi.encodeWithSelector(IPIDController.computeRate.selector, _marketPrice, _redemptionPrice, _accumulatedLeak),
      abi.encode(_computedRate)
    );
  }
}

contract Unit_PIDRateSetter_Constructor is Base {
  event ModifyParameters(bytes32 _parameter, address _addr);
  event ModifyParameters(bytes32 _parameter, uint256 _val);

  function test_Set_OracleRelayer() public {
    assertEq(address(pidRateSetter.oracleRelayer()), address(mockOracleRelayer));
  }

  function test_Set_Oracle() public {
    assertEq(address(pidRateSetter.orcl()), address(mockOracle));
  }

  function test_Set_PIDCalculator() public {
    assertEq(address(pidRateSetter.pidCalculator()), address(mockPIDController));
  }

  function test_Set_UpdateRateDelay() public {
    assertEq(pidRateSetter.updateRateDelay(), periodSize);
  }

  function test_Set_DefaultLeak() public {
    assertEq(pidRateSetter.defaultLeak(), 1);
  }

  function test_Set_AuthorizedAccounts() public {
    assertEq(pidRateSetter.authorizedAccounts(deployer), 1);
  }

  function test_Emit_ModifyParameters_OracleRelayer() public {
    expectEmitNoIndex();
    emit ModifyParameters('oracleRelayer', address(mockOracleRelayer));

    _createDefaulPIDRateSetter();
  }

  function test_Emit_ModifyParameters_Oracle() public {
    expectEmitNoIndex();
    emit ModifyParameters('orcl', address(mockOracle));

    _createDefaulPIDRateSetter();
  }

  function test_Emit_ModifyParameters_PIDController() public {
    expectEmitNoIndex();
    emit ModifyParameters('pidCalculator', address(mockPIDController));

    _createDefaulPIDRateSetter();
  }

  function test_Emit_ModifyParameters_UpdateRateDelay() public {
    expectEmitNoIndex();
    emit ModifyParameters('updateRateDelay', periodSize);

    _createDefaulPIDRateSetter();
  }

  function test_Revert_NullOracleRelayerAddress() public {
    vm.expectRevert('PIDRateSetter/null-oracle-relayer');
    new PIDRateSetter(address(0), address(mockOracle), address(mockPIDController), periodSize);
  }

  function test_Revert_NullOrcl() public {
    vm.expectRevert('PIDRateSetter/null-orcl');
    new PIDRateSetter(address(mockOracleRelayer), address(0), address(mockPIDController), periodSize);
  }

  function test_Revert_NullCalculator() public {
    vm.expectRevert('PIDRateSetter/null-calculator');
    new PIDRateSetter(address(mockOracleRelayer), address(mockOracle), address(0), periodSize);
  }
}

contract Unit_PIDRateSetter_GetMarketPrice is Base {
  function test_Call_Orcl_GetResultWithValidity(uint256 _result) public {
    _mockOrclGetResultWithValidity(_result, true);

    vm.expectCall(address(mockOracle), abi.encodeWithSelector(IOracle.getResultWithValidity.selector));
    pidRateSetter.getMarketPrice();
  }

  function test_Return_Orcl_Result(uint256 _result) public {
    _mockOrclGetResultWithValidity(_result, true);

    assertEq(pidRateSetter.getMarketPrice(), _result);
  }
}

contract Unit_PIDRateSetter_GetRedemptionAndMarketPrices is Base {
  function test_Call_Orcl_GetResultWithValidity(uint256 _result, uint256 _redemptionPrice) public {
    _mockOrclGetResultWithValidity(_result, true);
    _mockOracleRelayerRedemptionPrice(_redemptionPrice);

    vm.expectCall(address(mockOracle), abi.encodeWithSelector(IOracle.getResultWithValidity.selector));
    pidRateSetter.getRedemptionAndMarketPrices();
  }

  function test_Call_OracleRelayer_RedemptionPrice(uint256 _result, uint256 _redemptionPrice) public {
    _mockOrclGetResultWithValidity(_result, true);
    _mockOracleRelayerRedemptionPrice(_redemptionPrice);

    vm.expectCall(address(mockOracleRelayer), abi.encodeWithSelector(IOracleRelayer.redemptionPrice.selector));
    pidRateSetter.getRedemptionAndMarketPrices();
  }

  function test_Return_Orcl_Result(uint256 _result, uint256 _redemptionPrice) public {
    _mockOrclGetResultWithValidity(_result, true);
    _mockOracleRelayerRedemptionPrice(_redemptionPrice);

    (uint256 _marketPrice,) = pidRateSetter.getRedemptionAndMarketPrices();
    assertEq(_marketPrice, _result);
  }

  function test_Return_OracleRelayer_RedemptionPrice(uint256 _result, uint256 _redemptionPrc) public {
    _mockOrclGetResultWithValidity(_result, true);
    _mockOracleRelayerRedemptionPrice(_redemptionPrc);

    (, uint256 _redemptionPrice) = pidRateSetter.getRedemptionAndMarketPrices();
    assertEq(_redemptionPrice, _redemptionPrc);
  }
}

contract Unit_PIDRateSetter_UpdateRate is Base {
  using Math for uint256;

  struct UpdateRateScenario {
    uint256 marketPrice;
    uint256 redemptionPrice;
    uint256 pscl;
    uint256 tlv;
    uint256 computedRate;
  }

  function _updateRateDelayPassed(
    uint256 _timestamp,
    uint256 _lastUpdateTime,
    uint256 _updateRateDelay
  ) internal pure returns (bool) {
    vm.assume(_timestamp >= _lastUpdateTime);
    return _timestamp - _lastUpdateTime >= _updateRateDelay;
  }

  modifier happyPathDefaultLeakIsOne(UpdateRateScenario memory _scenario) {
    vm.assume(_scenario.marketPrice > 0);
    _mockValues(_scenario, 1, RAY);
    _;
  }

  modifier happyPathDefaultLeakIsZero(UpdateRateScenario memory _scenario) {
    vm.assume(notOverflowRPow(_scenario.pscl, _scenario.tlv));
    vm.assume(_scenario.marketPrice > 0);
    uint256 _iapcr = _scenario.pscl.rpow(_scenario.tlv);
    _mockValues(_scenario, 0, _iapcr);
    _;
  }

  function _mockValues(UpdateRateScenario memory _scenario, uint256 _defaultLeak, uint256 _iapcr) internal {
    _mockOrclGetResultWithValidity(_scenario.marketPrice, true);
    _mockOracleRelayerRedemptionPrice(_scenario.redemptionPrice);
    _mockOracleRelayerUpdateRedemptionRate();
    _mockPIDControllerPsl(_scenario.pscl);
    _mockPIDControllertlv(_scenario.tlv);
    _mockDefaultLeak(_defaultLeak);
    _mockPIDControllerComputeRate(_scenario.marketPrice, _scenario.redemptionPrice, _iapcr, _scenario.computedRate);
  }

  function test_Set_LastUpdateTime(UpdateRateScenario memory _scenario) public happyPathDefaultLeakIsOne(_scenario) {
    pidRateSetter.updateRate();

    assertEq(pidRateSetter.lastUpdateTime(), block.timestamp);
  }

  function test_Set_LastUpdateTime_DefaultLeakIsZero(UpdateRateScenario memory _scenario)
    public
    happyPathDefaultLeakIsZero(_scenario)
  {
    pidRateSetter.updateRate();

    assertEq(pidRateSetter.lastUpdateTime(), block.timestamp);
  }

  function test_Call_Orcl_GetResultWithValidity(UpdateRateScenario memory _scenario)
    public
    happyPathDefaultLeakIsOne(_scenario)
  {
    vm.expectCall(address(mockOracle), abi.encodeWithSelector(IOracle.getResultWithValidity.selector));

    pidRateSetter.updateRate();
  }

  function test_Call_Orcl_GetResultWithValidity_DefaultLeakIsZero(UpdateRateScenario memory _scenario)
    public
    happyPathDefaultLeakIsZero(_scenario)
  {
    vm.expectCall(address(mockOracle), abi.encodeWithSelector(IOracle.getResultWithValidity.selector));

    pidRateSetter.updateRate();
  }

  function test_Call_OracleRelayer_GetRedemptionPrice(UpdateRateScenario memory _scenario)
    public
    happyPathDefaultLeakIsOne(_scenario)
  {
    vm.expectCall(address(mockOracleRelayer), abi.encodeWithSelector(IOracleRelayer.redemptionPrice.selector));

    pidRateSetter.updateRate();
  }

  function test_Call_OracleRelayer_GetRedemptionPrice_DefaultLeakIsZero(UpdateRateScenario memory _scenario)
    public
    happyPathDefaultLeakIsZero(_scenario)
  {
    vm.expectCall(address(mockOracleRelayer), abi.encodeWithSelector(IOracleRelayer.redemptionPrice.selector));

    pidRateSetter.updateRate();
  }

  function test_Call_PIDController_ComputeRate(UpdateRateScenario memory _scenario)
    public
    happyPathDefaultLeakIsOne(_scenario)
  {
    vm.expectCall(
      address(mockPIDController),
      abi.encodeWithSelector(IPIDController.computeRate.selector, _scenario.marketPrice, _scenario.redemptionPrice, RAY)
    );

    pidRateSetter.updateRate();
  }

  function test_Call_PIDController_ComputeRate_DefaultLeakIsZero(UpdateRateScenario memory _scenario)
    public
    happyPathDefaultLeakIsZero(_scenario)
  {
    uint256 _iapcr = _scenario.pscl.rpow(_scenario.tlv);

    vm.expectCall(
      address(mockPIDController),
      abi.encodeWithSelector(
        IPIDController.computeRate.selector, _scenario.marketPrice, _scenario.redemptionPrice, _iapcr
      )
    );

    pidRateSetter.updateRate();
  }

  function test_Call_OracleRelayer_ModifyParameters(UpdateRateScenario memory _scenario)
    public
    happyPathDefaultLeakIsOne(_scenario)
  {
    vm.expectCall(
      address(mockOracleRelayer), abi.encodeCall(IOracleRelayer.updateRedemptionRate, (_scenario.computedRate))
    );

    pidRateSetter.updateRate();
  }

  function test_Call_OracleRelayer_ModifyParameters_DefaultLeakIsZero(UpdateRateScenario memory _scenario)
    public
    happyPathDefaultLeakIsZero(_scenario)
  {
    vm.expectCall(
      address(mockOracleRelayer), abi.encodeCall(IOracleRelayer.updateRedemptionRate, (_scenario.computedRate))
    );

    pidRateSetter.updateRate();
  }

  function test_Revert_WaitMore(uint256 _timeStamp, uint256 _lastUpdateTime, uint256 _updateRateDelay) public {
    vm.assume(!_updateRateDelayPassed(_timeStamp, _lastUpdateTime, _updateRateDelay));
    vm.warp(_timeStamp);
    _mockLastUpdateTime(_lastUpdateTime);
    _mockUpdateRateDelay(_updateRateDelay);

    vm.expectRevert(bytes('PIDRateSetter/wait-more'));

    pidRateSetter.updateRate();
  }

  function test_Revert_InvalidOracleValue(UpdateRateScenario memory _scenario) public {
    _mockOrclGetResultWithValidity(_scenario.marketPrice, false);

    vm.expectRevert(bytes('PIDRateSetter/invalid-oracle-value'));

    pidRateSetter.updateRate();
  }

  function test_Revert_NullPrice(UpdateRateScenario memory _scenario) public {
    _scenario.marketPrice = 0;

    _mockValues(_scenario, 1, RAY);

    vm.expectRevert(bytes('PIDRateSetter/null-price'));

    pidRateSetter.updateRate();
  }
}

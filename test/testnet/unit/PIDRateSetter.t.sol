// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IPIDController} from '@interfaces/IPIDController.sol';
import {IPIDRateSetter} from '@interfaces/IPIDRateSetter.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

import {PIDRateSetter} from '@contracts/PIDRateSetter.sol';

import {HaiTest, stdStorage, StdStorage} from '@testnet/utils/HaiTest.t.sol';

import {Math, RAY} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  uint256 periodSize = 3600;
  IPIDRateSetter pidRateSetter;
  IOracleRelayer mockOracleRelayer = IOracleRelayer(mockContract('mockOracleRelayer'));
  IBaseOracle mockOracle = IBaseOracle(mockContract('mockOracle'));
  IPIDController mockPIDController = IPIDController(mockContract('mockPIDController'));

  function _createDefaulPIDRateSetter() internal returns (PIDRateSetter _pidRateSetter) {
    vm.prank(deployer);
    _pidRateSetter = new PIDRateSetter(
      address(mockOracleRelayer), address(mockPIDController), IPIDRateSetter.PIDRateSetterParams(periodSize)
    );
  }

  function setUp() public virtual {
    pidRateSetter = _createDefaulPIDRateSetter();
  }

  modifier authorized() {
    vm.startPrank(deployer);
    _;
  }

  function _mockOracleRelayerMarketPrice(uint256 _result) internal {
    vm.mockCall(
      address(mockOracleRelayer), abi.encodeWithSelector(IOracleRelayer.marketPrice.selector), abi.encode(_result)
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

  function _mockLastUpdateTime(uint256 _lastUpdateTime) internal {
    stdstore.target(address(pidRateSetter)).sig(IPIDRateSetter.lastUpdateTime.selector).checked_write(_lastUpdateTime);
  }

  function _mockUpdateRateDelay(uint256 _updateRateDelay) internal {
    stdstore.target(address(pidRateSetter)).sig(IPIDRateSetter.params.selector).depth(0).checked_write(_updateRateDelay);
  }

  function _mockPIDControllerComputeRate(
    uint256 _marketPrice,
    uint256 _redemptionPrice,
    uint256 _computedRate
  ) internal {
    vm.mockCall(
      address(mockPIDController),
      abi.encodeWithSelector(IPIDController.computeRate.selector, _marketPrice, _redemptionPrice),
      abi.encode(_computedRate)
    );
  }
}

contract Unit_PIDRateSetter_Constructor is Base {
  function test_Set_OracleRelayer() public {
    assertEq(address(pidRateSetter.oracleRelayer()), address(mockOracleRelayer));
  }

  function test_Set_PIDCalculator() public {
    assertEq(address(pidRateSetter.pidCalculator()), address(mockPIDController));
  }

  function test_Set_UpdateRateDelay() public {
    assertEq(pidRateSetter.params().updateRateDelay, periodSize);
  }

  function test_Set_AuthorizedAccounts() public {
    assertEq(pidRateSetter.authorizedAccounts(deployer), true);
  }

  function test_Revert_NullOracleRelayerAddress() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));
    new PIDRateSetter(address(0), address(mockPIDController), IPIDRateSetter.PIDRateSetterParams(periodSize));
  }

  function test_Revert_NullCalculator() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));
    new PIDRateSetter(address(mockOracleRelayer), address(0), IPIDRateSetter.PIDRateSetterParams(periodSize));
  }
}

contract Unit_PIDRateSetter_ModifyParameters is Base {
  function test_ModifyParameters(IPIDRateSetter.PIDRateSetterParams memory _fuzz) public authorized {
    vm.assume(_fuzz.updateRateDelay > 0);
    pidRateSetter.modifyParameters('updateRateDelay', abi.encode(_fuzz.updateRateDelay));

    IPIDRateSetter.PIDRateSetterParams memory _params = pidRateSetter.params();

    assertEq(abi.encode(_fuzz), abi.encode(_params));
  }

  function test_ModifyParameters_Set_OracleRelayer(address _oracleRelayer)
    public
    authorized
    mockAsContract(_oracleRelayer)
  {
    pidRateSetter.modifyParameters('oracleRelayer', abi.encode(_oracleRelayer));

    assertEq(address(pidRateSetter.oracleRelayer()), _oracleRelayer);
  }

  function test_ModifyParameters_Set_PIDCalculator(address _pidCalculator)
    public
    authorized
    mockAsContract(_pidCalculator)
  {
    pidRateSetter.modifyParameters('pidCalculator', abi.encode(_pidCalculator));

    assertEq(address(pidRateSetter.pidCalculator()), _pidCalculator);
  }

  function test_Revert_ModifyParameters_UpdateRateDelayIs0() public authorized {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NotGreaterThan.selector, 0, 0));

    pidRateSetter.modifyParameters('updateRateDelay', abi.encode(0));
  }
}

contract Unit_PIDRateSetter_UpdateRate is Base {
  using Math for uint256;

  struct UpdateRateScenario {
    uint256 marketPrice;
    uint256 redemptionPrice;
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

  modifier happyPath(UpdateRateScenario memory _scenario) {
    vm.assume(_scenario.marketPrice > 0);
    _mockValues(_scenario);
    _;
  }

  function _mockValues(UpdateRateScenario memory _scenario) internal {
    _mockOracleRelayerMarketPrice(_scenario.marketPrice);
    _mockOracleRelayerRedemptionPrice(_scenario.redemptionPrice);
    _mockOracleRelayerUpdateRedemptionRate();
    _mockPIDControllerComputeRate(_scenario.marketPrice, _scenario.redemptionPrice, _scenario.computedRate);
  }

  function test_Set_LastUpdateTime(UpdateRateScenario memory _scenario) public happyPath(_scenario) {
    pidRateSetter.updateRate();

    assertEq(pidRateSetter.lastUpdateTime(), block.timestamp);
  }

  function test_Call_OracleRelayer_MarketPrice(UpdateRateScenario memory _scenario) public happyPath(_scenario) {
    vm.expectCall(address(mockOracleRelayer), abi.encodeWithSelector(IOracleRelayer.marketPrice.selector));

    pidRateSetter.updateRate();
  }

  function test_Call_OracleRelayer_GetRedemptionPrice(UpdateRateScenario memory _scenario) public happyPath(_scenario) {
    vm.expectCall(address(mockOracleRelayer), abi.encodeWithSelector(IOracleRelayer.redemptionPrice.selector));

    pidRateSetter.updateRate();
  }

  function test_Call_PIDController_ComputeRate(UpdateRateScenario memory _scenario) public happyPath(_scenario) {
    vm.expectCall(
      address(mockPIDController),
      abi.encodeWithSelector(IPIDController.computeRate.selector, _scenario.marketPrice, _scenario.redemptionPrice)
    );

    pidRateSetter.updateRate();
  }

  function test_Call_OracleRelayer_UpdateRate(UpdateRateScenario memory _scenario) public happyPath(_scenario) {
    vm.expectCall(
      address(mockOracleRelayer), abi.encodeCall(IOracleRelayer.updateRedemptionRate, (_scenario.computedRate))
    );

    pidRateSetter.updateRate();
  }

  function test_Revert_RateSetterCooldown(uint256 _timeStamp, uint256 _lastUpdateTime, uint256 _updateRateDelay) public {
    vm.assume(!_updateRateDelayPassed(_timeStamp, _lastUpdateTime, _updateRateDelay));
    vm.warp(_timeStamp);
    _mockLastUpdateTime(_lastUpdateTime);
    _mockUpdateRateDelay(_updateRateDelay);

    vm.expectRevert(IPIDRateSetter.PIDRateSetter_RateSetterCooldown.selector);

    pidRateSetter.updateRate();
  }

  function test_Revert_NullPrice(UpdateRateScenario memory _scenario) public {
    _scenario.marketPrice = 0;

    _mockValues(_scenario);

    vm.expectRevert(IPIDRateSetter.PIDRateSetter_InvalidPriceFeed.selector);

    pidRateSetter.updateRate();
  }
}

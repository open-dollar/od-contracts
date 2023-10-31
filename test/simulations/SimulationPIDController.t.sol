// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {TestParams, Deploy} from '@test/e2e/Common.t.sol';
import {console2} from 'forge-std/Script.sol';
import {Math} from '@libraries/Math.sol';
import {RAY, YEAR} from '@libraries/Math.sol';
import {PROPORTIONAL_GAIN, INTEGRAL_GAIN, HALF_LIFE_30_DAYS} from '@script/Params.s.sol';

import {OracleForTest, IBaseOracle} from '@test/mocks/OracleForTest.sol';
import {IPIDController} from '@interfaces/IPIDController.sol';

/**
 * @title  SimulationPIDController
 * @notice This test contract is used to simulate the PID controller and export the data to a csv file
 * @dev    This test is run with the command `yarn test:simulation`
 */
contract SimulationPIDController is TestParams, Deploy, HaiTest {
  using Math for uint256;

  OracleForTest marketOracle;
  string filePath = './test/simulations/pid-controller/';

  function setUp() public {
    marketOracle = new OracleForTest(1e18);
    systemCoinOracle = IBaseOracle(marketOracle);
    _getEnvironmentParams();
    run();
    vm.startPrank(deployer);
  }

  // --- settings ---
  int256 _proportionalGain = int256(PROPORTIONAL_GAIN);
  int256 _integralGain = int256(INTEGRAL_GAIN);
  uint256 _alphaDecay = HALF_LIFE_30_DAYS;
  uint256 _error = 1.01e27; // +1%
  uint256 _days = 31;

  // --- vars to log ---
  int256 _proportionalTerm;
  int256 _integramTerm;
  uint256 _redemptionPrice;
  uint256 _marketPrice;

  string _columns = 'timestamp,day,proportionalTerm,integralTerm,redemptionPrice,marketPrice';

  function test_production_setup_with_impulse()
    public
    setupPID(_proportionalGain, _integralGain, _alphaDecay)
    writeCSV('production_setup_with_impulse', _columns)
  {
    _runSimulationWithImpulse();
  }

  function test_no_gain_with_impulse() public setupPID(0, 0, 0) writeCSV('no_gain_with_impulse', _columns) {
    _runSimulationWithImpulse();
  }

  function test_proportional_with_impulse()
    public
    setupPID(_proportionalGain, 0, 0)
    writeCSV('proportional_gain_with_impulse', _columns)
  {
    _runSimulationWithImpulse();
  }

  function test_integral_with_impulse()
    public
    setupPID(0, _integralGain, 0)
    writeCSV('integral_gain_with_impulse', _columns)
  {
    _runSimulationWithImpulse();
  }

  function test_decay_with_impulse() public setupPID(0, 0, _alphaDecay) writeCSV('decay_with_impulse', _columns) {
    _runSimulationWithImpulse();
  }

  function test_production_setup_with_step()
    public
    setupPID(_proportionalGain, _integralGain, _alphaDecay)
    writeCSV('production_setup_with_step', _columns)
  {
    _runSimulationWithStep();
  }

  function test_no_gain_with_step() public setupPID(0, 0, 0) writeCSV('no_gain_with_step', _columns) {
    _runSimulationWithStep();
  }

  function test_proportional_with_step()
    public
    setupPID(_proportionalGain, 0, 0)
    writeCSV('proportional_gain_with_step', _columns)
  {
    _runSimulationWithStep();
  }

  function test_integral_with_step() public setupPID(0, _integralGain, 0) writeCSV('integral_gain_with_step', _columns) {
    _runSimulationWithStep();
  }

  function test_decay_with_step() public setupPID(0, 0, _alphaDecay) writeCSV('decay_with_step', _columns) {
    _runSimulationWithStep();
  }

  // --- simulation utils ---

  function _runSimulationWithImpulse() internal {
    vm.warp(block.timestamp + 1 days);
    _redemptionPrice = oracleRelayer.redemptionPrice();
    marketOracle.setPriceAndValidity(_redemptionPrice.rmul(_error) / 1e9, true);
    pidRateSetter.updateRate();

    for (uint256 _i; _i < _days; _i++) {
      vm.warp(block.timestamp + 1 days);
      // no error after the first day
      _redemptionPrice = oracleRelayer.redemptionPrice();
      marketOracle.setPriceAndValidity(_redemptionPrice / 1e9, true);
      pidRateSetter.updateRate();

      _logLine(_i);
    }
  }

  function _runSimulationWithStep() internal {
    for (uint256 _i; _i < _days; _i++) {
      vm.warp(block.timestamp + 1 days);
      _redemptionPrice = oracleRelayer.redemptionPrice();
      marketOracle.setPriceAndValidity(_redemptionPrice.rmul(_error) / 1e9, true);
      pidRateSetter.updateRate();

      _logLine(_i);
    }
  }

  modifier setupPID(int256 _kp, int256 _ki, uint256 _pscl) {
    pidController.modifyParameters('kp', abi.encode(_kp));
    pidController.modifyParameters('ki', abi.encode(_ki));
    pidController.modifyParameters('perSecondCumulativeLeak', abi.encode(_pscl));
    marketOracle.setPriceAndValidity(1e18, true);
    oracleRelayer.redemptionPrice();
    _;
  }

  // --- csv utils ---

  function _logLine(uint256 _day) internal {
    IPIDController.DeviationObservation memory _deviationObservation = pidController.deviationObservation();
    _proportionalTerm = _deviationObservation.proportional;
    _integramTerm = _deviationObservation.integral;
    _redemptionPrice = oracleRelayer.redemptionPrice();
    _marketPrice = oracleRelayer.marketPrice();
    vm.writeLine(
      filePath,
      string(
        abi.encodePacked(
          vm.toString(block.timestamp),
          ',',
          vm.toString(_day),
          ',',
          vm.toString(_proportionalTerm),
          ',',
          vm.toString(_integramTerm),
          ',',
          vm.toString(_redemptionPrice),
          ',',
          vm.toString(_marketPrice)
        )
      )
    );
  }

  modifier writeCSV(string memory _fileName, string memory _csvColumns) {
    filePath = string(abi.encodePacked(filePath, _fileName, '.csv'));
    vm.writeFile(filePath, ''); // resets the file
    vm.writeLine(filePath, _csvColumns);
    _;
  }
}

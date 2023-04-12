pragma solidity ^0.6.7;

import {FuzzablePIRawPerSecondCalculator} from './FuzzablePIRawPerSecondCalculator.sol';

contract PIRawPerSecondCalculatorFuzz is FuzzablePIRawPerSecondCalculator {
  int256 Kp__ = int256(EIGHTEEN_DECIMAL_NUMBER);
  int256 Ki__ = int256(EIGHTEEN_DECIMAL_NUMBER);
  uint256 perSecondCumulativeLeak__ = 999_997_208_243_937_652_252_849_536; // 1% per hour
  uint256 integralPeriodSize__ = 3600;
  uint256 noiseBarrier__ = EIGHTEEN_DECIMAL_NUMBER;
  uint256 feedbackOutputUpperBound__ = TWENTY_SEVEN_DECIMAL_NUMBER * EIGHTEEN_DECIMAL_NUMBER;
  int256 feedbackOutputLowerBound__ = -int256(NEGATIVE_RATE_LIMIT);
  int256[] importedState__ = new int[](5);

  // setting the constructor values to the ones used for unit testing, check others
  constructor()
    public
    FuzzablePIRawPerSecondCalculator(
      Kp__,
      Ki__,
      perSecondCumulativeLeak__,
      integralPeriodSize__,
      // noiseBarrier__,
      1,
      feedbackOutputUpperBound__,
      feedbackOutputLowerBound__,
      importedState__
    )
  {
    // granting reader and admin access to echidna addresses
    address payable[3] memory echidnaAddrs = [address(1), address(2), address(0xabc)];
    for (uint256 i = 0; i < echidnaAddrs.length; i++) {
      authorities[echidnaAddrs[i]] = 1;
      readers[echidnaAddrs[i]] = 1;
    }
    seedProposer = echidnaAddrs[0];
  }

  function scrambleParams( // changes pi params on the go (only valid params), will randomly change them (will be part of the path tested), to disable change visibility modifier to internal
    int256 Kp_,
    int256 Ki_,
    uint256 perSecondCumulativeLeak_,
    uint256 integralPeriodSize_,
    uint256 noiseBarrier_
  )
    // uint256 feedbackOutputUpperBound_,
    // int256  feedbackOutputLowerBound_
    internal
  {
    // feedbackOutputUpperBound        = feedbackOutputUpperBound_;
    // feedbackOutputLowerBound        = feedbackOutputLowerBound_;
    integralPeriodSize = integralPeriodSize_;
    controllerGains = ControllerGains(Kp_, Ki_);
    perSecondCumulativeLeak = perSecondCumulativeLeak_ % TWENTY_SEVEN_DECIMAL_NUMBER;
    noiseBarrier = noiseBarrier_ % EIGHTEEN_DECIMAL_NUMBER;
  }

  function echidna_invalid_foub() public view returns (bool) {
    return (
      both(
        feedbackOutputUpperBound < subtract(subtract(uint256(-1), defaultRedemptionRate), 1),
        feedbackOutputUpperBound > 0
      )
    );
  }

  function echidna_invalid_folb() public view returns (bool) {
    return (both(feedbackOutputLowerBound < 0, feedbackOutputLowerBound >= -int256(NEGATIVE_RATE_LIMIT)));
  }

  function echidna_invalid_nb() public view returns (bool) {
    return (noiseBarrier <= EIGHTEEN_DECIMAL_NUMBER);
  }

  uint256 lastValue;

  function echidna_invalid_pscl() public view returns (bool) {
    return (perSecondCumulativeLeak <= TWENTY_SEVEN_DECIMAL_NUMBER);
  }

  uint256 previousRate;
  // use with noise barrier set to 1 case.

  function fuzzComputeRate(uint256 marketPrice, uint256 redemptionPrice, uint256 accumulatedLeak) internal {
    uint256 rate = computeRate(marketPrice, redemptionPrice, accumulatedLeak);
    assert(rate == previousRate || previousRate == 0);
    previousRate = rate;
  }

  function fuzzKpKi(
    uint256 marketPrice,
    uint256 redemptionPrice,
    uint256 accumulatedLeak,
    int256 Kp_,
    int256 Ki_
  ) public {
    controllerGains = ControllerGains(Kp_, Ki_);
    computeRate(1 ether, 1 ether + 1000, now);
  }

  function fuzzMath(uint256 marketPrice, uint256 redemptionPrice, uint256 accumulatedLeak) public {
    accumulatedLeak = (accumulatedLeak == 0) ? 1 : accumulatedLeak;
    int256 p = subtract(int256(redemptionPrice), multiply(int256(marketPrice), int256(10 ** 9)));

    int256 lastProportionalTerm = getLastProportionalTerm();
    uint256 timeElapsed = (lastUpdateTime == 0) ? 0 : now - lastUpdateTime;
    int256 newTimeAdjustedDeviation = riemannSum(p, lastProportionalTerm) * int256(timeElapsed);
    int256 leakedPriceCumulative =
      (int256(accumulatedLeak) * priceDeviationCumulative) / int256(TWENTY_SEVEN_DECIMAL_NUMBER);

    int256 i = leakedPriceCumulative + newTimeAdjustedDeviation;

    // gain adjusting
    int256 adjustedProportional = (p * int256(controllerGains.Kp)) / int256(EIGHTEEN_DECIMAL_NUMBER);
    int256 adjustedIntegral = (i * int256(controllerGains.Ki)) / int256(EIGHTEEN_DECIMAL_NUMBER);
    int256 piOutput = adjustedProportional + adjustedIntegral;

    (uint256 calcRate,) = getBoundedRedemptionRate(piOutput);
    (uint256 rate) = computeRate(marketPrice, redemptionPrice, accumulatedLeak);
    assert(calcRate == rate);
  }
}

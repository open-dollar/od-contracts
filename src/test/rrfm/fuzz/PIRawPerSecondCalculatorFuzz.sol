pragma solidity ^0.6.7;

import {FuzzablePIRawPerSecondCalculator} from './FuzzablePIRawPerSecondCalculator.sol';

contract PIRawPerSecondCalculatorFuzz is FuzzablePIRawPerSecondCalculator {

    int256 Kp__                                 = int(EIGHTEEN_DECIMAL_NUMBER);
    int256 Ki__                                 = int(EIGHTEEN_DECIMAL_NUMBER);
    uint256 perSecondCumulativeLeak__           = 999997208243937652252849536; // 1% per hour
    uint256 integralPeriodSize__                = 3600;
    uint256 noiseBarrier__                      = EIGHTEEN_DECIMAL_NUMBER;
    uint256 feedbackOutputUpperBound__          = TWENTY_SEVEN_DECIMAL_NUMBER * EIGHTEEN_DECIMAL_NUMBER;
    int256  feedbackOutputLowerBound__          = -int(NEGATIVE_RATE_LIMIT);
    int256[] importedState__                    = new int[](5);


    // setting the constructor values to the ones used for unit testing, check others
    constructor() public
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
    ) {
        // granting reader and admin access to echidna addresses
        address payable[3] memory echidnaAddrs = [address(1), address(2), address(0xabc)];
        for (uint i = 0; i < echidnaAddrs.length; i++) {
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
        // uint256 feedbackOutputUpperBound_,
        // int256  feedbackOutputLowerBound_
    ) internal {
        // feedbackOutputUpperBound        = feedbackOutputUpperBound_;
        // feedbackOutputLowerBound        = feedbackOutputLowerBound_;
        integralPeriodSize              = integralPeriodSize_;
        controllerGains                 = ControllerGains(Kp_, Ki_);
        perSecondCumulativeLeak         = perSecondCumulativeLeak_ % TWENTY_SEVEN_DECIMAL_NUMBER;
        noiseBarrier                    = noiseBarrier_ % EIGHTEEN_DECIMAL_NUMBER;
    }

    function echidna_invalid_foub() public view returns (bool) {
        return (both(feedbackOutputUpperBound < subtract(subtract(uint(-1), defaultRedemptionRate), 1), feedbackOutputUpperBound > 0));
    }

    function echidna_invalid_folb() public view returns (bool) {
        return (both(feedbackOutputLowerBound < 0, feedbackOutputLowerBound >= -int(NEGATIVE_RATE_LIMIT)));
    }

    function echidna_invalid_nb() public view returns (bool) {
        return (noiseBarrier <= EIGHTEEN_DECIMAL_NUMBER);
    }

    uint lastValue;

    function echidna_invalid_pscl() public view returns (bool) {
        return (perSecondCumulativeLeak <= TWENTY_SEVEN_DECIMAL_NUMBER);
    }

    uint previousRate;
    // use with noise barrier set to 1 case.
    function fuzzComputeRate(
        uint marketPrice,
        uint redemptionPrice,
        uint accumulatedLeak
    ) internal {
        uint rate = computeRate(marketPrice, redemptionPrice, accumulatedLeak);
        assert(rate == previousRate || previousRate == 0);
        previousRate = rate;
    }

    function fuzzKpKi(
        uint marketPrice,
        uint redemptionPrice,
        uint accumulatedLeak,
        int256 Kp_,
        int256 Ki_
    ) public {
        controllerGains = ControllerGains(Kp_, Ki_);
        computeRate(1 ether, 1 ether + 1000, now);
    }

    function fuzzMath(
        uint marketPrice,
        uint redemptionPrice,
        uint accumulatedLeak
    ) public {
        accumulatedLeak = (accumulatedLeak == 0) ? 1 : accumulatedLeak;
        int p = subtract(int(redemptionPrice), multiply(int(marketPrice), int(10**9)));

        int256 lastProportionalTerm      = getLastProportionalTerm();
        uint256 timeElapsed              = (lastUpdateTime == 0) ? 0 : now - lastUpdateTime;
        int256 newTimeAdjustedDeviation  = riemannSum(p, lastProportionalTerm) * int(timeElapsed);
        int256 leakedPriceCumulative     = (int(accumulatedLeak) * priceDeviationCumulative) / int(TWENTY_SEVEN_DECIMAL_NUMBER);

        int i = leakedPriceCumulative + newTimeAdjustedDeviation;

        // gain adjusting
        int adjustedProportional = (p * int(controllerGains.Kp)) / int(EIGHTEEN_DECIMAL_NUMBER);
        int adjustedIntegral = (i * int(controllerGains.Ki)) / int(EIGHTEEN_DECIMAL_NUMBER);
        int piOutput = adjustedProportional + adjustedIntegral;

        (uint calcRate, ) = getBoundedRedemptionRate(piOutput);
        (uint rate) = computeRate(marketPrice, redemptionPrice, accumulatedLeak);
        assert (calcRate == rate);
    }
}

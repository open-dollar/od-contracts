pragma solidity 0.6.7;

import {FuzzablePIScaledPerSecondCalculator} from './FuzzablePIScaledPerSecondCalculator.sol';

contract PIScaledPerSecondCalculatorFuzz is FuzzablePIScaledPerSecondCalculator {
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
    FuzzablePIScaledPerSecondCalculator(
        Kp__,
        Ki__,
        perSecondCumulativeLeak__,
        integralPeriodSize__,
        noiseBarrier__,
        // 1,
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
        allReaderToggle = 1;
    }

    function scrambleParams( // changes pi params on the go, will randomly change them, to disable change visibility modifier to internal
        int256 Kp_,
        int256 Ki_,
        uint256 perSecondCumulativeLeak_,
        uint256 integralPeriodSize_,
        uint256 noiseBarrier_,
        uint256 feedbackOutputUpperBound_,
        int256  feedbackOutputLowerBound_
    ) internal {
        // feedbackOutputUpperBound        = feedbackOutputUpperBound_;
        // feedbackOutputLowerBound        = feedbackOutputLowerBound_;
        // integralPeriodSize              = integralPeriodSize_;
        controllerGains                 = ControllerGains(Kp_, Ki_);
        // perSecondCumulativeLeak         = perSecondCumulativeLeak_;
        // noiseBarrier                    = noiseBarrier_;
    }

    // function echidna_invalid_foub() public view returns (bool) {
    //     return (both(feedbackOutputUpperBound < subtract(subtract(uint(-1), defaultRedemptionRate), 1), feedbackOutputUpperBound > 0));
    // }

    // function echidna_invalid_folb() public view returns (bool) {
    //     return (both(feedbackOutputLowerBound < 0, feedbackOutputLowerBound >= -int(NEGATIVE_RATE_LIMIT)));
    // }

    // function echidna_invalid_nb() public view returns (bool) {
    //     return (noiseBarrier <= EIGHTEEN_DECIMAL_NUMBER);
    // }

    // function echidna_invalid_pscl() public view returns (bool) {
    //     return (perSecondCumulativeLeak <= TWENTY_SEVEN_DECIMAL_NUMBER);
    // }


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
        int256 Kp_,
        int256 Ki_
    ) internal {
        controllerGains = ControllerGains(Kp_, Ki_);
        computeRate(marketPrice, redemptionPrice, 100);
    }
}

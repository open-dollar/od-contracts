/// PRawPerSecondCalculator.sol

/**
Reflexer PI Controller License 1.0

Definitions

Primary License: This license agreement
Secondary License: GNU General Public License v2.0 or later
Effective Date of Secondary License: August 1st, 2022

Licensed Software:

Software License Grant: Subject to and dependent upon your adherence to the terms and conditions of this Primary License, and subject to explicit approval by Reflexer, Inc., Reflexer, Inc., hereby grants you the right to copy, modify or otherwise create derivative works, redistribute, and use the Licensed Software solely for internal testing and development, and solely until the Effective Date of the Secondary License.  You may not, and you agree you will not, use the Licensed Software outside the scope of the limited license grant in this Primary License.

You agree you will not (i) use the Licensed Software for any commercial purpose, and (ii) deploy the Licensed Software to a blockchain system other than as a noncommercial deployment to a testnet in which tokens or transactions could not reasonably be expected to have or develop commercial value.You agree to be bound by the terms and conditions of this Primary License until the Effective Date of the Secondary License, at which time the Primary License will expire and be replaced by the Secondary License. You Agree that as of the Effective Date of the Secondary License, you will be bound by the terms and conditions of the Secondary License.

You understand and agree that any violation of the terms and conditions of this License will automatically terminate your rights under this License for the current and all other versions of the Licensed Software.

You understand and agree that any use of the Licensed Software outside the boundaries of the limited licensed granted in this Primary License renders the license granted in this Primary License null and void as of the date you first used the Licensed Software in any way (void ab initio).You understand and agree that you may purchase a commercial license to use a version of the Licensed Software under the terms and conditions set by Reflexer, Inc.  You understand and agree that you will display an unmodified copy of this Primary License with each Licensed Software, and any derivative work of the Licensed Software.

TO THE EXTENT PERMITTED BY APPLICABLE LAW, THE LICENSED SOFTWARE IS PROVIDED ON AN “AS IS” BASIS. REFLEXER, INC HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS OR IMPLIED, INCLUDING (WITHOUT LIMITATION) ANY WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, NON-INFRINGEMENT, AND TITLE.

You understand and agree that all copies of the Licensed Software, and all derivative works thereof, are each subject to the terms and conditions of this License. Notwithstanding the foregoing, You hereby grant to Reflexer, Inc. a fully paid-up, worldwide, fully sublicensable license to use,for any lawful purpose, any such derivative work made by or for You, now or in the future. You agree that you will, at the request of Reflexer, Inc., provide Reflexer, Inc. with the complete source code to such derivative work.

Copyright © 2021 Reflexer Inc. All Rights Reserved
**/

pragma solidity 0.6.7;

import "../math/SafeMath.sol";
import "../math/SignedSafeMath.sol";

contract PRawPerSecondCalculator is SafeMath, SignedSafeMath {
    // --- Authorities ---
    mapping (address => uint) public authorities;
    function addAuthority(address account) external isAuthority { authorities[account] = 1; }
    function removeAuthority(address account) external isAuthority { authorities[account] = 0; }
    modifier isAuthority {
        require(authorities[msg.sender] == 1, "PRawPerSecondCalculator/not-an-authority");
        _;
    }

    // --- Readers ---
    mapping (address => uint) public readers;
    function addReader(address account) external isAuthority { readers[account] = 1; }
    function removeReader(address account) external isAuthority { readers[account] = 0; }
    modifier isReader {
        require(either(allReaderToggle == 1, readers[msg.sender] == 1), "PRawPerSecondCalculator/not-a-reader");
        _;
    }

    // -- Static & Default Variables ---
    // The Kp used in this calculator
    int256  internal Kp;                             // [EIGHTEEN_DECIMAL_NUMBER]

    // Flag that can allow anyone to read variables
    uint256 public   allReaderToggle;
    // The minimum percentage deviation from the redemption price that allows the contract to calculate a non null redemption rate
    uint256 internal noiseBarrier;                   // [EIGHTEEN_DECIMAL_NUMBER]
    // The default redemption rate to calculate in case P + I is smaller than noiseBarrier
    uint256 internal defaultRedemptionRate;          // [TWENTY_SEVEN_DECIMAL_NUMBER]
    // The maximum value allowed for the redemption rate
    uint256 internal feedbackOutputUpperBound;       // [TWENTY_SEVEN_DECIMAL_NUMBER]
    // The minimum value allowed for the redemption rate
    int256  internal feedbackOutputLowerBound;       // [TWENTY_SEVEN_DECIMAL_NUMBER]
    // The minimum delay between two computeRate calls
    uint256 internal periodSize;                     // [seconds]

    // --- Fluctuating/Dynamic Variables ---
    // Timestamp of the last update
    uint256 internal lastUpdateTime;                       // [timestamp]
    // Flag indicating that the rate computed is per second
    uint256 constant internal defaultGlobalTimeline = 1;

    // The address allowed to call calculateRate
    address public seedProposer;

    uint256 internal constant NEGATIVE_RATE_LIMIT         = TWENTY_SEVEN_DECIMAL_NUMBER - 1;
    uint256 internal constant TWENTY_SEVEN_DECIMAL_NUMBER = 10 ** 27;
    uint256 internal constant EIGHTEEN_DECIMAL_NUMBER     = 10 ** 18;

    constructor(
        int256 Kp_,
        uint256 periodSize_,
        uint256 noiseBarrier_,
        uint256 feedbackOutputUpperBound_,
        int256  feedbackOutputLowerBound_
    ) public {
        defaultRedemptionRate      = TWENTY_SEVEN_DECIMAL_NUMBER;

        require(both(feedbackOutputUpperBound_ < subtract(subtract(uint(-1), defaultRedemptionRate), 1), feedbackOutputUpperBound_ > 0), "PRawPerSecondCalculator/invalid-foub");
        require(both(feedbackOutputLowerBound_ < 0, feedbackOutputLowerBound_ >= -int(NEGATIVE_RATE_LIMIT)), "PRawPerSecondCalculator/invalid-folb");
        require(periodSize_ > 0, "PRawPerSecondCalculator/invalid-ips");
        require(both(noiseBarrier_ > 0, noiseBarrier_ <= EIGHTEEN_DECIMAL_NUMBER), "PRawPerSecondCalculator/invalid-nb");
        require(both(Kp_ >= -int(EIGHTEEN_DECIMAL_NUMBER), Kp_ <= int(EIGHTEEN_DECIMAL_NUMBER)), "PRawPerSecondCalculator/invalid-sg");

        authorities[msg.sender]   = 1;
        readers[msg.sender]       = 1;

        feedbackOutputUpperBound  = feedbackOutputUpperBound_;
        feedbackOutputLowerBound  = feedbackOutputLowerBound_;
        periodSize                = periodSize_;
        Kp                        = Kp_;
        noiseBarrier              = noiseBarrier_;
    }

    // --- Boolean Logic ---
    function both(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := and(x, y)}
    }
    function either(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := or(x, y)}
    }

    // --- Administration ---
    /*
    * @notify Modify an address parameter
    * @param parameter The name of the address parameter to change
    * @param addr The new address for the parameter
    */
    function modifyParameters(bytes32 parameter, address addr) external isAuthority {
        if (parameter == "seedProposer") {
          readers[seedProposer] = 0;
          seedProposer = addr;
          readers[seedProposer] = 1;
        }
        else revert("PRawPerSecondCalculator/modify-unrecognized-param");
    }
    /*
    * @notify Modify an uint256 parameter
    * @param parameter The name of the parameter to change
    * @param val The new value for the parameter
    */
    function modifyParameters(bytes32 parameter, uint256 val) external isAuthority {
        if (parameter == "nb") {
          require(both(val > 0, val <= EIGHTEEN_DECIMAL_NUMBER), "PRawPerSecondCalculator/invalid-nb");
          noiseBarrier = val;
        }
        else if (parameter == "ps") {
          require(val > 0, "PRawPerSecondCalculator/null-ps");
          periodSize = val;
        }
        else if (parameter == "foub") {
          require(both(val < subtract(subtract(uint(-1), defaultRedemptionRate), 1), val > 0), "PRawPerSecondCalculator/invalid-foub");
          feedbackOutputUpperBound = val;
        }
        else if (parameter == "allReaderToggle") {
          allReaderToggle = val;
        }
        else revert("PRawPerSecondCalculator/modify-unrecognized-param");
    }
    /*
    * @notify Modify an int256 parameter
    * @param parameter The name of the parameter to change
    * @param val The new value for the parameter
    */
    function modifyParameters(bytes32 parameter, int256 val) external isAuthority {
        if (parameter == "folb") {
          require(both(val < 0, val >= -int(NEGATIVE_RATE_LIMIT)), "PRawPerSecondCalculator/invalid-folb");
          feedbackOutputLowerBound = val;
        }
        else if (parameter == "sg") {
          require(both(val >= -int(EIGHTEEN_DECIMAL_NUMBER), val <= int(EIGHTEEN_DECIMAL_NUMBER)), "PRawPerSecondCalculator/invalid-sg");
          Kp = val;
        }
        else revert("PRawPerSecondCalculator/modify-unrecognized-param");
    }

    // --- Controller Specific Math ---
    function absolute(int x) internal pure returns (uint z) {
        z = (x < 0) ? uint(-x) : uint(x);
    }

    // --- P Controller Utils ---
    /*
    * @notice Return a redemption rate bounded by feedbackOutputLowerBound and feedbackOutputUpperBound as well as the
              timeline over which that rate will take effect
    * @param pOutput The raw redemption rate computed from the proportional and integral terms
    */
    function getBoundedRedemptionRate(int pOutput) public isReader view returns (uint256, uint256) {
        int  boundedPOutput = pOutput;
        uint newRedemptionRate;

        if (pOutput < feedbackOutputLowerBound) {
          boundedPOutput = feedbackOutputLowerBound;
        } else if (pOutput > int(feedbackOutputUpperBound)) {
          boundedPOutput = int(feedbackOutputUpperBound);
        }

        // newRedemptionRate cannot be lower than 10^0 (1) because of the way rpower is designed
        bool negativeOutputExceedsHundred = (boundedPOutput < 0 && -boundedPOutput >= int(defaultRedemptionRate));

        // If it is smaller than 1, set it to the nagative rate limit
        if (negativeOutputExceedsHundred) {
          newRedemptionRate = NEGATIVE_RATE_LIMIT;
        } else {
          // If boundedPOutput is lower than -int(NEGATIVE_RATE_LIMIT) set newRedemptionRate to 1
          if (boundedPOutput < 0 && boundedPOutput <= -int(NEGATIVE_RATE_LIMIT)) {
            newRedemptionRate = uint(addition(int(defaultRedemptionRate), -int(NEGATIVE_RATE_LIMIT)));
          } else {
            // Otherwise add defaultRedemptionRate and boundedPOutput together
            newRedemptionRate = uint(addition(int(defaultRedemptionRate), boundedPOutput));
          }
        }

        return (newRedemptionRate, defaultGlobalTimeline);
    }
    /*
    * @notice Returns whether the proportional result exceeds the noise barrier
    * @param proportionalResult Represents the P term
    * @param redemptionPrice The system coin redemption price
    */
    function breaksNoiseBarrier(uint proportionalResult, uint redemptionPrice) public isReader view returns (bool) {
        uint deltaNoise = subtract(multiply(uint(2), EIGHTEEN_DECIMAL_NUMBER), noiseBarrier);
        return proportionalResult >= subtract(divide(multiply(redemptionPrice, deltaNoise), EIGHTEEN_DECIMAL_NUMBER), redemptionPrice);
    }

    // --- Rate Validation/Calculation ---
    /*
    * @notice Compute a new redemption rate
    * @param marketPrice The system coin market price
    * @param redemptionPrice The system coin redemption price
    */
    function computeRate(
      uint marketPrice,
      uint redemptionPrice,
      uint
    ) external returns (uint256) {
        // Only the seed proposer can call this
        require(seedProposer == msg.sender, "PRawPerSecondCalculator/invalid-msg-sender");
        // Ensure that at least periodSize seconds passed since the last update or that this is the first update
        require(subtract(now, lastUpdateTime) >= periodSize || lastUpdateTime == 0, "PRawPerSecondCalculator/wait-more");
        // The proportional term is just redemption - market. Market is read as having 18 decimals so we multiply by 10**9
        // in order to have 27 decimals like the redemption price
        int256 proportionalTerm = subtract(int(redemptionPrice), multiply(int(marketPrice), int(10**9)));
        // Set the last update time to now
        lastUpdateTime = now;
        // Multiply P by Kp
        proportionalTerm = multiply(proportionalTerm, int(Kp)) / int(EIGHTEEN_DECIMAL_NUMBER);
        // If the P * Kp output breaks the noise barrier, you can recompute a non null rate. Also make sure the output is not null
        if (
          breaksNoiseBarrier(absolute(proportionalTerm), redemptionPrice) &&
          proportionalTerm != 0
        ) {
          // Get the new redemption rate by taking into account the feedbackOutputUpperBound and feedbackOutputLowerBound
          (uint newRedemptionRate, ) = getBoundedRedemptionRate(proportionalTerm);
          return newRedemptionRate;
        } else {
          return TWENTY_SEVEN_DECIMAL_NUMBER;
        }
    }
    /*
    * @notice Compute and return the upcoming redemption rate
    * @param marketPrice The system coin market price
    * @param redemptionPrice The system coin redemption price
    */
    function getNextRedemptionRate(uint marketPrice, uint redemptionPrice, uint)
      public isReader view returns (uint256, int256, uint256) {
        // The proportional term is just redemption - market. Market is read as having 18 decimals so we multiply by 10**9
        // in order to have 27 decimals like the redemption price
        int256 rawProportionalTerm = subtract(int(redemptionPrice), multiply(int(marketPrice), int(10**9)));
        // Multiply P by Kp
        int256 gainProportionalTerm = multiply(rawProportionalTerm, int(Kp)) / int(EIGHTEEN_DECIMAL_NUMBER);
        // If the P * Kp output breaks the noise barrier, you can recompute a non null rate. Also make sure the output is not null
        if (
          breaksNoiseBarrier(absolute(gainProportionalTerm), redemptionPrice) &&
          gainProportionalTerm != 0
        ) {
          // Get the new redemption rate by taking into account the feedbackOutputUpperBound and feedbackOutputLowerBound
          (uint newRedemptionRate, uint rateTimeline) = getBoundedRedemptionRate(gainProportionalTerm);
          return (newRedemptionRate, rawProportionalTerm, rateTimeline);
        } else {
          return (TWENTY_SEVEN_DECIMAL_NUMBER, rawProportionalTerm, defaultGlobalTimeline);
        }
    }

    // --- Parameter Getters ---
    /*
    * @notice Get the timeline over which the computed redemption rate takes effect e.g rateTimeline = 3600 so the rate is
    *         computed over 1 hour
    */
    function rt(uint marketPrice, uint redemptionPrice, uint) external isReader view returns (uint256) {
        (, , uint rateTimeline) = getNextRedemptionRate(marketPrice, redemptionPrice, 0);
        return rateTimeline;
    }
    /*
    * @notice Return Kp
    */
    function sg() external isReader view returns (int256) {
        return Kp;
    }
    function nb() external isReader view returns (uint256) {
        return noiseBarrier;
    }
    function drr() external isReader view returns (uint256) {
        return defaultRedemptionRate;
    }
    function foub() external isReader view returns (uint256) {
        return feedbackOutputUpperBound;
    }
    function folb() external isReader view returns (int256) {
        return feedbackOutputLowerBound;
    }
    function ps() external isReader view returns (uint256) {
        return periodSize;
    }
    function pscl() external isReader view returns (uint256) {
        return TWENTY_SEVEN_DECIMAL_NUMBER;
    }
    function lut() external isReader view returns (uint256) {
        return lastUpdateTime;
    }
    function dgt() external isReader view returns (uint256) {
        return defaultGlobalTimeline;
    }
    /*
    * @notice Returns the time elapsed since the last calculateRate call minus periodSize
    */
    function adat() external isReader view returns (uint256) {
        uint elapsed = subtract(now, lastUpdateTime);
        if (elapsed < periodSize) {
          return 0;
        }
        return subtract(elapsed, periodSize);
    }
    /*
    * @notice Returns the time elapsed since the last calculateRate call
    */
    function tlv() external isReader view returns (uint256) {
        uint elapsed = (lastUpdateTime == 0) ? 0 : subtract(now, lastUpdateTime);
        return elapsed;
    }
}

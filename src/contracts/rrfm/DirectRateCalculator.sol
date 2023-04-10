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

contract DirectRateCalculator is SafeMath {
    // --- Authorities ---
    mapping (address => uint) public authorities;
    function addAuthority(address account) external isAuthority { authorities[account] = 1; }
    function removeAuthority(address account) external isAuthority { authorities[account] = 0; }
    modifier isAuthority {
        require(authorities[msg.sender] == 1, "DirectRateCalculator/not-an-authority");
        _;
    }

    // --- Readers ---
    mapping (address => uint) public readers;
    function addReader(address account) external isAuthority { readers[account] = 1; }
    function removeReader(address account) external isAuthority { readers[account] = 0; }
    modifier isReader {
        require(either(allReaderToggle == 1, readers[msg.sender] == 1), "DirectRateCalculator/not-a-reader");
        _;
    }

    // --- Variables ---
    // Flag that can allow anyone to read variables
    uint256 public   allReaderToggle;
    // Multiplier for the delta between prices
    uint256 internal acceleration;

    uint256 internal constant TWENTY_SEVEN_DECIMAL_NUMBER = 10 ** 27;
    uint256 internal constant EIGHTEEN_DECIMAL_NUMBER     = 10 ** 18;

    constructor(
        uint256 acceleration_
    ) public {
        authorities[msg.sender] = 1;
        readers[msg.sender]     = 1;
        acceleration            = acceleration_;
    }

    // --- Boolean Logic ---
    function either(bool x, bool y) internal pure returns (bool z) {
        assembly{ z := or(x, y)}
    }

    // --- Administration ---
    /*
    * @notify Modify an uint256 parameter
    * @param parameter The name of the parameter to change
    * @param val The new value for the parameter
    */
    function modifyParameters(bytes32 parameter, uint256 val) external isAuthority {
        if (parameter == "acc") {
          acceleration = val;
        }
        else if (parameter == "allReaderToggle") {
          allReaderToggle = val;
        }
        else revert("DirectRateCalculator/modify-unrecognized-param");
    }

    // --- Controller Specific Math ---
    /*
    * @notify Compose a rate by combining a delta from 0% and TWENTY_SEVEN_DECIMAL_NUMBER
    */
    function composeRate(int256 rateComposition) public pure returns (uint256) {
        return rateComposition >= 0 ? addition(TWENTY_SEVEN_DECIMAL_NUMBER, uint256(rateComposition))
            : divide(multiply(TWENTY_SEVEN_DECIMAL_NUMBER, TWENTY_SEVEN_DECIMAL_NUMBER), addition(TWENTY_SEVEN_DECIMAL_NUMBER, uint256(-rateComposition)));
    }
    /*
    * @notify Decompose a rate by returning its delta from TWENTY_SEVEN_DECIMAL_NUMBER
    */
    function decomposeRate(uint256 rawRate) public pure returns (int256) {
        return rawRate >= TWENTY_SEVEN_DECIMAL_NUMBER ? int256(subtract(rawRate, TWENTY_SEVEN_DECIMAL_NUMBER))
            : int256(TWENTY_SEVEN_DECIMAL_NUMBER) - int256(multiply(TWENTY_SEVEN_DECIMAL_NUMBER, TWENTY_SEVEN_DECIMAL_NUMBER) / rawRate);
    }

    // --- Rate Calculation ---
    /*
    * @notice Compute a new redemption rate
    * @param marketPrice The system coin market price
    * @param redemptionPrice The system coin redemption price
    * @param currentRedemptionRate The most recent redemption rate
    */
    function computeRate(
      uint marketPrice,
      uint redemptionPrice,
      uint currentRedemptionRate
    ) external view isAuthority returns (uint256) {
        // If there is no acceleration, the rate will not change so we can return early
        if (acceleration == 0) return currentRedemptionRate;
        // Get the scaled proportional
        int256 scaledProportional = getScaledProportional(marketPrice, redemptionPrice);
        // Return the newly composed rate
        return composeRate(decomposeRate(currentRedemptionRate) + (multiply(marketPrice, 10**9) < redemptionPrice ? scaledProportional : -scaledProportional));
    }
    /*
    * @notice Calculate and return the scaled proportional
    * @param marketPrice The market price
    * @param redemptionPrice The redemption price
    */
    function getScaledProportional(uint marketPrice, uint redemptionPrice) public view returns (int256) {
        // The proportional term is just redemption - market. Market is read as having 18 decimals so we multiply by 10**9
        // in order to have 27 decimals like the redemption price
        uint256 scaledMarketPrice  = multiply(marketPrice, 10**9);
        // Get the rate proportional term
        uint256 proportionalTerm   = (scaledMarketPrice <= redemptionPrice) ?
          subtract(redemptionPrice, scaledMarketPrice) : subtract(scaledMarketPrice, redemptionPrice);
        // Multiply the proportional by the acceleration
        int256 scaledProportional  = int256(multiply(acceleration, proportionalTerm) / EIGHTEEN_DECIMAL_NUMBER);
        return scaledProportional;
    }

    // --- Getters ---
    /*
    * @notify Return the acceleration
    */
    function acc() public view isReader returns (uint256) {
        return acceleration;
    }
}

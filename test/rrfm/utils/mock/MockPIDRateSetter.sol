// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Math} from '@libraries/Math.sol';

abstract contract OracleLike {
  function getResultWithValidity() external view virtual returns (uint256, bool);
}

abstract contract OracleRelayerLike {
  function redemptionPrice() external virtual returns (uint256);
  function updateRedemptionRate(uint256) external virtual;
}

abstract contract SetterRelayer {
  function relayRate(uint256) external virtual;
}

abstract contract PIDCalculator {
  function computeRate(uint256, uint256) external virtual returns (uint256);
  function rt(uint256, uint256, uint256) external view virtual returns (uint256);
  function perSecondCumulativeLeak() external view virtual returns (uint256);
  function timeSinceLastUpdate() external view virtual returns (uint256);
}

contract MockPIDRateSetter {
  using Math for uint256;

  // --- System Dependencies ---
  // OSM or medianizer for the system coin
  OracleLike public orcl;
  // OracleRelayer where the redemption price is stored
  OracleRelayerLike public oracleRelayer;
  // The contract that will pass the new redemption rate to the oracle relayer
  SetterRelayer public setterRelayer;
  // Calculator for the redemption rate
  PIDCalculator public pidCalculator;

  constructor(address orcl_, address oracleRelayer_, address pidCalculator_, address setterRelayer_) {
    oracleRelayer = OracleRelayerLike(oracleRelayer_);
    orcl = OracleLike(orcl_);
    setterRelayer = SetterRelayer(setterRelayer_);
    pidCalculator = PIDCalculator(pidCalculator_);
  }

  function modifyParameters(bytes32 parameter, address addr) external {
    if (parameter == 'orcl') {
      orcl = OracleLike(addr);
    } else if (parameter == 'oracleRelayer') {
      oracleRelayer = OracleRelayerLike(addr);
    } else if (parameter == 'setterRelayer') {
      setterRelayer = SetterRelayer(addr);
    } else if (parameter == 'pidCalculator') {
      pidCalculator = PIDCalculator(addr);
    } else {
      revert('RateSetter/modify-unrecognized-param');
    }
  }

  function updateRate(address) public {
    // Get price feed updates
    (uint256 marketPrice, bool hasValidValue) = orcl.getResultWithValidity();
    // If the oracle has a value
    require(hasValidValue, 'MockPIDRateSetter/invalid-oracle-value');
    // If the price is non-zero
    require(marketPrice > 0, 'MockPIDRateSetter/null-market-price');
    // Get the latest redemption price
    uint256 redemptionPrice = oracleRelayer.redemptionPrice();
    // Calculate the new redemption rate
    uint256 calculated = pidCalculator.computeRate(marketPrice, redemptionPrice);
    // Update the rate using the setter relayer
    oracleRelayer.updateRedemptionRate(calculated);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

contract MockOracleRelayer {
  // The force that changes the system users' incentives by changing the redemption price
  uint256 public redemptionRate;
  // Last time when the redemption price was changed
  uint256 public redemptionPriceUpdateTime;
  // Virtual redemption price (not the most updated value)
  uint256 internal _redemptionPrice;
  // Upper bound for the per-second redemption rate
  uint256 public redemptionRateUpperBound; // [ray]
  // Lower bound for the per-second redemption rate
  uint256 public redemptionRateLowerBound; // [ray]

  constructor() {
    redemptionRate = RAY;
    _redemptionPrice = RAY;
    redemptionRateUpperBound = RAY * WAD;
    redemptionRateLowerBound = 1;
  }

  // --- Math ---
  uint256 constant WAD = 10 ** 18;
  uint256 constant RAY = 10 ** 27;

  function subtract(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = x - y;
    require(z <= x);
  }

  function multiply(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require(y == 0 || (z = x * y) / y == x);
  }

  function rmultiply(uint256 x, uint256 y) internal pure returns (uint256 z) {
    // alsites rounds down
    z = multiply(x, y) / RAY;
  }

  function rpower(uint256 x, uint256 n, uint256 base) internal pure returns (uint256 z) {
    assembly {
      switch x
      case 0 {
        switch n
        case 0 { z := base }
        default { z := 0 }
      }
      default {
        switch mod(n, 2)
        case 0 { z := base }
        default { z := x }
        let half := div(base, 2) // for rounding.
        for { n := div(n, 2) } n { n := div(n, 2) } {
          let xx := mul(x, x)
          if iszero(eq(div(xx, x), x)) { revert(0, 0) }
          let xxRound := add(xx, half)
          if lt(xxRound, xx) { revert(0, 0) }
          x := div(xxRound, base)
          if mod(n, 2) {
            let zx := mul(z, x)
            if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0, 0) }
            let zxRound := add(zx, half)
            if lt(zxRound, zx) { revert(0, 0) }
            z := div(zxRound, base)
          }
        }
      }
    }
  }

  // --- Administration ---
  function modifyParameters(bytes32 parameter, uint256 data) external {
    if (parameter == 'redemptionPrice') {
      _redemptionPrice = data;
    } else if (parameter == 'redemptionRate') {
      require(block.timestamp == redemptionPriceUpdateTime, 'MockOracleRelayer/redemption-price-not-updated');
      uint256 adjustedRate = data;
      if (data > redemptionRateUpperBound) {
        adjustedRate = redemptionRateUpperBound;
      } else if (data < redemptionRateLowerBound) {
        adjustedRate = redemptionRateLowerBound;
      }
      redemptionRate = adjustedRate;
    } else if (parameter == 'redemptionRateUpperBound') {
      require(data > RAY, 'MockOracleRelayer/invalid-redemption-rate-upper-bound');
      redemptionRateUpperBound = data;
    } else if (parameter == 'redemptionRateLowerBound') {
      require(data < RAY, 'MockOracleRelayer/invalid-redemption-rate-lower-bound');
      redemptionRateLowerBound = data;
    }
  }

  // --- Redemption Price Update ---
  /**
   * @notice Update the redemption price according to the current redemption rate
   */
  function updateRedemptionPrice() internal returns (uint256) {
    // Update redemption price
    _redemptionPrice =
      rmultiply(rpower(redemptionRate, subtract(block.timestamp, redemptionPriceUpdateTime), RAY), _redemptionPrice);
    if (_redemptionPrice == 0) _redemptionPrice = 1;
    redemptionPriceUpdateTime = block.timestamp;
    // Return updated redemption price
    return _redemptionPrice;
  }

  function updateRedemptionRate(uint256 rate) external {
    redemptionRate = rate;
  }

  /**
   * @notice Fetch the latest redemption price by first updating it
   */
  function redemptionPrice() public returns (uint256) {
    if (block.timestamp > redemptionPriceUpdateTime) return updateRedemptionPrice();
    return _redemptionPrice;
  }
}

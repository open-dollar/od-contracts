// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

contract Math {
  uint256 constant RAY = 10 ** 27;
  uint256 constant WAD = 10 ** 18;
  uint256 constant MAX_LIQUIDATION_QUANTITY = uint256(int256(-1)) / RAY;
  uint256 constant HUNDRED = 10 ** 2;
  uint256 public constant FIFTY = 50;
  uint256 public constant ONE = 1;
  uint256 public constant ONE_ETH = 1e18;
  int256 public constant INT256_MIN = -2 ** 255;

  function addition(uint256 x, int256 y) internal pure returns (uint256 z) {
    if (y > 0) {
      z = x + uint256(y);
    } else {
      z = x - uint256(-y);
    }
    require(y >= 0 || z <= x, 'Math/add-uint-int-overflow');
    require(y <= 0 || z >= x, 'Math/add-uint-int-underflow');
  }

  function addition(int256 x, int256 y) internal pure returns (int256 z) {
    z = x + y;
    require(y >= 0 || z <= x, 'Math/add-int-int-overflow');
    require(y <= 0 || z >= x, 'Math/add-int-int-underflow');
  }

  function addition(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require((z = x + y) >= x, 'Math/add-uint-uint-overflow');
  }

  function addUint48(uint48 x, uint48 y) internal pure returns (uint48 z) {
    require((z = x + y) >= x, 'Math/add-uint48-overflow');
  }

  function addUint256(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require((z = x + y) >= x, 'Math/add-uint256-overflow');
  }

  function subtract(int256 x, int256 y) internal pure returns (int256 z) {
    z = x - y;
    require(y <= 0 || z <= x, 'Math/sub-int-int-overflow');
    require(y >= 0 || z >= x, 'Math/sub-int-int-underflow');
  }

  function subtract(uint256 x, int256 y) internal pure returns (uint256 z) {
    if (y > 0) {
      z = x - uint256(y);
    } else {
      z = x + uint256(-y);
    }
    require(y <= 0 || z <= x, 'Math/sub-uint-int-overflow');
    require(y >= 0 || z >= x, 'Math/sub-uint-int-underflow');
  }

  function subtract(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require((z = x - y) <= x, 'Math/sub-underflow');
  }

  function deduct(uint256 x, uint256 y) internal pure returns (int256 z) {
    z = int256(x) - int256(y);
    require(int256(x) >= 0 && int256(y) >= 0, 'Math/ded-invalid-numbers');
  }

  function multiply(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require(y == 0 || (z = x * y) / y == x, 'Math/mul-overflow');
  }

  function multiply(int256 x, int256 y) internal pure returns (int256 z) {
    require(!(x == -1 && y == INT256_MIN), 'Math/mul-int-int-overflow');
    require(y == 0 || (z = x * y) / y == x, 'Math/mul-int-int-invalid');
  }

  function multiply(uint256 x, int256 y) internal pure returns (int256 z) {
    z = int256(x) * y;
    require(int256(x) >= 0, 'Math/mul-uint-int-null-x');
    require(y == 0 || z / y == int256(x), 'Math/mul-uint-int-overflow');
  }

  function wmultiply(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = multiply(x, y) / WAD;
  }

  function rmultiply(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = x * y;
    require(y == 0 || z / y == x, 'Math/rmul-overflow');
    z = z / RAY;
  }

  function divide(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require(y > 0, 'Math/div-y-null');
    z = x / y;
    require(z <= x, 'Math/div-invalid');
  }

  function rdivide(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require(y > 0, 'Math/rdiv-by-zero');
    z = multiply(x, RAY) / y;
  }

  function wdivide(uint256 x, uint256 y) internal pure returns (uint256 z) {
    require(y > 0, 'Math/wdiv-by-zero');
    z = multiply(x, WAD) / y;
  }

  function rpow(uint256 x, uint256 n, uint256 b) internal pure returns (uint256 z) {
    assembly {
      switch x
      case 0 {
        switch n
        case 0 { z := b }
        default { z := 0 }
      }
      default {
        switch mod(n, 2)
        case 0 { z := b }
        default { z := x }
        let half := div(b, 2) // for rounding.
        for { n := div(n, 2) } n { n := div(n, 2) } {
          let xx := mul(x, x)
          if iszero(eq(div(xx, x), x)) { revert(0, 0) }
          let xxRound := add(xx, half)
          if lt(xxRound, xx) { revert(0, 0) }
          x := div(xxRound, b)
          if mod(n, 2) {
            let zx := mul(z, x)
            if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0, 0) }
            let zxRound := add(zx, half)
            if lt(zxRound, zx) { revert(0, 0) }
            z := div(zxRound, b)
          }
        }
      }
    }
  }

  function rpower(uint256 x, uint256 n, uint256 b) internal pure returns (uint256 z) {
    assembly {
      switch x
      case 0 {
        switch n
        case 0 { z := b }
        default { z := 0 }
      }
      default {
        switch mod(n, 2)
        case 0 { z := b }
        default { z := x }
        let half := div(b, 2) // for rounding.
        for { n := div(n, 2) } n { n := div(n, 2) } {
          let xx := mul(x, x)
          if iszero(eq(div(xx, x), x)) { revert(0, 0) }
          let xxRound := add(xx, half)
          if lt(xxRound, xx) { revert(0, 0) }
          x := div(xxRound, b)
          if mod(n, 2) {
            let zx := mul(z, x)
            if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) { revert(0, 0) }
            let zxRound := add(zx, half)
            if lt(zxRound, zx) { revert(0, 0) }
            z := div(zxRound, b)
          }
        }
      }
    }
  }

  function maximum(uint256 x, uint256 y) internal pure returns (uint256 z) {
    z = (x >= y) ? x : y;
  }

  function minimum(uint256 x, uint256 y) internal pure returns (uint256 z) {
    if (x > y) z = y;
    else z = x;
  }
}

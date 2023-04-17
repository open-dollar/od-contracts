// Copyright (C) 2020 Maker Ecosystem Growth Holdings, INC

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

contract RateSetterMath {
  uint256 public constant RAY = 10 ** 27;
  uint256 public constant WAD = 10 ** 18;

  function ray(uint256 x) public pure returns (uint256 z) {
    z = multiply(x, 10 ** 9);
  }

  function rad(uint256 x) public pure returns (uint256 z) {
    z = multiply(x, 10 ** 27);
  }

  function minimum(uint256 x, uint256 y) public pure returns (uint256 z) {
    z = (x <= y) ? x : y;
  }

  function addition(uint256 x, uint256 y) public pure returns (uint256 z) {
    z = x + y;
    require(z >= x);
  }

  function addition(uint256 x, int256 y) public pure returns (uint256 z) {
    z = x + uint256(y);
    require(y >= 0 || z <= x);
    require(y <= 0 || z >= x);
  }

  function addition(int256 x, int256 y) public pure returns (int256 z) {
    z = x + y;
    require(y >= 0 || z <= x);
    require(y <= 0 || z >= x);
  }

  function subtract(uint256 x, uint256 y) public pure returns (uint256 z) {
    z = x - y;
    require(z <= x);
  }

  function subtract(int256 x, int256 y) public pure returns (int256 z) {
    z = x - y;
    require(y <= 0 || z <= x);
    require(y >= 0 || z >= x);
  }

  function multiply(uint256 x, uint256 y) public pure returns (uint256 z) {
    require(y == 0 || (z = x * y) / y == x);
  }

  function multiply(int256 x, uint256 y) public pure returns (int256 z) {
    require(y == 0 || (z = x * int256(y)) / int256(y) == x);
  }

  function multiply(int256 x, int256 y) public pure returns (int256 z) {
    require(y == 0 || (z = x * y) / y == x);
  }

  function rmultiply(uint256 x, uint256 y) public pure returns (uint256 z) {
    z = multiply(x, y) / RAY;
  }

  function rmultiply(uint256 x, int256 y) public pure returns (int256 z) {
    z = multiply(y, x) / int256(RAY);
  }

  function rdivide(uint256 x, uint256 y) public pure returns (uint256 z) {
    z = multiply(x, RAY) / y;
  }

  function wdivide(uint256 x, uint256 y) public pure returns (uint256 z) {
    z = multiply(x, WAD) / y;
  }

  function wmultiply(uint256 x, uint256 y) public pure returns (uint256 z) {
    z = multiply(x, y) / WAD;
  }

  function wmultiply(int256 x, uint256 y) public pure returns (int256 z) {
    z = multiply(x, y) / int256(WAD);
  }

  function rpower(uint256 x, uint256 n, uint256 base) public pure returns (uint256 z) {
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
}

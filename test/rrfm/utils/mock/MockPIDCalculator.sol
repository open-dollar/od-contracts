// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

contract MockPIDCalculator {
  uint256 constant RAY = 10 ** 27;

  uint256 internal validated = RAY + 2;

  function toggleValidated() public {
    if (validated == 0) {
      validated = RAY + 2;
    } else {
      validated = RAY - 2;
    }
  }

  function computeRate(uint256, uint256) external virtual returns (uint256) {
    return validated;
  }

  function rt(uint256, uint256, uint256) external view virtual returns (uint256) {
    return 31_536_000;
  }

  function perSecondCumulativeLeak() external view virtual returns (uint256) {
    return RAY;
  }

  function timeSinceLastUpdate() external view virtual returns (uint256) {
    return 1;
  }

  function lprad() external view virtual returns (uint256) {
    return RAY;
  }

  function uprad() external view virtual returns (uint256) {
    return RAY;
  }

  function adi() external view virtual returns (uint256) {
    return RAY;
  }

  function adat() external view virtual returns (uint256) {
    return 0;
  }
}

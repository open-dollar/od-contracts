// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface ISafeManager {
  function transferSAFEOwnership(uint256 _safe, address _dst) external;
}

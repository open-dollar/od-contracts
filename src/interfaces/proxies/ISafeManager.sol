// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface ISafeManager {
  function getSafes(address _usr) external view returns (uint256[] memory _safes);
  function transferSAFEOwnership(uint256 _safe, address _dst) external;
}

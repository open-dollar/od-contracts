// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface ISafeManager {
  struct SAFEData {
    address owner;
    address safeHandler;
    bytes32 collateralType;
  }

  function safeEngine() external returns (address _safeEngine);
  function transferSAFEOwnership(uint256 _safe, address _dst) external;
  function safeData(uint256 _safe) external view returns (SAFEData memory _sData);
}

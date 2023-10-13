// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

// TODO: delete this, replace with AlgebraV1 forge lib import

interface IAlgebraPool {
  function token0() external view returns (address);
  function token1() external view returns (address);
  function initialize(uint160 initPrice) external;
  function globalState()
    external
    view
    returns (
      uint160 price,
      int24 tick,
      uint16 feeZto,
      uint16 feeOtz,
      uint16 timepointIndex,
      uint8 communityFeeToken0,
      uint8 communityFeeToken1,
      bool unlocked
    );
  function dataStorageOperator() external returns (address);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IOracle {
  function priceSource() external view returns (address _priceSource);
  function getResultWithValidity() external view returns (uint256 _result, bool _validity);
  function read() external view returns (uint256 _value);
}

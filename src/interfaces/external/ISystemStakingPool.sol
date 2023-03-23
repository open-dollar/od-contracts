// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface ISystemStakingPool {
  function canPrintProtocolTokens() external view returns (bool _canPrintProtocolTokens);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

contract ChainlinkUptimeFeedForTestnet {
  function latestRoundData() external pure returns (uint256, int256 _answer, uint256, uint256, uint256) {
    _answer = 1;
  }
}

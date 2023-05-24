// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IChainlinkOracle {
  function decimals() external view returns (uint8);
  function description() external view returns (string memory);
  function getAnswer(uint256 _roundId) external view returns (int256);
  function getRoundData(uint256 __roundId)
    external
    view
    returns (uint256 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint256 _answeredInRound);
  function getTimestamp(uint256 _roundId) external view returns (uint256);
  function latestAnswer() external view returns (int256);
  function latestRound() external view returns (uint256);
  function latestRoundData()
    external
    view
    returns (uint256 _roundId, int256 _answer, uint256 _startedAt, uint256 _updatedAt, uint256 _answeredInRound);
  function latestTimestamp() external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface IChainlinkRelayerFactory is IAuthorizable {
  // --- Events ---
  event NewChainlinkRelayer(address indexed _chainlinkRelayer, address _aggregator, uint256 _staleThreshold);

  // --- Methods ---
  function deployChainlinkRelayer(
    address _aggregator,
    uint256 _staleThreshold
  ) external returns (IBaseOracle _chainlinkRelayer);

  // --- Views ---
  function chainlinkRelayersList() external view returns (address[] memory _chainlinkRelayersList);
}

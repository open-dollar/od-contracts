// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface IChainlinkRelayerFactory is IAuthorizable {
  // --- Events ---

  /**
   * @notice Emitted when a new ChainlinkRelayer contract is deployed
   * @param _chainlinkRelayer Address of the deployed ChainlinkRelayer contract
   * @param _aggregator Address of the aggregator to be used by the ChainlinkRelayer contract
   * @param _staleThreshold Stale threshold to be used by the ChainlinkRelayer contract
   */
  event NewChainlinkRelayer(address indexed _chainlinkRelayer, address _aggregator, uint256 _staleThreshold);

  // --- Methods ---

  /**
   * @notice Deploys a new ChainlinkRelayer contract
   * @param _aggregator Address of the aggregator to be used by the ChainlinkRelayer contract
   * @param _staleThreshold Stale threshold to be used by the ChainlinkRelayer contract
   * @return _chainlinkRelayer Address of the deployed ChainlinkRelayer contract
   */
  function deployChainlinkRelayer(
    address _aggregator,
    uint256 _staleThreshold
  ) external returns (IBaseOracle _chainlinkRelayer);

  // --- Views ---

  /**
   * @notice Getter for the list of ChainlinkRelayer contracts
   * @return _chainlinkRelayersList List of ChainlinkRelayer contracts
   */
  function chainlinkRelayersList() external view returns (address[] memory _chainlinkRelayersList);
}

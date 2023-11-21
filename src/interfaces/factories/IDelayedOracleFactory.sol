// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface IDelayedOracleFactory is IAuthorizable {
  // --- Events ---

  /**
   * @notice Emitted when a new DelayedOracle contract is deployed
   * @param _delayedOracle Address of the deployed DelayedOracle contract
   * @param _priceSource Address of the price source for the DelayedOracle contract
   * @param _updateDelay Delay in seconds to be applied between the price source and the delayed oracle feeds
   */
  event NewDelayedOracle(address indexed _delayedOracle, address _priceSource, uint256 _updateDelay);

  // --- Methods ---

  /**
   * @notice Deploys a new DelayedOracle contract
   * @param _priceSource Address of the price source for the DelayedOracle contract
   * @param _updateDelay Delay in seconds to be applied between the price source and the delayed oracle feeds
   * @return _delayedOracle Address of the deployed DelayedOracle contract
   */
  function deployDelayedOracle(
    IBaseOracle _priceSource,
    uint256 _updateDelay
  ) external returns (IDelayedOracle _delayedOracle);

  // --- Views ---

  /**
   * @notice Getter for the list of DelayedOracle contracts
   * @return _delayedOraclesList List of DelayedOracle contracts
   */
  function delayedOraclesList() external view returns (address[] memory _delayedOraclesList);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface IChainlinkRelayerFactory is IAuthorizable {
  // --- Events ---

  /**
   * @notice Emitted when a new ChainlinkRelayer contract is deployed
   * @param _chainlinkRelayer Address of the deployed ChainlinkRelayer contract
   * @param _priceFeed Address of the price feed to be used by the ChainlinkRelayer contract
   * @param _sequencerUptimeFeed Address of the sequencer uptime feed to be used by the ChainlinkRelayer contract
   * @param _staleThreshold Stale threshold to be used by the ChainlinkRelayer contract
   */
  event NewChainlinkRelayer(
    address indexed _chainlinkRelayer, address _priceFeed, address _sequencerUptimeFeed, uint256 _staleThreshold
  );

  // --- Errors ---

  /// @notice Throws if the provided sequencer uptime feed address is null
  error ChainlinkRelayerFactory_NullSequencerUptimeFeed();

  // --- Registry ---

  /// @notice Address of the Chainlink sequencer uptime feed used to consult the sequencer status
  function sequencerUptimeFeed() external view returns (IChainlinkOracle _sequencerUptimeFeed);

  // --- Methods ---

  /**
   * @notice Deploys a new ChainlinkRelayer contract
   * @param _priceFeed Address of the price feed to be used by the ChainlinkRelayer contract
   * @param _staleThreshold Stale threshold to be used by the ChainlinkRelayer contract
   * @return _chainlinkRelayer Address of the deployed ChainlinkRelayer contract
   */
  function deployChainlinkRelayer(
    address _priceFeed,
    uint256 _staleThreshold
  ) external returns (IBaseOracle _chainlinkRelayer);

  // --- Views ---

  /**
   * @notice Getter for the list of ChainlinkRelayer contracts
   * @return _chainlinkRelayersList List of ChainlinkRelayer contracts
   */
  function chainlinkRelayersList() external view returns (address[] memory _chainlinkRelayersList);

  // --- Administration ---

  /**
   * @notice Sets the Chainlink sequencer uptime feed contract address
   * @param _sequencerUptimeFeed The address of the Chainlink sequencer uptime feed
   */
  function setSequencerUptimeFeed(address _sequencerUptimeFeed) external;
}

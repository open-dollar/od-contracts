// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IChainlinkRelayerFactory} from '@interfaces/factories/IChainlinkRelayerFactory.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';

import {ChainlinkRelayerChild} from '@contracts/factories/ChainlinkRelayerChild.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

/**
 * @title  ChainlinkRelayerFactory
 * @notice This contract is used to deploy ChainlinkRelayer contracts
 * @dev    The deployed contracts are ChainlinkRelayerChild instances
 */
contract ChainlinkRelayerFactory is Authorizable, IChainlinkRelayerFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  // --- Registry ---

  /// @inheritdoc IChainlinkRelayerFactory
  IChainlinkOracle public sequencerUptimeFeed;

  // --- Data ---

  /// @notice The enumerable set of deployed ChainlinkRelayer contracts
  EnumerableSet.AddressSet internal _chainlinkRelayers;

  // --- Init ---

  /**
   * @param  _sequencerUptimeFeed The address of the Chainlink sequencer uptime feed
   */
  constructor(address _sequencerUptimeFeed) Authorizable(msg.sender) {
    _setSequencerUptimeFeed(_sequencerUptimeFeed);
  }

  // --- Methods ---

  /// @inheritdoc IChainlinkRelayerFactory
  function deployChainlinkRelayer(
    address _priceFeed,
    uint256 _staleThreshold
  ) external isAuthorized returns (IBaseOracle _chainlinkRelayer) {
    _chainlinkRelayer = new ChainlinkRelayerChild(_priceFeed, address(sequencerUptimeFeed), _staleThreshold);
    _chainlinkRelayers.add(address(_chainlinkRelayer));
    emit NewChainlinkRelayer(address(_chainlinkRelayer), _priceFeed, address(sequencerUptimeFeed), _staleThreshold);
  }

  // --- Views ---

  /// @inheritdoc IChainlinkRelayerFactory
  function chainlinkRelayersList() external view returns (address[] memory _chainlinkRelayersList) {
    return _chainlinkRelayers.values();
  }

  // --- Administration ---

  /// @inheritdoc IChainlinkRelayerFactory
  function setSequencerUptimeFeed(address _sequencerUptimeFeed) external isAuthorized {
    _setSequencerUptimeFeed(_sequencerUptimeFeed);
  }

  function _setSequencerUptimeFeed(address _sequencerUptimeFeed) internal {
    if (_sequencerUptimeFeed == address(0)) revert ChainlinkRelayerFactory_NullSequencerUptimeFeed();
    sequencerUptimeFeed = IChainlinkOracle(_sequencerUptimeFeed);
  }
}

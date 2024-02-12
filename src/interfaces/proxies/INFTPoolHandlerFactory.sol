// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {BeaconProxy} from '@openzeppelin/proxy/beacon/BeaconProxy.sol';
import {UpgradeableBeacon} from '@openzeppelin/proxy/beacon/UpgradeableBeacon.sol';

interface INFTPoolHandlerFactory {
  /**
   * @dev Emitted when a new NFTPoolHandler is created
   * @param instance Address of the new NFTPoolHandler
   */
  event NFTPoolHandlerCreated(address indexed instance);

  /**
   * @dev Creates a new NFTPoolHandler
   * @return instance Address of the new NFTPoolHandler
   */
  function createNFTPoolHandler() external returns (address instance);

  /**
   * @dev Returns the address of the NFTHandler beacon
   * @return NFTHandlerBeacon The UpgradeableBeacon instance
   */
  function NFT_POOL_HANDLER_BEACON() external view returns (UpgradeableBeacon NFTHandlerBeacon);

  /**
   * @dev Returns the address of the beacon implementation
   * @return beaconImplementation The address of the beacon implementation contract
   */
  function getBeaconImplementation() external view returns (address beaconImplementation);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {INFTPoolHandlerFactory} from '@interfaces/proxies/INFTPoolHandlerFactory.sol';
import {BeaconProxy} from '@openzeppelin/proxy/beacon/BeaconProxy.sol';
import {UpgradeableBeacon} from '@openzeppelin/proxy/beacon/UpgradeableBeacon.sol';

contract NFTPoolHandlerFactory is INFTPoolHandlerFactory {
  UpgradeableBeacon public immutable NFT_POOL_HANDLER_BEACON;

  constructor(address implementation) {
    NFT_POOL_HANDLER_BEACON = new UpgradeableBeacon(implementation);

    // deployer is the owner of the beacon
    NFT_POOL_HANDLER_BEACON.transferOwnership(msg.sender);
  }

  /// @inheritdoc INFTPoolHandlerFactory
  function createNFTPoolHandler() external returns (address instance) {
    instance = address(new BeaconProxy(address(NFT_POOL_HANDLER_BEACON), ''));
    emit NFTPoolHandlerCreated(instance);
  }

  /// @inheritdoc INFTPoolHandlerFactory
  function getBeaconImplementation() public view returns (address) {
    return NFT_POOL_HANDLER_BEACON.implementation();
  }
}

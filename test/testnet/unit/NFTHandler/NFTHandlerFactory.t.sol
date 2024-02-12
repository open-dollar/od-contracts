// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';
import {UpgradeableBeacon} from '@openzeppelin/proxy/beacon/UpgradeableBeacon.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';

import {NFTPoolHandlerFactory, INFTPoolHandlerFactory} from '@contracts/proxies/NFTPoolHandlerFactory.sol';
import {NFTPoolHandler} from '@contracts/proxies/NFTPoolHandler.sol';

contract NFTHandlerFactory is Test {
  event NFTPoolHandlerCreated(address indexed instance);

  NFTPoolHandlerFactory factory;
  NFTPoolHandler beaconLogic;
  ODProxy odProxy;

  function setUp() public {
    beaconLogic = new NFTPoolHandler(address(101), address(110));
    factory = new NFTPoolHandlerFactory(address(beaconLogic));
    odProxy = new ODProxy(address(this));
  }

  function testInitializeBeaconLogic() public {
    vm.expectRevert('Initializable: contract is already initialized');
    beaconLogic.initialize(odProxy);
  }

  function testBeaconLogicIsCorrectlySet() public {
    assertEq(address(beaconLogic), factory.getBeaconImplementation(), 'beacon logic incorrectly set');
  }

  function testBeaconIsCorrectlyDeployed() public {
    assertFalse(address(factory.NFT_POOL_HANDLER_BEACON()) == address(0), 'beacon incorrectly deployed');
    assertEq(
      factory.NFT_POOL_HANDLER_BEACON().implementation(), address(beaconLogic), 'beacon implementation incorrectly set'
    );

    // deployer is owner of the beacon
    assertEq(factory.NFT_POOL_HANDLER_BEACON().owner(), address(this), 'beacon owner incorrectly set');
  }

  function testCreateNFTPoolHandlerEvent() public {
    address instance = factory.createNFTPoolHandler();

    NFTPoolHandler(instance).initialize(odProxy);

    assertEq(NFTPoolHandler(instance).proxyOwner(), address(odProxy.OWNER()), 'proxy owner not set correctly');

    assertEq(address(NFTPoolHandler(instance).odProxy()), address(odProxy), 'ODProxy not set correctly');

    assertEq(address(NFTPoolHandler(instance).nftPool()), address(101), 'nftPool not set correctly');

    assertEq(address(NFTPoolHandler(instance).router()), address(110), 'router not set correctly');
  }
}

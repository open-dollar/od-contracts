// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestHelperScript} from './TestHelper.s.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';

// source .env && forge script OpenSafe --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY

contract OpenSafe is TestHelperScript {
  function run() public {
    vm.startBroadcast(vm.envUint('OP_GOERLI_PK'));
    address proxy = address(findOrDeploy(USER));
    openSafe(OP, proxy);
    vm.stopBroadcast();
  }

  function openSafe(bytes32 cType, address dsProxy) public returns (bytes memory) {
    (bool success, bytes memory data) = address(basicActions).delegatecall(
      abi.encodeWithSignature('openSAFE(address,bytes32,address)', address(safeManager), cType, dsProxy)
    );
    require(success, 'Delegate call to BasicActions.openSAFE error');
    return data;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestHelperScript1} from '@script/test/utils/TestHelper1.s.sol';
import {TestHelperScript2} from '@script/test/utils/TestHelper2.s.sol';

// source .env && forge script DeployProxy --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY

contract DeployProxy is TestHelperScript2 {
  function run() public {
    vm.startBroadcast(vm.envUint('OP_GOERLI_PK'));
    deploy();
    vm.stopBroadcast();
  }

  /**
   * @dev this function calls the proxyFactory directly,
   * therefore it bypasses the proxyRegistry and proxy address
   * will not be saved in the proxyRegistry mapping
   */
  function deploy() public returns (address payable) {
    return proxyFactory.build();
  }
}

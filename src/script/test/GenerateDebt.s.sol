// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestHelperScript1} from '@script/test/utils/TestHelper1.s.sol';
import {TestHelperScript2} from '@script/test/utils/TestHelper2.s.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';

// source .env && forge script GenerateDebt --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY
// source .env && forge script GenerateDebt --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC

contract GenerateDebt is TestHelperScript2 {
  function run() public {
    vm.startBroadcast(vm.envUint('OP_GOERLI_PK'));
    address proxy = address(deployOrFind(USER2));

    genDebt(12, 50 ether, proxy);
    vm.stopBroadcast();
  }

  function genDebt(uint256 _safeId, uint256 _deltaWad, address _proxy) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.generateDebt.selector,
      address(safeManager),
      address(taxCollector),
      address(coinJoin),
      _safeId,
      _deltaWad
    );
    HaiProxy(_proxy).execute(address(basicActions), payload);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestHelperScript1} from '@script/test/utils/TestHelper1.s.sol';
import {TestHelperScript2} from '@script/test/utils/TestHelper2.s.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';

// source .env && forge script OpenSafe --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY
// source .env && forge script OpenSafe --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC

contract OpenSafe is TestHelperScript2 {
  function run() public {
    vm.startBroadcast(vm.envUint('OP_GOERLI_PK'));
    address proxy = address(deployOrFind(USER2));
    openSafe(WETH, proxy);
    vm.stopBroadcast();
  }

  function openSafe(bytes32 _cType, address _proxy) public returns (uint256 _safeId) {
    bytes memory payload = abi.encodeWithSelector(basicActions.openSAFE.selector, address(safeManager), _cType, _proxy);
    bytes memory safeData = HaiProxy(_proxy).execute(address(basicActions), payload);
    _safeId = abi.decode(safeData, (uint256));
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestHelperScript1} from '@script/test/utils/TestHelper1.s.sol';
import {TestHelperScript2} from '@script/test/utils/TestHelper2.s.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';

// source .env && forge script LockCollateral --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY
// source .env && forge script LockCollateral --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC

contract LockCollateral is TestHelperScript2 {
  function run() public {
    vm.startBroadcast(vm.envUint('OP_GOERLI_PK'));
    address proxy = address(deployOrFind(USER2));
    wEthToken.approve(address(proxy), 0.01 ether);

    depositCollatAndGenDebt(12, 0.0001 ether, proxy);
    vm.stopBroadcast();
  }

  /**
   * @dev `lockTokenCollateral` currently has a bug and call will revert
   */
  function depositCollat(uint256 _safeId, uint256 _wad, address _proxy) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.lockTokenCollateral.selector, address(safeManager), address(collateralJoin[WETH]), _safeId, _wad
    );
    HaiProxy(_proxy).execute(address(basicActions), payload);
  }

  function depositCollatAndGenDebt(uint256 _safeId, uint256 _collatAmount, address _proxy) public {
    uint256 deltaWad = 0;

    bytes memory payload = abi.encodeWithSelector(
      basicActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(taxCollector),
      address(collateralJoin[WETH]),
      address(coinJoin),
      _safeId,
      _collatAmount,
      deltaWad
    );
    HaiProxy(_proxy).execute(address(basicActions), payload);
  }
}

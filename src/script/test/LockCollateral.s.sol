// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TestHelperScript1} from '@script/test/utils/TestHelper1.s.sol';
import {TestHelperScript2} from '@script/test/utils/TestHelper2.s.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';

// source .env && forge script DepositSafe2 --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC --broadcast --verify --etherscan-api-key $OP_ETHERSCAN_API_KEY
// source .env && forge script DepositSafe2 --with-gas-price 2000000000 -vvvvv --rpc-url $OP_GOERLI_RPC

contract DepositSafe2 is TestHelperScript1 {
  function run() public {
    vm.startBroadcast(vm.envUint('OP_GOERLI_PK'));
    address proxy = address(deployOrFind(USER2));
    wEthToken.approve(address(proxy), 0.01 ether);

    depositCollatAndGenDebt(1, 0.0001 ether, proxy);
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
// tx data
// 0x1cff79cd0000000000000000000000000c3287b5c1ea5b04e90a3d1af02b78544b33f573000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e47a4d9a47000000000000000000000000c0c6e2e5a31896e888ebef5837bb70cb3c37d86c00000000000000000000000018059871ea044bfe1e92f5ef0d5d6e621160c94d000000000000000000000000fb0758b07b4260958cb1589091489e2a2d9af513000000000000000000000000fc63f2cfbfb09131a87452df713e84885fff9466574554480000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005af3107a4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

// function lockTokenCollateralAndGenerateDebt(
//   address _manager,
//   address _taxCollector,
//   address _collateralJoin,
//   address _coinJoin,
//   uint256 _safe,
//   uint256 _collateralAmount,
//   uint256 _deltaWad,
//   bool _transferFrom

//   bytes memory _callData = abi.encodeWithSelector(
//     BasicActions.lockTokenCollateralAndGenerateDebt.selector,
//     address(safeManager),
//     address(taxCollector),
//     address(collateralJoin[_cType]),
//     address(coinJoin),
//     _safeId,
//     _collatAmount,
//     _deltaDebt // wad
//   );

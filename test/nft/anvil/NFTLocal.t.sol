// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {AnvilFork} from '@test/nft/anvil/AnvilFork.t.sol';
import {WSTETH, ARB, CBETH, RETH, MAGIC} from '@script/GoerliParams.s.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';

// forge t --fork-url $URL --match-contract NFTAnvil -vvvvv

contract NFTAnvil is AnvilFork {
  using SafeERC20 for IERC20;

  function test_openSafe_WETH() public {
    vm.startPrank(ALICE);

    uint256 safeId = openSafe(WSTETH, aProxy);
    assertEq(safeId, 1);

    address ownerOfToken = Vault721(vault721).ownerOf(safeId);
    assertEq(ownerOfToken, ALICE);
    vm.stopPrank();
  }
}

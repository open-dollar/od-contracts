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

  // fuzz tests set to 256 runs
  function test_depositCollateral(uint256 amount) public {
    vm.assume(amount <= MINT_AMOUNT);

    vm.startPrank(ALICE);
    depositCollatAndGenDebt(WSTETH, 1, amount, 0, aProxy);
    vm.stopPrank();

    vm.startPrank(BOB);
    depositCollatAndGenDebt(WSTETH, 2, amount, 0, bProxy);
    vm.stopPrank();

    vm.startPrank(CASSY);
    depositCollatAndGenDebt(WSTETH, 3, amount, 0, cProxy);
    vm.stopPrank();
  }
}

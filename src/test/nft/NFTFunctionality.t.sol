// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {GoerliForkSetup} from '@test/nft/GoerliForkSetup.t.sol';
import {GoerliParams, WETH, OP, WBTC, STONES, TOTEM} from '@script/GoerliParams.s.sol';
import {ARB_GOERLI_WETH, ARB_GOERLI_GOV_TOKEN} from '@script/Registry.s.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';

// forge t --fork-url $URL --match-contract NFTFunctionality -vvv

contract NFTFunctionality is GoerliForkSetup {
  using SafeERC20 for IERC20;

  function test_openSafe() public {
    vm.startPrank(alice);

    uint256 safeId = openSafe(WETH, aliceProxy);
    assertEq(safeId, 1);

    address ownerOfToken = Vault721(vault721).ownerOf(safeId);
    assertEq(ownerOfToken, alice);
    vm.stopPrank();
  }

  function test_openSafe_lockCollateral_WETH() public {
    vm.startPrank(alice);

    uint256 safeId = openSafe(WETH, aliceProxy);
    assertEq(safeId, 1);

    IERC20(ARB_GOERLI_WETH).approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(WETH, 1, 0.0001 ether, 0, aliceProxy);
    vm.stopPrank();
  }

  function test_openSafe_lockCollateral_generateDebt_WETH() public {
    vm.startPrank(alice);

    uint256 safeId = openSafe(WETH, aliceProxy);
    assertEq(safeId, 1);

    IERC20(ARB_GOERLI_WETH).approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(WETH, 1, 0.4 ether, 300 ether, aliceProxy);
    vm.stopPrank();
  }

  function test_openSafe_lockCollateral_OP() public {
    vm.startPrank(alice);

    uint256 safeId = openSafe(OP, aliceProxy);
    assertEq(safeId, 1);

    IERC20(ARB_GOERLI_GOV_TOKEN).approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(OP, 1, 125 ether, 0, aliceProxy);
    vm.stopPrank();
  }

  function test_openSafe_lockCollateral_generateDebt_OP() public {
    vm.startPrank(alice);

    uint256 safeId = openSafe(OP, aliceProxy);
    assertEq(safeId, 1);

    IERC20(ARB_GOERLI_GOV_TOKEN).approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(OP, 1, 125 ether, 75 ether, aliceProxy);
    vm.stopPrank();
  }

  function test_openSafe_lockCollateral_transfer_WETH() public {
    vm.startPrank(alice);

    uint256 safeId = openSafe(WETH, aliceProxy);
    assertEq(safeId, 1);

    IERC20(ARB_GOERLI_WETH).approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(WETH, 1, 0.0001 ether, 0, aliceProxy);

    Vault721(vault721).transferFrom(alice, bob, 1);

    uint256 nftBalAlice = Vault721(vault721).balanceOf(alice);
    uint256 nftBalBob = Vault721(vault721).balanceOf(bob);

    assertEq(nftBalAlice, 0);
    assertEq(nftBalBob, 1);
    vm.stopPrank();
  }

  function test_openSafe_lockCollateral_generateDebt_transfer_OP() public {
    vm.startPrank(alice);

    uint256 safeId = openSafe(OP, aliceProxy);
    assertEq(safeId, 1);

    IERC20(ARB_GOERLI_GOV_TOKEN).approve(aliceProxy, type(uint256).max);
    depositCollatAndGenDebt(OP, 1, 125 ether, 75 ether, aliceProxy);

    Vault721(vault721).transferFrom(alice, bob, 1);

    uint256 nftBalAlice = Vault721(vault721).balanceOf(alice);
    uint256 nftBalBob = Vault721(vault721).balanceOf(bob);

    assertEq(nftBalAlice, 0);
    assertEq(nftBalBob, 1);
    vm.stopPrank();
  }
}

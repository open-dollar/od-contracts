// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {NFTPool} from '@contracts/for-test/CamelotDex/NFTPool.sol';
import {NitroPool} from '@contracts/for-test/CamelotDex/NitroPool.sol';
import {INFTHandler} from '@contracts/for-test/CamelotDex/interfaces/INFTHandler.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/token/ERC721/IERC721.sol';
import {ERC20} from '@openzeppelin/token/ERC20/ERC20.sol';
import {ICamelotMaster} from '@contracts/for-test/CamelotDex/interfaces/ICamelotMaster.sol';
import {IXGrailToken} from '@contracts/for-test/CamelotDex/interfaces/tokens/IXGrailToken.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';

import {NFTPoolProxyHandler} from '@contracts/proxies/NFTPoolProxyHandler.sol';

contract NFTPoolForkTestV3 is Test {
  // for V3 tests

  uint256 ARBITRUM_BLOCK_V3 = 177_397_592;

  address IMPERSONATOR_ADDR_V3 = 0xF482881968D1F1D99397310636fF9FaC070f63C6; // random address that have NFT position
  uint256 IMPERSONATOR_NFT_ID_V3 = 1800; // random address that have NFT position
  address CAMELOT_ROUTER_V3 = 0x1F721E2E82F6676FCE4eA07A5958cF098D339e18; // Camelot Router (Uniswap v3)
  // address POOL_ADDR_V3 = 0x83F210dDa8D968094a8ea2a27E2A16D2b364c78A; // AlgebraPool
  address POOL_ADDR_V3 = 0x00c7f3082833e796A5b3e4Bd59f6642FF44DCD15; // NonfungiblePositionManager
  address TOKEN_0_V3 = 0x3d9907F9a368ad0a51Be60f7Da3b97cf940982D8; // Camelot Token
  address TOKEN_1_V3 = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8; // USDC

  //NFT POSITION MANAGER 0x00c7f3082833e796a5b3e4bd59f6642ff44dcd15

  NFTPool nftPool;
  ODProxy odProxy;
  NFTPoolProxyHandler nftHandler;
  IERC20 tokenPair;

  function setUp() public {
    // --- Arbitrum Fork ---
    uint256 forkId = vm.createFork(vm.rpcUrl('mainnet'));
    vm.selectFork(forkId);
    vm.rollFork(ARBITRUM_BLOCK_V3);

    // --- CamelotDex ---
    nftPool = NFTPool(POOL_ADDR_V3);

    // fund impersonator account
    vm.deal(IMPERSONATOR_ADDR_V3, 100 ether);

    // deploy ODProxy
    odProxy = __deployODProxy();

    // deploy NFTHandler
    nftHandler = __deployNFTHandler(odProxy);
  }

  // Helper functions
  function __deployODProxy() internal returns (ODProxy odProxy) {
    vm.startPrank(IMPERSONATOR_ADDR_V3);
    odProxy = new ODProxy(IMPERSONATOR_ADDR_V3);
    assertEq(odProxy.OWNER(), IMPERSONATOR_ADDR_V3);
  }

  function __deployNFTHandler(ODProxy odProxy) internal returns (NFTPoolProxyHandler nftHandler) {
    nftHandler = new NFTPoolProxyHandler(odProxy, address(nftPool), CAMELOT_ROUTER_V3);
    assertEq(address(nftHandler.odProxy()), address(odProxy));
    assertEq(address(nftHandler.nftPool()), address(nftPool));
    assertEq(nftHandler.proxyOwner(), IMPERSONATOR_ADDR_V3);
  }

  function testWithdrawPositionV3() public {
    // setup scenario: impersonator withdraws NFT from NFTHandler
    vm.startPrank(IMPERSONATOR_ADDR_V3);

    // ERC721 approve nftHandler
    IERC721(POOL_ADDR_V3).approve(address(nftHandler), IMPERSONATOR_NFT_ID_V3);
    // check if account is owner of token
    assertEq(IERC721(POOL_ADDR_V3).ownerOf(IMPERSONATOR_NFT_ID_V3), IMPERSONATOR_ADDR_V3);
    // nftHandler withdraws position
    nftHandler.withdrawFromPositionV3(IMPERSONATOR_NFT_ID_V3, 0, 0);

    assertTrue(IERC20(TOKEN_0_V3).balanceOf(address(odProxy)) == 0);
    assertTrue(IERC20(TOKEN_1_V3).balanceOf(address(odProxy)) > 0);
  }
}

contract NFTPoolNitroTest is Test {

  address ARBTIRUM_NFTPOOL_ADDR = 0x4576a5cB734B65766Db336D7E0AE0188FE47cB92;
  address ARBTIRUM_NITROPOOL_ADDR = 0x4391D56A8E56BE1fB30a45bAa0E5B7a4b488FbAa;
  uint256 ARBTIRUM_BLOCK = 176_391_391;

  address IMPERSONATOR_ADDR_V2 = 0x8cc44a3Fe63E844f37CeE1C91f7b5bc4aD26639e; // random address that have NFT position
  uint256 IMPERSONATOR_NFT_ID_V2 = 1;

  address CAMELOT_ROUTER_V2 = 0xc873fEcbd354f5A56E00E710B90EF4201db2448d; // Camelot Router (Uniswap v2)
  address POOL_ADDR_V2 = 0x913398d79438e8D709211cFC3DC8566F6C67e1A8; // CamelotDex pair token

  address TOKEN_0_V2 = 0xE5A21382f6ef9c3B6F873f69d583fFD3b91449F0; // Test wsTEth
  address TOKEN_1_V2 = 0x0dc0caB40adDB6694B089dEdfC35B694a9B60Aac; // Test ODG Reward token to the user that deposit

  NFTPool nftPool;
  NitroPool nitroPool;
  ODProxy odProxy;
  NFTPoolProxyHandler nftHandler;
  IERC20 tokenPair;

  function setUp() public {
    // --- Arbitrum Fork ---

    uint256 forkId = vm.createFork(vm.rpcUrl('mainnet'));
    vm.selectFork(forkId);
    vm.rollFork(ARBTIRUM_BLOCK);

    // --- CamelotDex ---
    nftPool = NFTPool(ARBTIRUM_NFTPOOL_ADDR);

    // --- NitroPool ---
    nitroPool = NitroPool(ARBTIRUM_NITROPOOL_ADDR);

    // fund impersonator account
    vm.deal(IMPERSONATOR_ADDR_V2, 100 ether);

    // deploy ODProxy
    odProxy = __deployODProxy();

    // deploy NFTHandler
    nftHandler = __deployNFTHandler(odProxy);
  }

  function testImpersonatorState() public {
    // check if NFT ownership is NitroPool
    assertEq(nftPool.ownerOf(IMPERSONATOR_NFT_ID_V2), ARBTIRUM_NITROPOOL_ADDR);
    // check impersonator eth balance
    assertEq(100 ether, IMPERSONATOR_ADDR_V2.balance);

    // check is IMPERSONATOR_ADDR_V2 as allowance of NFT
    assertEq(nftPool.getApproved(IMPERSONATOR_NFT_ID_V2), IMPERSONATOR_ADDR_V2);
  }

  function testWithdrawFromNitroPool() public {
    // setup scenario: impersonator withdraws NFT from NitroPool
    __getNFTFromNitroPool();
  }

  function testTransferToNFTHandler() public {
    // setup scenario: impersonator transfers NFT to NFTHandler
    __getNFTFromNitroPool();
    vm.startPrank(IMPERSONATOR_ADDR_V2);
    // approve NFTHandler to transfer NFT
    nftPool.approve(address(nftHandler), IMPERSONATOR_NFT_ID_V2);
    assertEq(nftPool.getApproved(IMPERSONATOR_NFT_ID_V2), address(nftHandler));
    // transfer NFT to NFTHandler
    nftHandler.transferFrom(IMPERSONATOR_ADDR_V2, IMPERSONATOR_NFT_ID_V2);
    // check NFT ownership
    assertEq(nftPool.ownerOf(IMPERSONATOR_NFT_ID_V2), address(nftHandler));
  }

  function testApproveAndTransferToNFTHandler() public {
    // setup scenario: impersonator approves NFTHandler to transfer NFT, then transfers NFT to NFTHandler
    __getNFTFromNitroPool();
    vm.startPrank(IMPERSONATOR_ADDR_V2);
    // approve NFTHandler to transfer NFT
    nftPool.approve(address(nftHandler), IMPERSONATOR_NFT_ID_V2);
    assertEq(nftPool.getApproved(IMPERSONATOR_NFT_ID_V2), address(nftHandler));
    // transfer NFT to NFTHandler
    nftHandler.transferFrom(IMPERSONATOR_ADDR_V2, IMPERSONATOR_NFT_ID_V2);
    // check NFT ownership
    assertEq(nftPool.ownerOf(IMPERSONATOR_NFT_ID_V2), address(nftHandler));
  }

  function testTransferToNFTHandlerWithoutApproval() public {
    // setup scenario: impersonator transfers NFT to NFTHandler without approval
    __getNFTFromNitroPool();
    vm.startPrank(IMPERSONATOR_ADDR_V2);
    // transfer NFT to NFTHandler
    nftPool.safeTransferFrom(IMPERSONATOR_ADDR_V2, address(nftHandler), IMPERSONATOR_NFT_ID_V2);
    // check NFT ownership
    assertEq(nftPool.ownerOf(IMPERSONATOR_NFT_ID_V2), address(nftHandler));
  }

  function testWithdrawPositionV2() public {
    // setup scenario: impersonator withdraws NFT from NFTHandler

    // Step one: get NFT from NitroPool to CamelotDex itself
    __getNFTFromNitroPool();

    vm.startPrank(IMPERSONATOR_ADDR_V2);


    // ODProxy don't have any tokens
    assertEq(IERC20(TOKEN_0_V2).balanceOf(address(odProxy)), 0);

    // Step two: transfer NFT to NFTHandler
    // transfer NFT to NFTHandler

    // change to approve/transfer pattern
    nftPool.safeTransferFrom(IMPERSONATOR_ADDR_V2, address(nftHandler), IMPERSONATOR_NFT_ID_V2);

    // get stake position from CamelotDex
    (,,uint256 startLockTime,uint256 lockDuration,,,,) = nftPool.getStakingPosition(IMPERSONATOR_NFT_ID_V2);

    // move timestamp above lockDuration
    vm.warp(startLockTime + lockDuration + 1);

    // Step three: withdraw position
    // nftHandler withdraws position
    nftHandler.withdrawFromPositionV2(IMPERSONATOR_NFT_ID_V2, 1, 1);

    // at this phase the NFT should be burned
    assertFalse(nftPool.exists(IMPERSONATOR_NFT_ID_V2));

    // ODProxy should have token
    assertEq(IERC20(TOKEN_0_V2).balanceOf(address(odProxy)), 10 ether);
  }

  // Helper functions
  function __deployODProxy() internal returns (ODProxy odProxy) {
    vm.startPrank(IMPERSONATOR_ADDR_V2);
    odProxy = new ODProxy(IMPERSONATOR_ADDR_V2);
    assertEq(odProxy.OWNER(), IMPERSONATOR_ADDR_V2);
  }

  function __deployNFTHandler(ODProxy odProxy) internal returns (NFTPoolProxyHandler nftHandler) {
    nftHandler = new NFTPoolProxyHandler(odProxy, address(nftPool), CAMELOT_ROUTER_V2);
    assertEq(address(nftHandler.odProxy()), address(odProxy));
    assertEq(address(nftHandler.nftPool()), address(nftPool));
    assertEq(nftHandler.proxyOwner(), IMPERSONATOR_ADDR_V2);
  }

  function __getNFTFromNitroPool() internal {
    // setup scenario: impersonator withdraws NFT from NitroPool
    vm.startPrank(IMPERSONATOR_ADDR_V2);
    // check NFT ownership
    assertEq(nftPool.ownerOf(IMPERSONATOR_NFT_ID_V2), ARBTIRUM_NITROPOOL_ADDR);
    // withdraw NFT from NitroPool
    nitroPool.withdraw(IMPERSONATOR_NFT_ID_V2);
    // check that user get some tokens from nitroPool

    // check NFT ownership
    assertEq(nftPool.ownerOf(IMPERSONATOR_NFT_ID_V2), IMPERSONATOR_ADDR_V2);
    vm.stopPrank();
  }

}

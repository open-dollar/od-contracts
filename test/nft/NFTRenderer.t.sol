// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {GoerliForkSetup} from '@test/nft/GoerliForkSetup.t.sol';
import {ARB_GOERLI_WETH, ARB_GOERLI_GOV_TOKEN} from '@script/Registry.s.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';
import {NFTRenderer2} from '@libraries/NFTRenderer2.sol';

// forge t --fork-url $URL --match-contract NFTRendererTest -vvvvv

/**
 * @dev script not functional if getter functions are set to internal
 * must be public for testing purposes - hence commented out
 */
contract NFTRendererTest is GoerliForkSetup {
  uint256 public safeId = 3;
  NFTRenderer public nftRendererTester = NFTRenderer(0x2a004eA6266eA1A340D1a7D78F1e0F4e9Ae2e685);

  function testParams1() public {
    nftRendererTester.renderParams(15);
  }

  function testParams2() public {
    nftRendererTester.renderParams(1);
  }

  function testParams3() public {
    nftRendererTester.renderParams(3);
  }
}

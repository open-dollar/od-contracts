// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {GoerliForkSetup} from '@test/nft/GoerliForkSetup.t.sol';
import {GoerliParams, WETH, FTRG, WBTC, STONES, TOTEM} from '@script/GoerliParams.s.sol';
import {ARB_GOERLI_WETH, ARB_GOERLI_GOV_TOKEN} from '@script/Registry.s.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';

// forge t --fork-url $URL --match-contract NFTSecurity -vvv

contract NFTSecurity is GoerliForkSetup {
  using SafeERC20 for IERC20;

  // TODO attempt to burn NFT
}

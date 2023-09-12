// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {GoerliForkSetup} from '@test/nft/GoerliForkSetup.t.sol';
import {ARB_GOERLI_WETH, ARB_GOERLI_GOV_TOKEN} from '@script/Registry.s.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {NFTRenderer2} from '@libraries/NFTRenderer2.sol';

// forge t --fork-url $URL --match-contract NFTRenderer -vvv

/**
 * @dev script not functional if getter functions are set to internal
 * must be public for testing purposes - hence commented out
 */
contract NFTRenderer is GoerliForkSetup {
  uint256 public safeId = 3;

  // function testNftImage() public {
  //   (bytes32 cType, address safeHandler) = vault721._getCType(safeId);
  //   (uint256 lockedCollat, uint256 genDebt) = vault721._getLockedCollatAndGenDebt(cType, safeHandler);
  //   uint256 safetyCRatio = vault721._getCTypeRatio(cType);
  //   uint256 stabilityFee = vault721._getStabilityFee(cType);
  //   string memory symbol = vault721._getTokenSymbol(cType);

  //   NFTRenderer2.VaultParams memory params = NFTRenderer2.VaultParams({
  //     tokenId: safeId,
  //     collat: lockedCollat,
  //     debt: genDebt,
  //     ratio: safetyCRatio,
  //     fee: stabilityFee,
  //     symbol: symbol
  //   });

  //   string memory uri = NFTRenderer2.render(params);
  //   emit log_string(uri);
  // }
}

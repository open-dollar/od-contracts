// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {GoerliFork} from '@test/nft/goerli/GoerliFork.t.sol';
import {GoerliParams, WSTETH, ARB, CBETH, RETH, MAGIC} from '@script/GoerliParams.s.sol';
import {GOERLI_WETH, GOERLI_GOV_TOKEN} from '@script/Registry.s.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {CollateralAuctionHouse} from '@contracts/CollateralAuctionHouse.sol';
import {CollateralJoinFactory} from '@contracts/factories/CollateralJoinFactory.sol';

// forge t --fork-url $URL --match-contract AddCollateralGoerli -vvvvv

contract AddCollateralGoerli is GoerliFork {
  uint256 constant MINUS_0_5_PERCENT_PER_HOUR = 999_998_607_628_240_588_157_433_861;

  /**
   * @dev params for testing, do not use for production
   */
  ICollateralAuctionHouse.CollateralAuctionHouseParams _cahCParams = ICollateralAuctionHouse
    .CollateralAuctionHouseParams({
    minimumBid: WAD, // 1 COINs
    minDiscount: WAD, // no discount
    maxDiscount: 0.9e18, // -10%
    perSecondDiscountUpdateRate: MINUS_0_5_PERCENT_PER_HOUR
  });

  function testAddCollateral() public {
    vm.startPrank(address(timelockController));
    bytes32[] memory _collateralTypesList = collateralJoinFactory.collateralTypesList();
    collateralJoinFactory.deployCollateralJoin(bytes32('WETH'), 0xEe01c0CD76354C383B8c7B4e65EA88D00B06f36f);
    vm.stopPrank();
  }

  function testDeployCollateralAuctionHouse() public {
    vm.startPrank(address(timelockController));
    collateralAuctionHouseFactory.deployCollateralAuctionHouse(bytes32('WETH'), _cahCParams);
    vm.stopPrank();
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {GoerliContracts} from '@script/GoerliContracts.s.sol';
import {CollateralJoinFactory} from '@contracts/factories/CollateralJoinFactory.sol';
import {CollateralAuctionHouseFactory} from '@contracts/factories/CollateralAuctionHouseFactory.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {WAD, RAY, RAD} from '@libraries/Math.sol';

uint256 constant MINUS_0_5_PERCENT_PER_HOUR = 999_998_607_628_240_588_157_433_861;

/**
 * @dev add to env
 * CTYPE_ADDR= <token address>
 * CTYPE_SYM= <bytes32 of token symbol>
 */

contract CTypeBase is GoerliContracts, Script {
  CollateralJoinFactory public collateralJoinFactory =
    CollateralJoinFactory(CollateralJoinFactory_Address);
  CollateralAuctionHouseFactory public collateralAuctionHouseFactory =
    CollateralAuctionHouseFactory(CollateralAuctionHouseFactory_Address);

  bytes32 public cType = vm.envBytes32('CTYPE_SYM');
  address public cAddr = vm.envAddress('CTYPE_ADDR');

  /**
   * @dev params for testing, do not use for production
   */
  ICollateralAuctionHouse.CollateralAuctionHouseParams _cahCParams =
    ICollateralAuctionHouse.CollateralAuctionHouseParams({
      minimumBid: WAD, // 1 COINs
      minDiscount: WAD, // no discount
      maxDiscount: 0.9e18, // -10%
      perSecondDiscountUpdateRate: MINUS_0_5_PERCENT_PER_HOUR
    });
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {GoerliContracts} from '@script/GoerliContracts.s.sol';
import {CollateralJoinFactory} from '@contracts/factories/CollateralJoinFactory.sol';
import {CollateralAuctionHouseFactory} from '@contracts/factories/CollateralAuctionHouseFactory.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';

/**
 * @dev add to env
 * CTYPE_ADDR= <token address>
 * CTYPE_SYM= <bytes32 of token symbol>
 */

contract CTypeBase is GoerliContracts, Script {
  CollateralJoinFactory public collateralJoinFactory = CollateralJoinFactory(collateralJoinFactoryAddr);
  CollateralAuctionHouseFactory public collateralAuctionHouseFactory =
    CollateralAuctionHouseFactory(collateralAuctionHouseFactoryAddr);

  bytes32 public cType = vm.envBytes32('CTYPE_SYM');
  address public cAddr = vm.envAddress('CTYPE_ADDR');

  /**
   * @dev params for testing, do not use for production
   */
  ICollateralAuctionHouse.CollateralAuctionHouseParams _cahCParams = ICollateralAuctionHouse
    .CollateralAuctionHouseParams({
    minimumBid: 1,
    minDiscount: 1,
    maxDiscount: 1,
    perSecondDiscountUpdateRate: 1,
    lowerCollateralDeviation: 1,
    upperCollateralDeviation: 1
  });
}

pragma solidity 0.6.7;

import {ICollateralAuctionHouse} from './ICollateralAuctionHouse.sol';

interface IIncreasingDiscountCollateralAuctionHouse is ICollateralAuctionHouse {
  function getApproximateCollateralBought(
    uint256 _id,
    uint256 _wad
  ) external view returns (uint256 _collateralFsmPriceFeedValue, uint256 _systemCoinPriceFeedValue);

  function getCollateralBought(
    uint256 _id,
    uint256 _wad
  ) external returns (uint256 _collateralFsmPriceFeedValue, uint256 _systemCoinPriceFeedValue);
  function buyCollateral(uint256 _id, uint256 _wad) external;
}

pragma solidity 0.6.7;

import {IAuthorizable} from './IAuthorizable.sol';

interface ICollateralAuctionHouse is IAuthorizable {
  function coinName() external view returns (bytes32 _name);
  function bidAmount(uint256 _id) external view returns (uint256 _rad);
  function raisedAmount(uint256 _id) external view returns (uint256 _rad);
  function remainingAmountToSell(uint256 _id) external view returns (uint256 _wad);
  function forgoneCollateralReceiver(uint256 _id) external view returns (address _receiver);
  function amountToRaise(uint256 _id) external view returns (uint256 _rad);
  function terminateAuctionPrematurely(uint256 _auctionId) external;
  function startAuction(
    address _forgoneCollateralReceiver,
    address _initialBidder,
    uint256 /* rad */ _amountToRaise,
    uint256 /* wad */ _collateralToSell,
    uint256 /* rad */ _initialBid
  ) external returns (uint256 _id);
  function settleAuction(uint256 _id) external;
}

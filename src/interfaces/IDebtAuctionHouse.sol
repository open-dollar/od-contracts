pragma solidity 0.6.7;

import {IAuthorizable} from './IAuthorizable.sol';
import {IDisableable} from './IDisableable.sol';

interface IDebtAuctionHouse is IDisableable, IAuthorizable {
  function startAuction(
    address _incomeReceiver,
    uint256 /* wad */ _amountToSell,
    uint256 /* rad */ _initialBid
  ) external returns (uint256 _id);
  function protocolToken() external view returns (address _protocolToken);
  function restartAuction(uint256 _id) external;
  function decreaseSoldAmount(uint256 _id, uint256 /* wad */ _amountToBuy, uint256 /* rad */ _bid) external;
  function settleAuction(uint256 _id) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IDisableable} from './IDisableable.sol';
import {IAuthorizable} from './IAuthorizable.sol';

interface ISurplusAuctionHouse is IDisableable, IAuthorizable {
  function startAuction(uint256 /* rad */ _amountToSell, uint256 /* wad */ _initialBid) external returns (uint256 _id);
  function restartAuction(uint256 _id) external;
  function protocolToken() external view returns (address _protocolToken);
  function increaseBidSize(uint256 _id, uint256 /* rad */ _amountToBuy, uint256 /* wad */ _bid) external;
  function settleAuction(uint256 _id) external;
  function terminateAuctionPrematurely(uint256 _id) external;
}

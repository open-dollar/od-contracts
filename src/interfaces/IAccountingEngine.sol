pragma solidity 0.6.7;

import {IDisableable} from './IDisableable.sol';
import {IAuthorizable} from './IAuthorizable.sol';

interface IAccountingEngine is IDisableable, IAuthorizable {
  function pushDebtToQueue(uint256 _debtBlock) external;
  function popDebtFromQueue(uint256 _debtBlockTimestamp) external;
  function surplusAuctionDelay() external view returns (uint256 _surplusAuctionDelay);
  function surplusAuctionAmountToSell() external view returns (uint256 _surplusAmountToSell);
  function surplusAuctionHouse() external view returns (address _surplusAuctionHouseAddress);
  function safeEngine() external view returns (address _safeEngineAddress);
  function totalOnAuctionDebt() external view returns (uint256 _totalOnAuctionDebt);
  function cancelAuctionedDebtWithSurplus(uint256 _rad) external;
  function auctionDebt() external returns (uint256 _id);
  function auctionSurplus() external returns (uint256 _id);
  function transferExtraSurplus() external;
  function transferPostSettlementSurplus() external;
}

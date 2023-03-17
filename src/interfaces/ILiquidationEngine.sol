pragma solidity 0.6.7;

import {IDisableable} from './IDisableable.sol';
import {IAuthorizable} from './IAuthorizable.sol';

interface ILiquidationEngine is IDisableable, IAuthorizable {
  function removeCoinsFromAuction(uint256 _rad) external;
  function collateralTypes(bytes32)
    external
    view
    returns (
      address _collateralAuctionHouse,
      uint256 /* wad */ _liquidationPenalty,
      uint256 /* rad */ _liquidationQuantity
    );

  function connectSAFESaviour(address _saviour) external;
  function disconnectSAFESaviour(address _saviour) external;
  function protectSAFE(bytes32 _collateralType, address _safe, address _saviour) external;
  function liquidateSAFE(bytes32 _collateralType, address _safe) external returns (uint256 _auctionId);
  function getLimitAdjustedDebtToCover(bytes32 _collateralType, address _safe) external view returns (uint256 _wad);
}

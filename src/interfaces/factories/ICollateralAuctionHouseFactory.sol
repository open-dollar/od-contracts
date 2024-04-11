// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IModifiablePerCollateral} from '@interfaces/utils/IModifiablePerCollateral.sol';

interface ICollateralAuctionHouseFactory is IAuthorizable, IModifiable, IModifiablePerCollateral {
  // --- Events ---

  /**
   * @notice Emitted when a new CollateralAuctionHouse contract is deployed
   * @param _cType Bytes32 representation of the collateral type
   * @param _collateralAuctionHouse Address of the deployed CollateralAuctionHouse contract
   */
  event DeployCollateralAuctionHouse(bytes32 indexed _cType, address indexed _collateralAuctionHouse);

  // --- Errors ---

  /**
   * @notice Getter for the collateral parameters struct
   * @param _cType Bytes32 representation of the collateral type
   * @return _cahParams CollateralAuctionHouse parameters struct
   */
  function cParams(bytes32 _cType)
    external
    view
    returns (ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahParams);

  /**
   * @notice Getter for the unpacked collateral parameters struct
   * @param _cType Bytes32 representation of the collateral type
   * @return _minimumBid Minimum bid for the collateral auctions [wad]
   * @return _minDiscount Minimum discount for the collateral auctions [wad %]
   * @return _maxDiscount Maximum discount for the collateral auctions [wad %]
   * @return _perSecondDiscountUpdateRate Per second rate at which the discount is updated [ray]
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _cParams(bytes32 _cType)
    external
    view
    returns (uint256 _minimumBid, uint256 _minDiscount, uint256 _maxDiscount, uint256 _perSecondDiscountUpdateRate);

  // --- Registry ---

  /// @notice Address of the SAFEEngine contract
  function safeEngine() external view returns (address _safeEngine);
  /// @notice Address of the LiquidationEngine contract
  function liquidationEngine() external view returns (address _liquidationEngine);
  /// @notice Address of the OracleRelayer contract
  function oracleRelayer() external view returns (address _oracleRelayer);

  // --- Data ---

  /**
   * @notice Getter for the address of the CollateralAuctionHouse contract associated with a collateral type
   * @param _cType Bytes32 representation of the collateral type
   * @return _collateralAuctionHouse Address of the CollateralAuctionHouse contract
   */
  function collateralAuctionHouses(bytes32 _cType) external view returns (address _collateralAuctionHouse);

  /**
   * @notice Getter for the list of CollateralAuctionHouse contracts
   * @return _collateralAuctionHouses List of CollateralAuctionHouse contracts
   */
  function collateralAuctionHousesList() external view returns (address[] memory _collateralAuctionHouses);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface ICollateralJoin is IAuthorizable, IDisableable {
  // --- Events ---
  event Join(address _sender, address _account, uint256 _wad);
  event Exit(address _sender, address _account, uint256 _wad);

  // --- Registry ---
  /**
   * @notice SAFEEngine contract
   */
  function safeEngine() external view returns (ISAFEEngine _safeEngine);

  /**
   * @notice Collateral token ERC20Metadata contract
   */
  function collateral() external view returns (IERC20Metadata _collateral);

  // --- Data ---
  /**
   * @notice System name of the collateral type
   */
  function collateralType() external view returns (bytes32 _cType);

  /**
   * @notice Collateral token decimals
   */
  function decimals() external view returns (uint256 _decimals);

  /**
   * @notice Multiplier used to transform collateral into 18 decimals within the system
   */
  function multiplier() external view returns (uint256 _multiplier);

  // --- Methods ---
  /**
   * @notice Join collateral in the system
   * @param _account Account to which we add collateral into the system
   * @param _wad Amount of collateral to transfer in the system (represented as a number with 18 decimals)
   */
  function join(address _account, uint256 _wad) external;

  /**
   * @notice Exit collateral from the system
   * @param _account Account to which we transfer the collateral out of the system
   * @param _wad Amount of collateral to transfer to account (represented as a number with 18 decimals)
   */
  function exit(address _account, uint256 _wad) external;
}

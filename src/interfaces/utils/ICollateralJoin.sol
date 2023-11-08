// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IERC20Metadata} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface ICollateralJoin is IAuthorizable, IDisableable {
  // --- Events ---

  /**
   * @notice Emitted when an account joins collateral tokens into the system
   * @param _sender Address of the account that called the function (sent the ERC20 collateral tokens)
   * @param _account Address of the account that received the collateral tokens
   * @param _wad Amount of collateral tokens joined [wad]
   */
  event Join(address _sender, address _account, uint256 _wad);

  /**
   * @notice Emitted when an account exits collateral tokens from the system
   * @param _sender Address of the account that called the function (sent the internal collateral tokens)
   * @param _account Address of the account that received the ERC20 collateral tokens
   * @param _wad Amount of collateral tokens exited [wad]
   */
  event Exit(address _sender, address _account, uint256 _wad);

  // --- Registry ---

  /// @notice Address of the SAFEEngine contract
  function safeEngine() external view returns (ISAFEEngine _safeEngine);

  /// @notice Address of the ERC20 collateral token contract
  function collateral() external view returns (IERC20Metadata _collateral);

  // --- Data ---

  /**
   * @notice The collateral type that this contract handles
   * @return _cType Bytes32 representation of the collateralType
   */
  function collateralType() external view returns (bytes32 _cType);

  /// @notice Number of decimals of the collateral token
  function decimals() external view returns (uint256 _decimals);

  /// @notice Multiplier used to transform collateral into 18 decimals within the system
  function multiplier() external view returns (uint256 _multiplier);

  // --- Methods ---

  /**
   * @notice Join collateral in the system
   * @param _account Account to which we add collateral into the system
   * @param _wei Amount of collateral to transfer in the system (represented as a number with token decimals)
   */
  function join(address _account, uint256 _wei) external;

  /**
   * @notice Exit collateral from the system
   * @param _account Account to which we transfer the collateral out of the system
   * @param _wei Amount of collateral to transfer to account (represented as a number with token decimals)
   */
  function exit(address _account, uint256 _wei) external;
}

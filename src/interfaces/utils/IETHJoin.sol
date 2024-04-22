// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface IETHJoin is IAuthorizable, IDisableable {
  // --- Events ---

  /**
   * @notice Emitted when an account joins ETH collateral into the system
   * @param _sender Address of the account that called the function (sent the ETH collateral)
   * @param _account Address of the account that received the ETH collateral
   * @param _wad Amount of ETH collateral joined [wad]
   */
  event Join(address _sender, address _account, uint256 _wad);

  /**
   * @notice Emitted when an account exits ETH collateral from the system
   * @param _sender Address of the account that called the function (sent the internal ETH collateral)
   * @param _account Address of the account that received the ETH collateral
   * @param _wad Amount of ETH collateral exited [wad]
   */
  event Exit(address _sender, address _account, uint256 _wad);

  // --- Errors ---

  /// @notice Throws if the transfer of ETH fails
  error ETHJoin_FailedTransfer();

  // --- Registry ---

  /// @notice Address of the SAFEEngine contract
  function safeEngine() external view returns (ISAFEEngine _safeEngine);

  // --- Data ---

  /**
   * @notice The collateral type that this contract handles
   * @return _cType Bytes32 representation of the collateralType
   */
  function collateralType() external view returns (bytes32 _cType);

  /// @notice Number of decimals of the collateral token
  function decimals() external view returns (uint256 _decimals);

  /**
   * @notice Join ETH in the system
   * @param _account Account that will receive the ETH representation inside the system
   */
  function join(address _account) external payable;

  /**
   * @notice Exit ETH from the system
   * @param _account Account that will receive the ETH representation inside the system
   * @param _wad Amount of ETH to transfer to account [wad]
   */
  function exit(address _account, uint256 _wad) external;
}

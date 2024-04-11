// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface ICoinJoin is IAuthorizable, IDisableable {
  // --- Events ---

  /**
   * @notice Emitted when an account joins coins into the system
   * @param _sender Address of the account that called the function (sent the ERC20 coins)
   * @param _account Address of the account that received the coins
   * @param _wad Amount of coins joined [wad]
   */
  event Join(address _sender, address _account, uint256 _wad);

  /**
   * @notice Emitted when an account exits coins from the system
   * @param _sender Address of the account that called the function (sent the internal coins)
   * @param _account Address of the account that received the ERC20 coins
   * @param _wad Amount of coins exited [wad]
   */
  event Exit(address _sender, address _account, uint256 _wad);

  // --- Registry ---

  /// @notice Address of the SAFEEngine contract
  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  /// @notice Address of the SystemCoin contract
  function systemCoin() external view returns (ISystemCoin _systemCoin);

  // --- Data ---

  /// @notice Number of decimals the coin has
  function decimals() external view returns (uint256 _decimals);

  // --- Methods ---

  /**
   * @notice Join system coins in the system
   * @param _account Account that will receive the joined coins
   * @param _wad Amount of external coins to join [wad]
   * @dev    Exited coins have 18 decimals but inside the system they have 45 [rad] decimals.
   *         When we join, the amount [wad] is multiplied by 10**27 [ray]
   */
  function join(address _account, uint256 _wad) external;

  /**
   * @notice Exit system coins from the system
   * @dev    New coins cannot be minted after the system is disabled
   * @param _account Account that will receive the exited coins
   * @param _wad Amount of internal coins to join (18 decimal number)
   * @dev    Inside the system, coins have 45 decimals [rad] but outside of it they have 18 decimals [wad].
   *         When we exit, we specify a wad amount of coins and then the contract automatically multiplies
   *         wad by 10**27 to move the correct 45 decimal coin amount to this adapter
   */
  function exit(address _account, uint256 _wad) external;
}

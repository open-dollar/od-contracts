// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {RAY} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  CoinJoin
 * @notice This contract allows to connect the SAFEEngine with the system coin
 * @dev    This contract needs to be authorized in Coin and SAFEEngine
 */
contract CoinJoin is Authorizable, Disableable, ICoinJoin {
  using Assertions for address;
  // --- Data ---
  // SAFE database

  ISAFEEngine public safeEngine;
  // Coin created by the system; this is the external, ERC-20 representation, not the internal 'coinBalance'
  ISystemCoin public systemCoin;
  // Number of decimals the system coin has
  uint256 public decimals;

  // --- Init ---
  constructor(address _safeEngine, address _systemCoin) Authorizable(msg.sender) {
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
    systemCoin = ISystemCoin(_systemCoin.assertNonNull());
    decimals = 18;
  }

  /**
   * @notice Join system coins in the system
   * @dev    Exited coins have 18 decimals but inside the system they have 45 (rad) decimals.
   *         When we join, the amount (wad) is multiplied by 10**27 (ray)
   * @param _account Account that will receive the joined coins
   * @param _wad Amount of external coins to join (18 decimal number)
   */
  function join(address _account, uint256 _wad) external {
    safeEngine.transferInternalCoins(address(this), _account, RAY * _wad);
    systemCoin.burn(msg.sender, _wad);
    emit Join(msg.sender, _account, _wad);
  }

  /**
   * @notice Exit system coins from the system
   * @dev    Inside the system, coins have 45 (rad) decimals but outside of it they have 18 decimals (wad).
   *         When we exit, we specify a wad amount of coins and then the contract automatically multiplies
   *         wad by 10**27 to move the correct 45 decimal coin amount to this adapter
   * @dev    New coins cannot be minted after the system is disabled
   * @param _account Account that will receive the exited coins
   * @param _wad Amount of internal coins to join (18 decimal number)
   */
  function exit(address _account, uint256 _wad) external whenEnabled {
    safeEngine.transferInternalCoins(msg.sender, address(this), RAY * _wad);
    systemCoin.mint(_account, _wad);
    emit Exit(msg.sender, _account, _wad);
  }
}

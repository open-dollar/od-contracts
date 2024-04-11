// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

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

  // --- Registry ---

  /// @inheritdoc ICoinJoin
  ISAFEEngine public safeEngine;
  /// @inheritdoc ICoinJoin
  ISystemCoin public systemCoin;

  // --- Data ---

  /// @inheritdoc ICoinJoin
  uint256 public decimals;

  // --- Init ---

  /**
   * @param  _safeEngine Address of the SAFEEngine contract
   * @param  _systemCoin Address of the SystemCoin contract
   */
  constructor(address _safeEngine, address _systemCoin) Authorizable(msg.sender) {
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
    systemCoin = ISystemCoin(_systemCoin.assertNonNull());
    decimals = 18;
  }

  // --- Methods ---

  /// @inheritdoc ICoinJoin
  function join(address _account, uint256 _wad) external {
    safeEngine.transferInternalCoins(address(this), _account, RAY * _wad);
    systemCoin.transferFrom(msg.sender, address(this), _wad);
    systemCoin.burn(_wad);
    emit Join(msg.sender, _account, _wad);
  }

  /// @inheritdoc ICoinJoin
  function exit(address _account, uint256 _wad) external whenEnabled {
    safeEngine.transferInternalCoins(msg.sender, address(this), RAY * _wad);
    systemCoin.mint(_account, _wad);
    emit Exit(msg.sender, _account, _wad);
  }
}

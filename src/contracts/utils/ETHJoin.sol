// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IETHJoin, ISAFEEngine} from '@interfaces/utils/IETHJoin.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {Math} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  ETHJoin
 * @notice This contract allows to connect the SAFEEngine to native ETH collateral
 * @dev    All Join adapters need to implement two basic methods: `join` and `exit`
 */
contract ETHJoin is Authorizable, Disableable, IETHJoin {
  using Math for uint256;
  using Assertions for address;

  // --- Registry ---

  /// @inheritdoc IETHJoin
  ISAFEEngine public safeEngine;
  /// @inheritdoc IETHJoin
  bytes32 public collateralType;

  // --- Data ---

  /// @inheritdoc IETHJoin
  uint256 public decimals;

  // --- Init ---

  /**
   * @param  _safeEngine Address of the SAFEEngine contract
   * @param  _cType Bytes32 representation of the collateral type
   */
  constructor(address _safeEngine, bytes32 _cType) Authorizable(msg.sender) {
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
    collateralType = _cType;
    decimals = 18;
  }

  // --- Methods ---

  /// @inheritdoc IETHJoin
  function join(address _account) external payable whenEnabled {
    safeEngine.modifyCollateralBalance(collateralType, _account, msg.value.toInt());
    emit Join(msg.sender, _account, msg.value);
  }

  /// @inheritdoc IETHJoin
  function exit(address _account, uint256 _wei) external {
    safeEngine.modifyCollateralBalance(collateralType, msg.sender, -_wei.toInt());
    emit Exit(msg.sender, _account, _wei);
    (bool _success,) = _account.call{value: _wei}('');
    if (!_success) revert ETHJoin_FailedTransfer();
  }
}

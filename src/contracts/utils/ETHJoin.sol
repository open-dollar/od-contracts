// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IETHJoin, ISAFEEngine} from '@interfaces/utils/IETHJoin.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {Math} from '@libraries/Math.sol';

/*
    Here we provide ETHJoin adapter (for native Ether)
    to connect the SAFEEngine to arbitrary external token implementations,
    creating a bounded context for the SAFEEngine. 
    In practice, adapter implementations will be varied and specific to
    individual collateral types, accounting for different transfer
    semantics and token standards.
    Adapters need to implement two basic methods:
      - `join`: enter collateral into the system
      - `exit`: remove collateral from the system
*/

contract ETHJoin is Authorizable, Disableable, IETHJoin {
  using Math for uint256;

  // --- Data ---
  // SAFE database
  ISAFEEngine public safeEngine;
  // Collateral type name
  bytes32 public collateralType;
  // Number of decimals ETH has
  uint256 public decimals;

  // --- Init ---
  constructor(address _safeEngine, bytes32 _cType) Authorizable(msg.sender) {
    safeEngine = ISAFEEngine(_safeEngine);
    collateralType = _cType;
    decimals = 18;
  }

  /**
   * @notice Join ETH in the system
   * @param _account Account that will receive the ETH representation inside the system
   */
  function join(address _account) external payable whenEnabled {
    safeEngine.modifyCollateralBalance(collateralType, _account, msg.value.toInt());
    emit Join(msg.sender, _account, msg.value);
  }

  /**
   * @notice Exit ETH from the system
   * @param _account Account that will receive the ETH representation inside the system
   */
  function exit(address _account, uint256 _wad) external {
    safeEngine.modifyCollateralBalance(collateralType, msg.sender, -_wad.toInt());
    emit Exit(msg.sender, _account, _wad);
    (bool _success,) = _account.call{value: _wad}('');
    if (!_success) revert ETHJoin_FailedTransfer();
  }
}

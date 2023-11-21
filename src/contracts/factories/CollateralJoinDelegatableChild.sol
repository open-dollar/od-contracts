// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICollateralJoinChild} from '@interfaces/factories/ICollateralJoinChild.sol';
import {ERC20Votes} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol';
import {CollateralJoinChild} from '@contracts/factories/CollateralJoinChild.sol';
import {ICollateralJoinDelegatableChild} from '@interfaces/factories/ICollateralJoinDelegatableChild.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  CollateralJoinDelegatableChild
 * @notice This contract inherits all the functionality of CollateralJoin to be factory deployed and adds a ERC20Votes delegation
 * @dev    For well behaved ERC20Votes tokens with less than 18 decimals
 */
contract CollateralJoinDelegatableChild is CollateralJoinChild, ICollateralJoinDelegatableChild {
  using Assertions for address;

  /// @notice Address to whom the voting power is delegated
  address public delegatee;

  // --- Init ---

  /**
   * @param  _safeEngine Address of the SafeEngine contract
   * @param  _cType      Bytes32 representation of the collateral type
   * @param  _collateral Address of the ERC20Votes collateral token
   * @param  _delegatee  Address to whom the voting power is delegated
   */
  constructor(
    address _safeEngine,
    bytes32 _cType,
    address _collateral,
    address _delegatee
  ) CollateralJoinChild(_safeEngine, _cType, _collateral) {
    ERC20Votes(_collateral).delegate(_delegatee.assertNonNull());
    delegatee = _delegatee;
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICollateralJoinChild} from '@interfaces/factories/ICollateralJoinChild.sol';
import {ERC20Votes} from '@openzeppelin/token/ERC20/extensions/ERC20Votes.sol';
import {CollateralJoinChild} from '@contracts/factories/CollateralJoinChild.sol';

/**
 * @title  CollateralJoinDelegatableChild
 * @notice This contract inherits all the functionality of `CollateralJoin.sol` to be factory deployed and adds a ERC20Votes delegation
 * @dev    For well behaved ERC20Votes tokens with less than 18 decimals
 */
contract CollateralJoinDelegatableChild is CollateralJoinChild {
  address public delegatee;

  // --- Init ---
  constructor(
    address _safeEngine,
    bytes32 _cType,
    address _collateral,
    address _delegatee
  ) CollateralJoinChild(_safeEngine, _cType, _collateral) {
    ERC20Votes(_collateral).delegate(_delegatee);
    delegatee = _delegatee;
  }
}

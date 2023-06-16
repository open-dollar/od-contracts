// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {
  ICollateralJoin, ICollateralJoinFactory, ISAFEEngine, IERC20Metadata
} from '@interfaces/utils/ICollateralJoin.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {Math} from '@libraries/Math.sol';
import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';

import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  CollateralJoin
 * @notice This contract allows to connect the SAFEEngine to arbitrary external token implementations
 * @dev    For well behaved ERC20 tokens with less than 18 decimals
 *         All Join adapters need to implement two basic methods: `join` and `exit`
 */
contract CollateralJoin is Authorizable, Disableable, ICollateralJoin {
  using Math for uint256;
  using SafeERC20 for IERC20Metadata;
  using Assertions for address;

  // --- Registry ---
  /// @inheritdoc ICollateralJoin
  ICollateralJoinFactory public collateralJoinFactory;
  /// @inheritdoc ICollateralJoin
  ISAFEEngine public safeEngine;
  /// @inheritdoc ICollateralJoin
  IERC20Metadata public collateral;

  // --- Data ---
  /// @inheritdoc ICollateralJoin
  bytes32 public collateralType;
  /// @inheritdoc ICollateralJoin
  uint256 public decimals;
  /// @inheritdoc ICollateralJoin
  uint256 public multiplier;

  // --- Init ---
  constructor(address _safeEngine, bytes32 _cType, address _collateral) Authorizable(msg.sender) {
    collateralJoinFactory = ICollateralJoinFactory(msg.sender);
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
    collateralType = _cType;
    collateral = IERC20Metadata(_collateral);
    decimals = collateral.decimals();
    // NOTE: assumes collateral token has <= 18 decimals
    multiplier = 18 - decimals;
  }

  // --- Methods ---
  /**
   * @dev This function locks collateral in the adapter and creates a representation of
   *      the locked collateral inside the system. The representation uses 18 decimals.
   * @inheritdoc ICollateralJoin
   */
  function join(address _account, uint256 _wad) external whenEnabled whenFactoryEnabled {
    safeEngine.modifyCollateralBalance(collateralType, _account, _wad.toInt());
    collateral.safeTransferFrom(msg.sender, address(this), _wad / 10 ** multiplier);
    emit Join(msg.sender, _account, _wad);
  }

  /**
   * @dev This function destroys the collateral representation from inside the system
   *      and exits the collateral from this adapter. The transferred collateral uses
   *      the same decimals as the original collateral token.
   * @inheritdoc ICollateralJoin
   */
  function exit(address _account, uint256 _wad) external {
    safeEngine.modifyCollateralBalance(collateralType, msg.sender, -_wad.toInt());
    collateral.safeTransfer(_account, _wad / 10 ** multiplier);
    emit Exit(msg.sender, _account, _wad);
  }

  modifier whenFactoryEnabled() {
    if (collateralJoinFactory.contractEnabled() == 0) revert CollateralJoin_FactoryIsDisabled();
    _;
  }
}

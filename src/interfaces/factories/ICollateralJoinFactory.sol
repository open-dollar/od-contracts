// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface ICollateralJoinFactory is IAuthorizable, IDisableable {
  // --- Events ---

  /**
   * @notice Emitted when a new CollateralJoin contract is deployed
   * @param _cType Bytes32 representation of the collateral type
   * @param _collateral Address of the ERC20 collateral token
   * @param _collateralJoin Address of the deployed CollateralJoin contract
   */
  event DeployCollateralJoin(bytes32 indexed _cType, address indexed _collateral, address indexed _collateralJoin);

  /**
   * @notice Emitted when a CollateralJoin contract is disabled
   * @param _collateralJoin Address of the disabled CollateralJoin contract
   */
  event DisableCollateralJoin(address indexed _collateralJoin);

  // --- Errors ---

  /// @notice Throws when trying to deploy a CollateralJoin contract for an existent collateral type
  error CollateralJoinFactory_CollateralJoinExistent();
  /// @notice Throws when trying to disable a non-existent CollateralJoin contract
  error CollateralJoinFactory_CollateralJoinNonExistent();

  // --- Registry ---

  /// @notice Address of the SAFEEngine contract
  function safeEngine() external view returns (address _safeEngine);

  // --- Data ---

  /**
   * @notice Getter for the address of the CollateralJoin contract associated with a collateral type
   * @param _cType Bytes32 representation of the collateral type
   * @return _collateralJoin Address of the CollateralJoin contract
   */
  function collateralJoins(bytes32 _cType) external view returns (address _collateralJoin);

  /**
   * @notice Getter for the list of collateral types
   * @return _collateralTypesList List of collateral types
   */
  function collateralTypesList() external view returns (bytes32[] memory _collateralTypesList);

  /**
   * @notice Getter for the list of CollateralJoin contracts
   * @return _collateralJoinsList List of CollateralJoin contracts
   */
  function collateralJoinsList() external view returns (address[] memory _collateralJoinsList);

  // --- Methods ---

  /**
   * @notice Deploys a CollateralJoinChild contract
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _collateral Address of the ERC20 collateral token
   * @return _collateralJoin Address of the deployed CollateralJoinChild contract
   */
  function deployCollateralJoin(bytes32 _cType, address _collateral) external returns (ICollateralJoin _collateralJoin);

  /**
   * @notice Deploys a CollateralJoinDelegatableChild contract
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _collateral Address of the ERC20Votes collateral token
   * @param  _delegatee Address to whom the deployed child will delegate the voting power to
   * @return _collateralJoin Address of the deployed CollateralJoinDelegatableChild contract
   */
  function deployDelegatableCollateralJoin(
    bytes32 _cType,
    address _collateral,
    address _delegatee
  ) external returns (ICollateralJoin _collateralJoin);

  /**
   * @notice Disables a CollateralJoin contract and removes it from the collateral types list
   * @param  _cType Bytes32 representation of the collateral type
   * @dev    Allows the deployment of other CollateralJoin contract for the same collateral type
   */
  function disableCollateralJoin(bytes32 _cType) external;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface IETHJoin is IAuthorizable, IDisableable {
  // --- Events ---
  event Join(address _sender, address _account, uint256 _wad);
  event Exit(address _sender, address _account, uint256 _wad);

  // --- Errors ---
  error ETHJoin_FailedTransfer();

  // --- Data ---
  function safeEngine() external view returns (ISAFEEngine _safeEngine);
  function collateralType() external view returns (bytes32 _cType);
  function decimals() external view returns (uint256 _decimals);

  function join(address _account) external payable;
  function exit(address _account, uint256 _wad) external;
}

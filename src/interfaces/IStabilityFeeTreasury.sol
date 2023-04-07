// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/IAuthorizable.sol';
import {IDisableable} from '@interfaces/IDisableable.sol';

interface IStabilityFeeTreasury is IAuthorizable, IDisableable {
  function setTotalAllowance(address _account, uint256 _rad) external;
  function setPerBlockAllowance(address _account, uint256 _rad) external;
  function giveFunds(address _account, uint256 _rad) external;
  function takeFunds(address _account, uint256 _rad) external;
  function pullFunds(address _destinationAccount, address _token, uint256 _wad) external;
  function transferSurplusFunds() external;
}

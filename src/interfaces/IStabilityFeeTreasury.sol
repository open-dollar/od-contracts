pragma solidity 0.6.7;

import {IDisableable} from './IDisableable.sol';
import {IAuthorizable} from './IAuthorizable.sol';

interface IStabilityFeeTreasury is IDisableable, IAuthorizable {
  function setTotalAllowance(address _account, uint256 _rad) external;
  function setPerBlockAllowance(address _account, uint256 _rad) external;
  function giveFunds(address _account, uint256 _rad) external;
  function takeFunds(address _account, uint256 _rad) external;
  function pullFunds(address _destinationAccount, address _token, uint256 _wad) external;
  function transferSurplusFunds() external;
}

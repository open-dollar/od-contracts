// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IAuthorizable {
  function authorizedAccounts(address _account) external view returns (bool _authorized);
  function addAuthorization(address _account) external;
  function removeAuthorization(address _account) external;
}

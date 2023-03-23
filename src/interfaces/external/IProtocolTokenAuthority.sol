// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IProtocolTokenAuthority {
  function authorizedAccounts(address) external view returns (uint256 _authorized);
}

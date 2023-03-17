pragma solidity 0.6.7;

interface IProtocolTokenAuthority {
  function authorizedAccounts(address) external view returns (uint256 _authorized);
}

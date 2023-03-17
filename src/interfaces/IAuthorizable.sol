pragma solidity 0.6.7;

interface IAuthorizable {
  function authorizedAccounts(address _account) external view returns (bool _authorized);
  function addAuthorization(address _account) external;
  function removeAuthorization(address _account) external;
}

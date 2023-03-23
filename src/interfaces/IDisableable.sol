pragma solidity 0.6.7;

interface IDisableable {
  function disableContract() external;
  function contractEnabled() external view returns (uint256 _enabled);
}

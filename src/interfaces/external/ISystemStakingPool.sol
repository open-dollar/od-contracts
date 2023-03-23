pragma solidity 0.6.7;

interface ISystemStakingPool {
  function canPrintProtocolTokens() external view returns (bool _canPrintProtocolTokens);
}

pragma solidity 0.6.7;

interface ICoinJoin {
  function coinName() external view returns (bytes32 _name);
  function systemCoin() external view returns (address _systemCoin);
  function join(address _account, uint256 _wad) external;
}

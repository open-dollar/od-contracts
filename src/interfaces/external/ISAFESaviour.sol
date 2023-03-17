pragma solidity 0.6.7;

interface ISAFESaviour {
  function saveSAFE(
    address _liquidator,
    bytes32 _collateralType,
    address _safe
  ) external returns (bool, uint256, uint256);
}

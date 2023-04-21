// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface ISAFESaviour {
  function saveSAFE(
    address _liquidator,
    bytes32 _collateralType,
    address _safe
  ) external returns (bool _ok, uint256 _collateralAdded, uint256 _liquidatorReward);
}

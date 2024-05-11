// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface ISAFESaviour {
  function saveSAFE(
    address _liquidator,
    bytes32 _cType,
    address _safe
  ) external returns (bool _ok, uint256 _collateralAdded, uint256 _liquidatorReward);
}

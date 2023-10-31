// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiSafeManager, EnumerableSet} from '@contracts/proxies/HaiSafeManager.sol';

contract HaiSafeManagerForTest is HaiSafeManager {
  using EnumerableSet for EnumerableSet.UintSet;

  constructor(address _safeEngine) HaiSafeManager(_safeEngine) {}

  function setSAFE(uint256 _safe, SAFEData memory __safeData) external {
    _safeData[_safe] = SAFEData({
      owner: __safeData.owner,
      pendingOwner: __safeData.pendingOwner,
      safeHandler: __safeData.safeHandler,
      collateralType: __safeData.collateralType
    });
    _usrSafes[__safeData.owner].add(_safe);
    _usrSafesPerCollat[__safeData.owner][__safeData.collateralType].add(_safe);
  }
}

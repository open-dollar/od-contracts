// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {LiquidationEngine} from '@contracts/LiquidationEngine.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';

contract LiquidationEngineForTest is LiquidationEngine {
  constructor(address _safeEngine) LiquidationEngine(_safeEngine) {}

  function setCollateralAuctionHouse(bytes32 _collateralType, address _collateralAuctionHouse) external {
    collateralTypes[_collateralType].collateralAuctionHouse = _collateralAuctionHouse;
  }

  function setAccountingEngine(address _accountingEngine) external {
    accountingEngine = IAccountingEngine(_accountingEngine);
  }
}

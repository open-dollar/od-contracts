// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {LiquidationEngine} from '@contracts/LiquidationEngine.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';

import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

contract LiquidationEngineForTest is LiquidationEngine {
  using EnumerableSet for EnumerableSet.AddressSet;

  constructor(
    address _safeEngine,
    address _accountingEngine,
    LiquidationEngineParams memory _params
  ) LiquidationEngine(_safeEngine, _accountingEngine, _params) {}

  function setCollateralAuctionHouse(bytes32 _collateralType, address _collateralAuctionHouse) external {
    _cParams[_collateralType].collateralAuctionHouse = _collateralAuctionHouse;
    _authorizedAccounts.add(_collateralAuctionHouse);
  }

  function setAccountingEngine(address _accountingEngine) external {
    accountingEngine = IAccountingEngine(_accountingEngine);
  }
}

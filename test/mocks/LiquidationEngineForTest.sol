// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {LiquidationEngine} from '@contracts/LiquidationEngine.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';

import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

contract LiquidationEngineForTest is LiquidationEngine {
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  constructor(
    address _safeEngine,
    address _accountingEngine,
    LiquidationEngineParams memory _liqEngineParams
  ) LiquidationEngine(_safeEngine, _accountingEngine, _liqEngineParams) {}

  function setCollateralAuctionHouse(bytes32 _cType, address _collateralAuctionHouse) external {
    _cParams[_cType].collateralAuctionHouse = _collateralAuctionHouse;
    _authorizedAccounts.add(_collateralAuctionHouse);
  }

  function setAccountingEngine(address _accountingEngine) external {
    accountingEngine = IAccountingEngine(_accountingEngine);
  }

  function addToCollateralList(bytes32 _cType) external {
    _collateralList.add(_cType);
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TaxCollector, ITaxCollector} from '@contracts/TaxCollector.sol';

contract TaxCollectorForTest is TaxCollector {
  constructor(address _safeEngine) TaxCollector(_safeEngine) {}

  function splitTaxIncome(bytes32 _collateralType, uint256 _debtAmount, int256 _deltaRate) external {
    _splitTaxIncome(_collateralType, _debtAmount, _deltaRate);
  }

  function distributeTax(
    bytes32 _collateralType,
    address _receiver,
    uint256 _receiverListPosition,
    uint256 _debtAmount,
    int256 _deltaRate
  ) external {
    _distributeTax(_collateralType, _receiver, _receiverListPosition, _debtAmount, _deltaRate);
  }
}

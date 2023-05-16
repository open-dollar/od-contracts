// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IOracle} from '@interfaces/IOracle.sol';
import {OracleRelayer} from '@contracts/OracleRelayer.sol';

contract OracleRelayerForTest is OracleRelayer {
  constructor(address _safeEngine) OracleRelayer(_safeEngine) {}

  // function to mock oracle since we can get a slot with sdstorage
  function setCTypeOracle(bytes32 _cType, address _oracle) external {
    _cParams[_cType].oracle = IOracle(_oracle);
  }

  function setRedemptionPrice(uint256 _price) external {
    _redemptionPrice = _price;
  }

  function callUpdateRedemptionPrice() external returns (uint256 _redemptionPrice) {
    _redemptionPrice = _updateRedemptionPrice();
  }
}

contract OracleRelayerForInternalCallsTest is OracleRelayerForTest {
  event UpdateRedemptionPriceCalled();
  event GetRedemptionPriceCalled();

  constructor(address _safeEngine) OracleRelayerForTest(_safeEngine) {}

  function _updateRedemptionPrice() internal override returns (uint256 _redemptionPrice) {
    emit UpdateRedemptionPriceCalled();
    return super._updateRedemptionPrice();
  }

  function _getRedemptionPrice() internal override returns (uint256 _redemptionPrice) {
    emit GetRedemptionPriceCalled();
    return super._getRedemptionPrice();
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {OracleRelayer, IOracleRelayer, EnumerableSet} from '@contracts/OracleRelayer.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

contract OracleRelayerForTest is OracleRelayer {
  using EnumerableSet for EnumerableSet.Bytes32Set;

  constructor(
    address _safeEngine,
    IBaseOracle _systemCoinOracle,
    OracleRelayerParams memory _oracleRelayerParams
  ) OracleRelayer(_safeEngine, _systemCoinOracle, _oracleRelayerParams) {}

  // function to mock oracle since we can get a slot with sdstorage
  function setCTypeOracle(bytes32 _cType, address _oracle) external {
    _cParams[_cType].oracle = IDelayedOracle(_oracle);
  }

  function addToCollateralList(bytes32 _cType) external {
    _collateralList.add(_cType);
  }

  function setRedemptionPrice(uint256 _price) external {
    _redemptionPrice = _price;
  }

  function setContractEnabled(bool _contractEnabled) external {
    contractEnabled = _contractEnabled;
  }

  function callUpdateRedemptionPrice() external returns (uint256 _redemptionPrice) {
    return _updateRedemptionPrice();
  }

  function getRedemptionPrice() external view returns (uint256 __redemptionPrice) {
    return _redemptionPrice;
  }
}

contract OracleRelayerForInternalCallsTest is OracleRelayerForTest {
  event UpdateRedemptionPriceCalled();
  event GetRedemptionPriceCalled();

  constructor(
    address _safeEngine,
    IBaseOracle _systemCoinOracle,
    OracleRelayerParams memory _oracleRelayerParams
  ) OracleRelayerForTest(_safeEngine, _systemCoinOracle, _oracleRelayerParams) {}

  function _updateRedemptionPrice() internal override returns (uint256 _redemptionPrice) {
    emit UpdateRedemptionPriceCalled();
    return super._updateRedemptionPrice();
  }

  function _getRedemptionPrice() internal override returns (uint256 _redemptionPrice) {
    emit GetRedemptionPriceCalled();
    return super._getRedemptionPrice();
  }
}

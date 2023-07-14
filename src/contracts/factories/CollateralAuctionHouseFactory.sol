// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICollateralAuctionHouseFactory} from '@interfaces/factories/ICollateralAuctionHouseFactory.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';

import {CollateralAuctionHouseChild} from '@contracts/factories/CollateralAuctionHouseChild.sol';

import {Authorizable, IAuthorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable, IDisableable} from '@contracts/utils/Disableable.sol';
import {Modifiable, IModifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {WAD} from '@libraries/Math.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

contract CollateralAuctionHouseFactory is Authorizable, Disableable, Modifiable, ICollateralAuctionHouseFactory {
  using Assertions for uint256;
  using Assertions for address;
  using Encoding for bytes;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  // --- Registry ---
  address public safeEngine;
  address public liquidationEngine;
  address public oracleRelayer;

  // --- Data ---
  // solhint-disable-next-line private-vars-leading-underscore
  ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams public _params;

  function params()
    external
    view
    returns (ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _cahParams)
  {
    return _params;
  }

  function cParams(bytes32 _cType)
    external
    view
    returns (ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahCParams)
  {
    return ICollateralAuctionHouse(collateralAuctionHouses[_cType]).cParams();
  }

  // solhint-disable-next-line private-vars-leading-underscore
  function _cParams(bytes32 _cType)
    external
    view
    returns (
      uint256 _minimumBid,
      uint256 _minDiscount,
      uint256 _maxDiscount,
      uint256 _perSecondDiscountUpdateRate,
      uint256 _lowerCollateralDeviation,
      uint256 _upperCollateralDeviation
    )
  {
    return ICollateralAuctionHouse(collateralAuctionHouses[_cType])._cParams();
  }

  mapping(bytes32 => address) public collateralAuctionHouses;

  EnumerableSet.Bytes32Set internal _collateralList;

  // --- Init ---
  constructor(
    address _safeEngine,
    address _oracleRelayer,
    address _liquidationEngine,
    ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _cahParams
  ) Authorizable(msg.sender) validParams {
    safeEngine = _safeEngine.assertNonNull();
    oracleRelayer = _oracleRelayer;
    _setLiquidationEngine(_liquidationEngine);

    _params = _cahParams;
  }

  // --- Methods ---
  function deployCollateralAuctionHouse(
    bytes32 _cType,
    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahCParams
  ) external isAuthorized whenEnabled returns (address _collateralAuctionHouse) {
    if (!_collateralList.add(_cType)) revert CAHFactory_CAHExists();

    ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _emptyCahParams;

    _collateralAuctionHouse = address(
      new CollateralAuctionHouseChild({
      _safeEngine: safeEngine,
      _oracleRelayer: address(0), // read from factory
      _liquidationEngine: address(0), // read from factory
      _cType: _cType, 
      _cahParams: _emptyCahParams, // read from factory
      _cahCParams: _cahCParams
      })
    );

    collateralAuctionHouses[_cType] = _collateralAuctionHouse;
    emit DeployCollateralAuctionHouse(_cType, _collateralAuctionHouse);
  }

  // --- Views ---
  function collateralList() external view returns (bytes32[] memory __collateralList) {
    return _collateralList.values();
  }

  function collateralAuctionHousesList() external view returns (address[] memory _collateralAuctionHousesList) {
    bytes32[] memory __collateralList = _collateralList.values();
    _collateralAuctionHousesList = new address[](__collateralList.length);
    for (uint256 _i; _i < __collateralList.length; ++_i) {
      _collateralAuctionHousesList[_i] = collateralAuctionHouses[__collateralList[_i]];
    }
  }

  // --- Administration ---
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();
    address _address = _data.toAddress();

    // Registry
    if (_param == 'oracleRelayer') oracleRelayer = _address;
    else if (_param == 'liquidationEngine') _setLiquidationEngine(_address);
    // SystemCoin Params
    else if (_param == 'lowerSystemCoinDeviation') _params.lowerSystemCoinDeviation = _uint256;
    else if (_param == 'upperSystemCoinDeviation') _params.upperSystemCoinDeviation = _uint256;
    else if (_param == 'minSystemCoinDeviation') _params.minSystemCoinDeviation = _uint256;
    else revert UnrecognizedParam();
  }

  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal override {
    if (!_collateralList.contains(_cType)) revert UnrecognizedCType();
    IModifiable(collateralAuctionHouses[_cType]).modifyParameters(_cType, _param, _data);
  }

  function _setLiquidationEngine(address _newLiquidationEngine) internal {
    if (liquidationEngine != address(0)) _removeAuthorization(liquidationEngine);
    liquidationEngine = _newLiquidationEngine;
    _addAuthorization(_newLiquidationEngine);
  }

  function _validateParameters() internal view override {
    // SystemCoin Auction House
    _params.lowerSystemCoinDeviation.assertLtEq(WAD);
    _params.upperSystemCoinDeviation.assertLtEq(WAD);

    // Liquidation Engine
    oracleRelayer.assertNonNull();
    liquidationEngine.assertNonNull();
  }
}

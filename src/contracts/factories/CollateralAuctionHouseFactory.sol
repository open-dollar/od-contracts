// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICollateralAuctionHouseFactory} from '@interfaces/factories/ICollateralAuctionHouseFactory.sol';
import {IIncreasingDiscountCollateralAuctionHouse} from '@interfaces/IIncreasingDiscountCollateralAuctionHouse.sol';

import {CollateralAuctionHouseChild} from '@contracts/factories/CollateralAuctionHouseChild.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Disableable, IDisableable} from '@contracts/utils/Disableable.sol';
import {Modifiable, IModifiable} from '@contracts/utils/Modifiable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {WAD} from '@libraries/Math.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

contract CollateralAuctionHouseFactory is Authorizable, Disableable, Modifiable, ICollateralAuctionHouseFactory {
  using EnumerableSet for EnumerableSet.AddressSet;
  using Assertions for uint256;
  using Assertions for address;
  using Encoding for bytes;

  // --- Registry ---
  address public safeEngine;
  address public liquidationEngine;
  address public oracleRelayer;

  // --- Data ---
  IIncreasingDiscountCollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams internal _params;

  function params()
    external
    view
    returns (IIncreasingDiscountCollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _cahParams)
  {
    return _params;
  }

  // TODO: add cParams(_cType) => queries CAH.cParams()

  EnumerableSet.AddressSet internal _collateralAuctionHouses;
  mapping(bytes32 => address) public collateralAuctionHouse;

  // --- Init ---
  constructor(
    address _safeEngine,
    address _oracleRelayer,
    address _liquidationEngine,
    IIncreasingDiscountCollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _cahParams
  ) Authorizable(msg.sender) validParams {
    safeEngine = _safeEngine;
    oracleRelayer = _oracleRelayer;
    liquidationEngine = _liquidationEngine;

    _params = _cahParams;
  }

  // --- Methods ---
  function deployCollateralAuctionHouse(
    bytes32 _cType,
    IIncreasingDiscountCollateralAuctionHouse.CollateralAuctionHouseParams memory _cahCParams
  ) external isAuthorized whenEnabled returns (address _collateralAuctionHouse) {
    // TODO: check that cType doesn't yet exist
    IIncreasingDiscountCollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _emptyCahParams;

    _collateralAuctionHouse = address(
      new CollateralAuctionHouseChild({
      _safeEngine: safeEngine,
      _oracleRelayer: address(0), // read from factory
      _liquidationEngine: address(0), // read from factory
      _collateralType: _cType, 
      _cahParams: _emptyCahParams, // read from factory
      _cahCParams: _cahCParams
      })
    );

    _collateralAuctionHouses.add(_collateralAuctionHouse);
    collateralAuctionHouse[_cType] = _collateralAuctionHouse;
    // TODO: rm from event
    emit DeployCollateralAuctionHouse(_cType, address(420), _collateralAuctionHouse);
  }

  // TODO: input cType
  function disableCollateralAuctionHouse(address _collateralAuctionHouse) external isAuthorized {
    if (!_collateralAuctionHouses.remove(_collateralAuctionHouse)) {
      revert CollateralAuctionHouseFactory_NotCollateralAuctionHouse();
    }
    IDisableable(address(_collateralAuctionHouse)).disableContract();
    // TODO: delete collateralAuctionHouse[_cType];
    emit DisableCollateralAuctionHouse(_collateralAuctionHouse);
  }

  // --- Views ---
  function collateralAuctionHousesList() external view returns (address[] memory _collateralAuctionHousesList) {
    return _collateralAuctionHouses.values();
  }

  // --- Administration ---
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    uint256 _uint256 = _data.toUint256();
    address _address = _data.toAddress();

    // Registry
    if (_param == 'oracleRelayer') oracleRelayer = _address;
    else if (_param == 'liquidationEngine') liquidationEngine = _address;
    // SystemCoin Params
    else if (_param == 'lowerSystemCoinDeviation') _params.lowerSystemCoinDeviation = _uint256;
    else if (_param == 'upperSystemCoinDeviation') _params.upperSystemCoinDeviation = _uint256;
    else if (_param == 'minSystemCoinDeviation') _params.minSystemCoinDeviation = _uint256;
  }

  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal override {
    IModifiable(collateralAuctionHouse[_cType]).modifyParameters(_cType, _param, _data);
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

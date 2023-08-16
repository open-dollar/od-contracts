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

  function cParams(bytes32 _cType)
    external
    view
    returns (ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahParams)
  {
    return ICollateralAuctionHouse(collateralAuctionHouses[_cType]).params();
  }

  // solhint-disable-next-line private-vars-leading-underscore
  function _cParams(bytes32 _cType)
    external
    view
    returns (uint256 _minimumBid, uint256 _minDiscount, uint256 _maxDiscount, uint256 _perSecondDiscountUpdateRate)
  {
    return ICollateralAuctionHouse(collateralAuctionHouses[_cType])._params();
  }

  mapping(bytes32 => address) public collateralAuctionHouses;

  EnumerableSet.Bytes32Set internal _collateralList;

  // --- Init ---
  constructor(
    address _safeEngine,
    address _liquidationEngine,
    address _oracleRelayer
  ) Authorizable(msg.sender) validParams {
    safeEngine = _safeEngine.assertNonNull();
    _setLiquidationEngine(_liquidationEngine);
    oracleRelayer = _oracleRelayer;
  }

  // --- Methods ---
  function deployCollateralAuctionHouse(
    bytes32 _cType,
    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahParams
  ) external isAuthorized whenEnabled returns (ICollateralAuctionHouse _collateralAuctionHouse) {
    if (!_collateralList.add(_cType)) revert CAHFactory_CAHExists();

    _collateralAuctionHouse = new CollateralAuctionHouseChild({
      _safeEngine: safeEngine,
      _liquidationEngine: address(0), // read from factory
      _oracleRelayer: address(0), // read from factory
      _cType: _cType,
      _cahParams: _cahParams
      });

    collateralAuctionHouses[_cType] = address(_collateralAuctionHouse);
    emit DeployCollateralAuctionHouse(_cType, address(_collateralAuctionHouse));
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
    address _address = _data.toAddress();

    // Registry
    if (_param == 'liquidationEngine') _setLiquidationEngine(_address);
    else if (_param == 'oracleRelayer') oracleRelayer = _address;
    else revert UnrecognizedParam();
  }

  function _modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) internal override {
    if (!_collateralList.contains(_cType)) revert UnrecognizedCType();
    IModifiable(collateralAuctionHouses[_cType]).modifyParameters(_param, _data);
  }

  function _setLiquidationEngine(address _newLiquidationEngine) internal {
    if (liquidationEngine != address(0)) _removeAuthorization(liquidationEngine);
    liquidationEngine = _newLiquidationEngine;
    _addAuthorization(_newLiquidationEngine);
  }

  function _validateParameters() internal view override {
    liquidationEngine.assertNonNull();
    oracleRelayer.assertNonNull();
  }
}

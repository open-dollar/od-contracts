// SPDX-License-Identifier: GPL-3.0
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

import {ITaxCollector, ISAFEEngine, GLOBAL_PARAM} from '@interfaces/ITaxCollector.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {Math, RAY} from '@libraries/Math.sol';
import {Encoding} from '@libraries/Encoding.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

contract TaxCollector is Authorizable, ITaxCollector {
  using Math for uint256;
  using Encoding for bytes;
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  // --- Data ---
  // Data about each collateral type
  mapping(bytes32 => CollateralType) public collateralTypes;
  // Each collateral type that sends SF to a specific tax receiver
  mapping(address => EnumerableSet.Bytes32Set) internal _secondaryReceiverRevenueSources;
  // Tax receiver data
  mapping(bytes32 => mapping(address => TaxReceiver)) internal _secondaryTaxReceivers;

  function secondaryTaxReceiver(
    bytes32 _cType,
    address _receiver
  ) external view returns (TaxReceiver memory _secondaryTaxReceiver) {
    return _secondaryTaxReceivers[_cType][_receiver];
  }

  // TODO: mv to cData
  // Percentage of each collateral's SF that goes to other addresses apart from the primary receiver
  mapping(bytes32 => uint256) public secondaryReceiverAllotedTax; // [%ray]

  // The address that always receives some SF
  address public primaryTaxReceiver;
  // Base stability fee charged to all collateral types
  uint256 public globalStabilityFee; // [ray%]
  // Max number of secondarytax receivers a collateral type can have
  uint256 public maxSecondaryReceivers;

  uint256 public constant WHOLE_TAX_CUT = 10 ** 29;

  // All collateral types
  EnumerableSet.Bytes32Set internal _collateralList;
  // Enumerable set with tax receiver data
  EnumerableSet.AddressSet internal _secondaryReceivers;

  // --- Registry ---
  ISAFEEngine public safeEngine;

  // --- Init ---
  constructor(address _safeEngine) Authorizable(msg.sender) {
    safeEngine = ISAFEEngine(_safeEngine);
  }

  /**
   * @notice Initialize a brand new collateral type
   * @param _cType Collateral type name (e.g ETH-A, TBTC-B)
   */
  function initializeCollateralType(bytes32 _cType) external isAuthorized {
    CollateralType storage _collateralType = collateralTypes[_cType];
    require(_collateralType.stabilityFee == 0, 'TaxCollector/collateral-type-already-init');
    _collateralType.stabilityFee = RAY;
    _collateralType.updateTime = block.timestamp;
    _collateralList.add(_cType);
    emit InitializeCollateralType(_cType);
  }

  // --- Tax Collection Utils ---
  /**
   * @notice Check if multiple collateral types are up to date with taxation
   */
  function collectedManyTax(uint256 _start, uint256 _end) public view returns (bool _ok) {
    require(_start <= _end && _end < _collateralList.length(), 'TaxCollector/invalid-indexes');
    for (uint256 _i = _start; _i <= _end; ++_i) {
      if (block.timestamp > collateralTypes[_collateralList.at(_i)].updateTime) {
        _ok = false;
        return _ok;
      }
    }
    _ok = true;
  }

  /**
   * @notice Check how much SF will be charged (to collateral types between indexes 'start' and 'end'
   *         in the collateralList) during the next taxation
   * @param _start Index in collateralList from which to start looping and calculating the tax outcome
   * @param _end Index in collateralList at which we stop looping and calculating the tax outcome
   */
  function taxManyOutcome(uint256 _start, uint256 _end) public view returns (bool _ok, int256 _rad) {
    require(_start <= _end && _end < _collateralList.length(), 'TaxCollector/invalid-indexes');
    int256 _primaryReceiverBalance = -safeEngine.coinBalance(primaryTaxReceiver).toIntNotOverflow();
    int256 _deltaRate;
    uint256 _debtAmount;
    for (uint256 _i = _start; _i <= _end; ++_i) {
      if (block.timestamp > collateralTypes[_collateralList.at(_i)].updateTime) {
        _debtAmount = safeEngine.cData(_collateralList.at(_i)).debtAmount;
        (, _deltaRate) = taxSingleOutcome(_collateralList.at(_i));
        _rad = _rad + _debtAmount.mul(_deltaRate);
      }
    }
    if (_rad < 0) {
      _ok = _rad >= _primaryReceiverBalance;
    } else {
      _ok = true;
    }
  }

  /**
   * @notice Get how much SF will be distributed after taxing a specific collateral type
   * @param _cType Collateral type to compute the taxation outcome for
   * @return _newlyAccumulatedRate The newly accumulated rate
   * @return _deltaRate The delta between the new and the last accumulated rates
   */
  function taxSingleOutcome(bytes32 _cType) public view returns (uint256 _newlyAccumulatedRate, int256 _deltaRate) {
    uint256 _lastAccumulatedRate = safeEngine.cData(_cType).accumulatedRate;
    _newlyAccumulatedRate = (globalStabilityFee + collateralTypes[_cType].stabilityFee).rpow(
      block.timestamp - collateralTypes[_cType].updateTime
    ).rmul(_lastAccumulatedRate);
    return (_newlyAccumulatedRate, _newlyAccumulatedRate.sub(_lastAccumulatedRate));
  }

  // --- Tax Receiver Utils ---
  /**
   * @notice Get the secondary tax receiver list length
   */
  function secondaryReceiversListLength() public view returns (uint256 _secondaryReceiversListLength) {
    return _secondaryReceivers.length();
  }

  /**
   * @notice Get the collateralList length
   */
  function collateralListLength() public view returns (uint256 _collateralListLength) {
    return _collateralList.length();
  }

  /**
   * @notice Check if a tax receiver is at a certain position in the list
   */
  function isSecondaryReceiver(address _receiver) public view returns (bool _isSecondaryReceiver) {
    return _secondaryReceivers.contains(_receiver);
  }

  // --- Views ---
  function collateralListList() external view returns (bytes32[] memory _collateralListList) {
    return _collateralList.values();
  }

  function secondaryReceiversList() external view returns (address[] memory _secondaryReceiversList) {
    return _secondaryReceivers.values();
  }

  function secondaryReceiverRevenueSourcesList(address _secondaryReceiver)
    external
    view
    returns (bytes32[] memory _secondaryReceiverRevenueSourcesList)
  {
    return _secondaryReceiverRevenueSources[_secondaryReceiver].values();
  }

  // --- Tax (Stability Fee) Collection ---
  /**
   * @notice Collect tax from multiple collateral types at once
   * @param _start Index in collateralList from which to start looping and calculating the tax outcome
   * @param _end Index in collateralList at which we stop looping and calculating the tax outcome
   */
  function taxMany(uint256 _start, uint256 _end) external {
    require(_start <= _end && _end < _collateralList.length(), 'TaxCollector/invalid-indexes');
    for (uint256 _i = _start; _i <= _end; ++_i) {
      taxSingle(_collateralList.at(_i));
    }
  }

  /**
   * @notice Collect tax from a single collateral type
   * @param _cType Collateral type to tax
   */
  function taxSingle(bytes32 _cType) public returns (uint256 _latestAccumulatedRate) {
    if (block.timestamp <= collateralTypes[_cType].updateTime) {
      _latestAccumulatedRate = safeEngine.cData(_cType).accumulatedRate;
      return _latestAccumulatedRate;
    }
    (, int256 _deltaRate) = taxSingleOutcome(_cType);
    // Check how much debt has been generated for collateralType
    uint256 _debtAmount = safeEngine.cData(_cType).debtAmount;
    _splitTaxIncome(_cType, _debtAmount, _deltaRate);
    _latestAccumulatedRate = safeEngine.cData(_cType).accumulatedRate;
    collateralTypes[_cType].updateTime = block.timestamp;
    emit CollectTax(_cType, _latestAccumulatedRate, _deltaRate);
    return _latestAccumulatedRate;
  }

  /**
   * @notice Split SF between all tax receivers
   * @param _cType Collateral type to distribute SF for
   * @param _deltaRate Difference between the last and the latest accumulate rates for the collateralType
   */
  function _splitTaxIncome(bytes32 _cType, uint256 _debtAmount, int256 _deltaRate) internal {
    // Start looping from the oldest tax receiver
    address _secondaryReceiver;
    uint256 _secondaryReceiversListLength = _secondaryReceivers.length();
    // Loop through the entire tax receiver list
    for (uint256 _i; _i < _secondaryReceiversListLength; ++_i) {
      _secondaryReceiver = _secondaryReceivers.at(_i);
      // If the current tax receiver should receive SF from collateralType
      if (_secondaryTaxReceivers[_cType][_secondaryReceiver].taxPercentage > 0) {
        _distributeTax(_cType, _secondaryReceiver, _debtAmount, _deltaRate);
      }
    }
    // Distribute to primary receiver
    _distributeTax(_cType, primaryTaxReceiver, _debtAmount, _deltaRate);
  }

  /**
   * @notice Give/withdraw SF from a tax receiver
   * @param _cType Collateral type to distribute SF for
   * @param _receiver Tax receiver address
   * @param _debtAmount Total debt currently issued
   * @param _deltaRate Difference between the latest and the last accumulated rates for the collateralType
   */
  function _distributeTax(bytes32 _cType, address _receiver, uint256 _debtAmount, int256 _deltaRate) internal {
    // Check how many coins the receiver has and negate the value
    int256 _coinBalance = -safeEngine.coinBalance(_receiver).toIntNotOverflow();
    // Compute the % out of SF that should be allocated to the receiver
    int256 _currentTaxCut = (_receiver == primaryTaxReceiver)
      ? (WHOLE_TAX_CUT - secondaryReceiverAllotedTax[_cType]).mul(_deltaRate) / int256(WHOLE_TAX_CUT)
      : int256(uint256(_secondaryTaxReceivers[_cType][_receiver].taxPercentage)) * _deltaRate / int256(WHOLE_TAX_CUT);
    /**
     * If SF is negative and a tax receiver doesn't have enough coins to absorb the loss,
     *           compute a new tax cut that can be absorbed
     */
    _currentTaxCut = _debtAmount.mul(_currentTaxCut) < 0 && _coinBalance > _debtAmount.mul(_currentTaxCut)
      ? _coinBalance / int256(_debtAmount)
      : _currentTaxCut;
    /**
     * If the tax receiver's tax cut is not null and if the receiver accepts negative SF
     *         offer/take SF to/from them
     */
    if (_currentTaxCut != 0) {
      if (
        _receiver == primaryTaxReceiver || (_deltaRate >= 0 || _secondaryTaxReceivers[_cType][_receiver].canTakeBackTax)
      ) {
        safeEngine.updateAccumulatedRate(_cType, _receiver, _currentTaxCut);
        emit DistributeTax(_cType, _receiver, _currentTaxCut);
      }
    }
  }

  // --- Admin ---
  /**
   * @notice Modify general parameters
   * @param _param The name of the parameter modified
   * @param _data New value for the parameter
   */
  function modifyParameters(bytes32 _param, bytes memory _data) external isAuthorized {
    uint256 _uint256 = _data.toUint256();

    if (_param == 'primaryTaxReceiver') _setPrimaryTaxReceiver(_data.toAddress());
    else if (_param == 'globalStabilityFee') globalStabilityFee = _uint256;
    else if (_param == 'maxSecondaryReceivers') maxSecondaryReceivers = _uint256;
    else revert UnrecognizedParam();

    emit ModifyParameters(_param, GLOBAL_PARAM, _data);
  }

  function _setPrimaryTaxReceiver(address _primaryTaxReceiver) internal {
    require(_primaryTaxReceiver != address(0), 'TaxCollector/null-data');
    primaryTaxReceiver = _primaryTaxReceiver;
    emit SetPrimaryReceiver(GLOBAL_PARAM, _primaryTaxReceiver);
  }

  /**
   * @notice Modify collateral specific params
   * @param _cType Collateral type we modify params for
   * @param _param The name of the parameter modified
   * @param _data New value for the parameter
   */
  function modifyParameters(bytes32 _cType, bytes32 _param, bytes memory _data) external isAuthorized {
    if (_param == 'stabilityFee') _setStabilityFee(_cType, _data.toUint256());
    else if (_param == 'secondaryTaxReceiver') _setSecondaryTaxReceiver(_cType, abi.decode(_data, (TaxReceiver)));
    else revert UnrecognizedParam();

    emit ModifyParameters(_param, _cType, _data);
  }

  /**
   * @notice Set a new stability fee for a collateral type
   * @dev    Needs to be called at the exact time the SF is collected
   * @param _cType Collateral type we update the stability fee for
   * @param _stabilityFee The SF value to set
   */
  function _setStabilityFee(bytes32 _cType, uint256 _stabilityFee) internal {
    require(block.timestamp == collateralTypes[_cType].updateTime, 'TaxCollector/update-time-not-now');
    collateralTypes[_cType].stabilityFee = _stabilityFee;
  }

  /**
   * @notice Add a new secondary tax receiver or update data (add a new SF source or modify % of SF taken from a collateral type)
   * @param _cType Collateral type that will give SF to the tax receiver
   * @param _data Encoded data containing the receiver, tax percentage, and whether it supports negative tax
   */
  function _setSecondaryTaxReceiver(bytes32 _cType, TaxReceiver memory _data) internal {
    require(_data.receiver != address(0), 'TaxCollector/null-account');
    require(_data.receiver != primaryTaxReceiver, 'TaxCollector/primary-receiver-cannot-be-secondary');

    if (_secondaryReceivers.add(_data.receiver)) {
      require(_secondaryReceivers.length() <= maxSecondaryReceivers, 'TaxCollector/exceeds-max-receiver-limit');
      require(_data.taxPercentage > 0, 'TaxCollector/null-sf');
      require(
        secondaryReceiverAllotedTax[_cType] + _data.taxPercentage < WHOLE_TAX_CUT,
        'TaxCollector/tax-cut-exceeds-hundred'
      );

      secondaryReceiverAllotedTax[_cType] += _data.taxPercentage;
      _secondaryReceiverRevenueSources[_data.receiver].add(_cType);
      _secondaryTaxReceivers[_cType][_data.receiver] = _data;
    } else {
      if (_data.taxPercentage == 0) {
        secondaryReceiverAllotedTax[_cType] -= _secondaryTaxReceivers[_cType][_data.receiver].taxPercentage;

        _secondaryReceiverRevenueSources[_data.receiver].remove(_cType);
        if (_secondaryReceiverRevenueSources[_data.receiver].length() == 0) {
          _secondaryReceivers.remove(_data.receiver);
        }

        delete(_secondaryTaxReceivers[_cType][_data.receiver]);
      } else {
        uint256 _secondaryReceiverAllotedTax = (
          secondaryReceiverAllotedTax[_cType] - _secondaryTaxReceivers[_cType][_data.receiver].taxPercentage
        ) + _data.taxPercentage;
        require(_secondaryReceiverAllotedTax < WHOLE_TAX_CUT, 'TaxCollector/tax-cut-too-big');

        secondaryReceiverAllotedTax[_cType] = _secondaryReceiverAllotedTax;
        _secondaryTaxReceivers[_cType][_data.receiver] = _data;
        // NOTE: if it was already added it just ignores it
        _secondaryReceiverRevenueSources[_data.receiver].add(_cType);
      }
    }

    emit SetSecondaryReceiver(
      _cType,
      _data.receiver,
      _secondaryTaxReceivers[_cType][_data.receiver].taxPercentage,
      _secondaryTaxReceivers[_cType][_data.receiver].canTakeBackTax
    );
  }
}

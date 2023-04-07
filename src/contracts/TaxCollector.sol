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

import {ITaxCollector, SAFEEngineLike} from '@interfaces/ITaxCollector.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {Math, RAY} from '@libraries/Math.sol';
import {LinkedList} from '@libraries/LinkedList.sol';

contract TaxCollector is ITaxCollector, Authorizable {
  using Math for uint256;
  using LinkedList for LinkedList.List;

  // --- Data ---
  // Data about each collateral type
  mapping(bytes32 => CollateralType) public collateralTypes;
  // Percentage of each collateral's SF that goes to other addresses apart from the primary receiver
  mapping(bytes32 => uint256) public secondaryReceiverAllotedTax; // [%ray]
  // Whether an address is already used for a tax receiver
  mapping(address => uint256) public usedSecondaryReceiver; // [bool]
  // Address associated to each tax receiver index
  mapping(uint256 => address) public secondaryReceiverAccounts;
  // How many collateral types send SF to a specific tax receiver
  mapping(address => uint256) public secondaryReceiverRevenueSources;
  // Tax receiver data
  mapping(bytes32 => mapping(uint256 => TaxReceiver)) public secondaryTaxReceivers;

  // The address that always receives some SF
  address public primaryTaxReceiver;
  // Base stability fee charged to all collateral types
  uint256 public globalStabilityFee; // [ray%]
  // Number of secondary tax receivers ever added
  uint256 public secondaryReceiverNonce;
  // Max number of secondarytax receivers a collateral type can have
  uint256 public maxSecondaryReceivers;
  // Latest secondary tax receiver that still has at least one revenue source
  uint256 public latestSecondaryReceiver;

  uint256 public constant WHOLE_TAX_CUT = 10 ** 29;

  // All collateral types
  bytes32[] public collateralList;
  // Linked list with tax receiver data
  LinkedList.List internal _secondaryReceiverList;

  SAFEEngineLike public safeEngine;

  // --- Init ---
  constructor(address _safeEngine) {
    _addAuthorization(msg.sender);
    safeEngine = SAFEEngineLike(_safeEngine);
    emit AddAuthorization(msg.sender);
  }

  // --- Administration ---
  /**
   * @notice Initialize a brand new collateral type
   * @param _collateralType Collateral type name (e.g ETH-A, TBTC-B)
   */
  function initializeCollateralType(bytes32 _collateralType) external isAuthorized {
    CollateralType storage collateralType_ = collateralTypes[_collateralType];
    require(collateralType_.stabilityFee == 0, 'TaxCollector/collateral-type-already-init');
    collateralType_.stabilityFee = RAY;
    collateralType_.updateTime = block.timestamp;
    collateralList.push(_collateralType);
    emit InitializeCollateralType(_collateralType);
  }

  /**
   * @notice Modify collateral specific uint256 params
   * @param _collateralType Collateral type who's parameter is modified
   * @param _parameter The name of the parameter modified
   * @param _data New value for the parameter
   */
  function modifyParameters(bytes32 _collateralType, bytes32 _parameter, uint256 _data) external isAuthorized {
    require(block.timestamp == collateralTypes[_collateralType].updateTime, 'TaxCollector/update-time-not-now');
    if (_parameter == 'stabilityFee') collateralTypes[_collateralType].stabilityFee = _data;
    else revert('TaxCollector/modify-unrecognized-param');
    emit ModifyParameters(_collateralType, _parameter, _data);
  }

  /**
   * @notice Modify general uint256 params
   * @param _parameter The name of the parameter modified
   * @param _data New value for the parameter
   */
  function modifyParameters(bytes32 _parameter, uint256 _data) external isAuthorized {
    if (_parameter == 'globalStabilityFee') globalStabilityFee = _data;
    else if (_parameter == 'maxSecondaryReceivers') maxSecondaryReceivers = _data;
    else revert('TaxCollector/modify-unrecognized-param');
    emit ModifyParameters(_parameter, _data);
  }

  /**
   * @notice Modify general address params
   * @param _parameter The name of the parameter modified
   * @param _data New value for the parameter
   */
  function modifyParameters(bytes32 _parameter, address _data) external isAuthorized {
    require(_data != address(0), 'TaxCollector/null-data');
    if (_parameter == 'primaryTaxReceiver') primaryTaxReceiver = _data;
    else revert('TaxCollector/modify-unrecognized-param');
    emit ModifyParameters(_parameter, _data);
  }

  /**
   * @notice Set whether a tax receiver can incur negative fees
   * @param _collateralType Collateral type giving fees to the tax receiver
   * @param _position Receiver position in the list
   * @param _val Value that specifies whether a tax receiver can incur negative rates
   */
  function modifyParameters(bytes32 _collateralType, uint256 _position, uint256 _val) external isAuthorized {
    if (_secondaryReceiverList.isNode(_position) && secondaryTaxReceivers[_collateralType][_position].taxPercentage > 0)
    {
      secondaryTaxReceivers[_collateralType][_position].canTakeBackTax = _val;
    } else {
      revert('TaxCollector/unknown-tax-receiver');
    }
    emit ModifyParameters(_collateralType, _position, _val);
  }

  /**
   * @notice Create or modify a secondary tax receiver's data
   * @param _collateralType Collateral type that will give SF to the tax receiver
   * @param _position Receiver position in the list. Used to determine whether a new tax receiver is
   *             created or an existing one is edited
   * @param _taxPercentage Percentage of SF offered to the tax receiver
   * @param _receiverAccount Receiver address
   */
  function modifyParameters(
    bytes32 _collateralType,
    uint256 _position,
    uint256 _taxPercentage,
    address _receiverAccount
  ) external isAuthorized {
    (!_secondaryReceiverList.isNode(_position))
      ? _addSecondaryReceiver(_collateralType, _taxPercentage, _receiverAccount)
      : _modifySecondaryReceiver(_collateralType, _position, _taxPercentage);
    emit ModifyParameters(_collateralType, _position, _taxPercentage, _receiverAccount);
  }

  // --- Tax Receiver Utils ---
  /**
   * @notice Add a new secondary tax receiver
   * @param _collateralType Collateral type that will give SF to the tax receiver
   * @param _taxPercentage Percentage of SF offered to the tax receiver
   * @param _receiverAccount Tax receiver address
   */
  function _addSecondaryReceiver(bytes32 _collateralType, uint256 _taxPercentage, address _receiverAccount) internal {
    require(_receiverAccount != address(0), 'TaxCollector/null-account');
    require(_receiverAccount != primaryTaxReceiver, 'TaxCollector/primary-receiver-cannot-be-secondary');
    require(_taxPercentage > 0, 'TaxCollector/null-sf');
    require(usedSecondaryReceiver[_receiverAccount] == 0, 'TaxCollector/account-already-used');
    require(secondaryReceiversAmount() + 1 <= maxSecondaryReceivers, 'TaxCollector/exceeds-max-receiver-limit');
    require(
      secondaryReceiverAllotedTax[_collateralType] + _taxPercentage < WHOLE_TAX_CUT,
      'TaxCollector/tax-cut-exceeds-hundred'
    );
    ++secondaryReceiverNonce;
    latestSecondaryReceiver = secondaryReceiverNonce;
    usedSecondaryReceiver[_receiverAccount] = 1;
    secondaryReceiverAllotedTax[_collateralType] = secondaryReceiverAllotedTax[_collateralType] + _taxPercentage;
    secondaryTaxReceivers[_collateralType][latestSecondaryReceiver].taxPercentage = _taxPercentage;
    secondaryReceiverAccounts[latestSecondaryReceiver] = _receiverAccount;
    secondaryReceiverRevenueSources[_receiverAccount] = 1;
    _secondaryReceiverList.push(latestSecondaryReceiver, false);
    emit AddSecondaryReceiver(
      _collateralType,
      secondaryReceiverNonce,
      latestSecondaryReceiver,
      secondaryReceiverAllotedTax[_collateralType],
      secondaryReceiverRevenueSources[_receiverAccount]
    );
  }

  /**
   * @notice Update a secondary tax receiver's data (add a new SF source or modify % of SF taken from a collateral type)
   * @param _collateralType Collateral type that will give SF to the tax receiver
   * @param _position Receiver's position in the tax receiver list
   * @param _taxPercentage Percentage of SF offered to the tax receiver (ray%)
   */
  function _modifySecondaryReceiver(bytes32 _collateralType, uint256 _position, uint256 _taxPercentage) internal {
    if (_taxPercentage == 0) {
      secondaryReceiverAllotedTax[_collateralType] =
        secondaryReceiverAllotedTax[_collateralType] - secondaryTaxReceivers[_collateralType][_position].taxPercentage;

      if (secondaryReceiverRevenueSources[secondaryReceiverAccounts[_position]] == 1) {
        if (_position == latestSecondaryReceiver) {
          (, uint256 _prevReceiver) = _secondaryReceiverList.prev(latestSecondaryReceiver);
          latestSecondaryReceiver = _prevReceiver;
        }
        _secondaryReceiverList.del(_position);
        delete(usedSecondaryReceiver[secondaryReceiverAccounts[_position]]);
        delete(secondaryTaxReceivers[_collateralType][_position]);
        delete(secondaryReceiverRevenueSources[secondaryReceiverAccounts[_position]]);
        delete(secondaryReceiverAccounts[_position]);
      } else if (secondaryTaxReceivers[_collateralType][_position].taxPercentage > 0) {
        --secondaryReceiverRevenueSources[secondaryReceiverAccounts[_position]];
        delete(secondaryTaxReceivers[_collateralType][_position]);
      }
    } else {
      uint256 _secondaryReceiverAllotedTax = (
        secondaryReceiverAllotedTax[_collateralType] - secondaryTaxReceivers[_collateralType][_position].taxPercentage
      ) + _taxPercentage;
      require(_secondaryReceiverAllotedTax < WHOLE_TAX_CUT, 'TaxCollector/tax-cut-too-big');
      if (secondaryTaxReceivers[_collateralType][_position].taxPercentage == 0) {
        ++secondaryReceiverRevenueSources[secondaryReceiverAccounts[_position]];
      }
      secondaryReceiverAllotedTax[_collateralType] = _secondaryReceiverAllotedTax;
      secondaryTaxReceivers[_collateralType][_position].taxPercentage = _taxPercentage;
    }
    emit ModifySecondaryReceiver(
      _collateralType,
      secondaryReceiverNonce,
      latestSecondaryReceiver,
      secondaryReceiverAllotedTax[_collateralType],
      secondaryReceiverRevenueSources[secondaryReceiverAccounts[_position]]
    );
  }

  // --- Tax Collection Utils ---
  /**
   * @notice Check if multiple collateral types are up to date with taxation
   */
  function collectedManyTax(uint256 _start, uint256 _end) public view returns (bool _ok) {
    require(_start <= _end && _end < collateralList.length, 'TaxCollector/invalid-indexes');
    for (uint256 _i = _start; _i <= _end; ++_i) {
      if (block.timestamp > collateralTypes[collateralList[_i]].updateTime) {
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
    require(_start <= _end && _end < collateralList.length, 'TaxCollector/invalid-indexes');
    int256 _primaryReceiverBalance = -int256(safeEngine.coinBalance(primaryTaxReceiver));
    int256 _deltaRate;
    uint256 _debtAmount;
    for (uint256 _i = _start; _i <= _end; ++_i) {
      if (block.timestamp > collateralTypes[collateralList[_i]].updateTime) {
        (_debtAmount,,,,,) = safeEngine.collateralTypes(collateralList[_i]);
        (, _deltaRate) = taxSingleOutcome(collateralList[_i]);
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
   * @param _collateralType Collateral type to compute the taxation outcome for
   * @return _newlyAccumulatedRate The newly accumulated rate
   * @return _deltaRate The delta between the new and the last accumulated rates
   */
  function taxSingleOutcome(bytes32 _collateralType)
    public
    view
    returns (uint256 _newlyAccumulatedRate, int256 _deltaRate)
  {
    (, uint256 _lastAccumulatedRate,,,,) = safeEngine.collateralTypes(_collateralType);
    _newlyAccumulatedRate = (globalStabilityFee + collateralTypes[_collateralType].stabilityFee).rpow(
      block.timestamp - collateralTypes[_collateralType].updateTime
    ).rmul(_lastAccumulatedRate);
    return (_newlyAccumulatedRate, _newlyAccumulatedRate.sub(_lastAccumulatedRate));
  }

  // --- Tax Receiver Utils ---
  /**
   * @notice Get the secondary tax receiver list length
   */
  function secondaryReceiversAmount() public view returns (uint256 _secondaryReceiversAmount) {
    return _secondaryReceiverList.range();
  }

  /**
   * @notice Get the collateralList length
   */
  function collateralListLength() public view returns (uint256 _collateralListLength) {
    return collateralList.length;
  }

  /**
   * @notice Check if a tax receiver is at a certain position in the list
   */
  function isSecondaryReceiver(uint256 _receiver) public view returns (bool _isSecondaryReceiver) {
    if (_receiver == 0) return false;
    return _secondaryReceiverList.isNode(_receiver);
  }

  // --- Tax (Stability Fee) Collection ---
  /**
   * @notice Collect tax from multiple collateral types at once
   * @param _start Index in collateralList from which to start looping and calculating the tax outcome
   * @param _end Index in collateralList at which we stop looping and calculating the tax outcome
   */
  function taxMany(uint256 _start, uint256 _end) external {
    require(_start <= _end && _end < collateralList.length, 'TaxCollector/invalid-indexes');
    for (uint256 _i = _start; _i <= _end; ++_i) {
      taxSingle(collateralList[_i]);
    }
  }

  /**
   * @notice Collect tax from a single collateral type
   * @param _collateralType Collateral type to tax
   */
  function taxSingle(bytes32 _collateralType) public returns (uint256 _latestAccumulatedRate) {
    if (block.timestamp <= collateralTypes[_collateralType].updateTime) {
      (, _latestAccumulatedRate,,,,) = safeEngine.collateralTypes(_collateralType);
      return _latestAccumulatedRate;
    }
    (, int256 _deltaRate) = taxSingleOutcome(_collateralType);
    // Check how much debt has been generated for collateralType
    (uint256 _debtAmount,,,,,) = safeEngine.collateralTypes(_collateralType);
    _splitTaxIncome(_collateralType, _debtAmount, _deltaRate);
    (, _latestAccumulatedRate,,,,) = safeEngine.collateralTypes(_collateralType);
    collateralTypes[_collateralType].updateTime = block.timestamp;
    emit CollectTax(_collateralType, _latestAccumulatedRate, _deltaRate);
    return _latestAccumulatedRate;
  }

  /**
   * @notice Split SF between all tax receivers
   * @param _collateralType Collateral type to distribute SF for
   * @param _deltaRate Difference between the last and the latest accumulate rates for the collateralType
   */
  function _splitTaxIncome(bytes32 _collateralType, uint256 _debtAmount, int256 _deltaRate) internal {
    // Start looping from the latest tax receiver
    uint256 _currentSecondaryReceiver = latestSecondaryReceiver;
    // While we still haven't gone through the entire tax receiver list
    while (_currentSecondaryReceiver > 0) {
      // If the current tax receiver should receive SF from collateralType
      if (secondaryTaxReceivers[_collateralType][_currentSecondaryReceiver].taxPercentage > 0) {
        _distributeTax(
          _collateralType,
          secondaryReceiverAccounts[_currentSecondaryReceiver],
          _currentSecondaryReceiver,
          _debtAmount,
          _deltaRate
        );
      }
      // Continue looping
      //(, _currentSecondaryReceiver) = _secondaryReceiverList.prev(_currentSecondaryReceiver);
      --_currentSecondaryReceiver; // REVIEW: Is it the same as above?
    }
    // Distribute to primary receiver
    _distributeTax(_collateralType, primaryTaxReceiver, type(uint256).max, _debtAmount, _deltaRate);
  }

  /**
   * @notice Give/withdraw SF from a tax receiver
   * @param _collateralType Collateral type to distribute SF for
   * @param _receiver Tax receiver address
   * @param _receiverListPosition Position of receiver in the secondaryReceiverList (if the receiver is secondary)
   * @param _debtAmount Total debt currently issued
   * @param _deltaRate Difference between the latest and the last accumulated rates for the collateralType
   */
  function _distributeTax(
    bytes32 _collateralType,
    address _receiver,
    uint256 _receiverListPosition,
    uint256 _debtAmount,
    int256 _deltaRate
  ) internal {
    require(safeEngine.coinBalance(_receiver) < 2 ** 255, 'TaxCollector/coin-balance-does-not-fit-into-int256');
    // Check how many coins the receiver has and negate the value
    int256 _coinBalance = -int256(safeEngine.coinBalance(_receiver));
    // Compute the % out of SF that should be allocated to the receiver
    int256 _currentTaxCut = (_receiver == primaryTaxReceiver)
      ? (WHOLE_TAX_CUT - secondaryReceiverAllotedTax[_collateralType]).mul(_deltaRate) / int256(WHOLE_TAX_CUT)
      : int256(secondaryTaxReceivers[_collateralType][_receiverListPosition].taxPercentage) * _deltaRate
        / int256(WHOLE_TAX_CUT);
    /**
     * If SF is negative and a tax receiver doesn't have enough coins to absorb the loss,
     *           compute a new tax cut that can be absorbed
     *
     */
    _currentTaxCut = (_debtAmount.mul(_currentTaxCut) < 0 && _coinBalance > _debtAmount.mul(_currentTaxCut))
      ? _coinBalance / int256(_debtAmount)
      : _currentTaxCut;
    /**
     * If the tax receiver's tax cut is not null and if the receiver accepts negative SF
     *         offer/take SF to/from them
     *
     */
    if (_currentTaxCut != 0) {
      if (
        _receiver == primaryTaxReceiver
          || (
            _deltaRate >= 0
              || (
                _currentTaxCut < 0 // REVIEW: May this check fail ever?
                  && secondaryTaxReceivers[_collateralType][_receiverListPosition].canTakeBackTax > 0
              )
          )
      ) {
        safeEngine.updateAccumulatedRate(_collateralType, _receiver, _currentTaxCut);
        emit DistributeTax(_collateralType, _receiver, _currentTaxCut);
      }
    }
  }
}

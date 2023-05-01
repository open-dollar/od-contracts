// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {TaxCollector, ITaxCollector, EnumerableSet} from '@contracts/TaxCollector.sol';

contract TaxCollectorForTest is TaxCollector {
  constructor(address _safeEngine) TaxCollector(_safeEngine) {}

  function splitTaxIncome(bytes32 _collateralType, uint256 _debtAmount, int256 _deltaRate) external {
    _splitTaxIncome(_collateralType, _debtAmount, _deltaRate);
  }

  function distributeTax(bytes32 _collateralType, address _receiver, uint256 _debtAmount, int256 _deltaRate) external {
    _distributeTax(_collateralType, _receiver, _debtAmount, _deltaRate);
  }

  function addSecondaryTaxReceiver(
    bytes32 _collateralType,
    address _receiver,
    bool _canTakeBackTax,
    uint128 _taxPercentage
  ) external {
    _secondaryTaxReceivers[_collateralType][_receiver].canTakeBackTax = _canTakeBackTax;
    _secondaryTaxReceivers[_collateralType][_receiver].taxPercentage = _taxPercentage;
  }

  function addToCollateralList(bytes32 _collateralType) external {
    _collateralList.add(_collateralType);
  }

  function addSecondaryReceiver(address _receiver) external {
    _secondaryReceivers.add(_receiver);
  }

  // --- Legacy test methods ---
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  uint256 canTakeBackTax;
  uint256 secondaryReceiverNonce;
  uint256 public latestSecondaryReceiver;

  function _secondaryReceiversAt(uint256 _index) internal view returns (address) {
    uint256 _correctedIndex = _index - 1; // NOTE: LinkedList starts at index 1, but EnumerableSet starts at index 0
    if (_correctedIndex < _secondaryReceivers.length()) return _secondaryReceivers.at(_correctedIndex);
    else return address(0);
  }

  function secondaryReceiverAccounts(uint256 _index) external view returns (address) {
    return _secondaryReceiversAt(_index);
  }

  function secondaryReceiversAmount() external view returns (uint256) {
    return _secondaryReceivers.length();
  }

  function usedSecondaryReceiver(address _receiver) external view returns (uint256 _usedSecondaryReceiver) {
    if (_secondaryReceivers.contains(_receiver)) {
      return 1;
    }
  }

  function isSecondaryReceiver(uint256 _receiverIndex) external view returns (bool _isSecondaryReceiver) {
    address _receiver = _secondaryReceiversAt(_receiverIndex);
    if (_secondaryReceivers.contains(_receiver)) {
      return true;
    }
  }

  function secondaryReceiverRevenueSources(address _receiver) external view returns (uint256) {
    return _secondaryReceiverRevenueSources[_receiver].length();
  }

  function secondaryTaxReceivers(
    bytes32 _collateralType,
    uint256 _receiverIndex
  ) external view returns (uint256, uint256) {
    address _receiver = _secondaryReceiversAt(_receiverIndex);
    bool _canTakeBackTax = _secondaryTaxReceivers[_collateralType][_receiver].canTakeBackTax;
    uint128 _taxPercentage = _secondaryTaxReceivers[_collateralType][_receiver].taxPercentage;
    if (_canTakeBackTax) return (canTakeBackTax, _taxPercentage);
    else return (0, _taxPercentage);
  }

  // NOTE: this method is only used for testing compatibility purposes
  function modifyParameters(bytes32 _collateralType, uint256 _receiverIndex, uint256 _val) external /* isAuthorized */ {
    if (_val != 0) {
      canTakeBackTax = _val;
      modifyParameters(_collateralType, _secondaryReceiversAt(_receiverIndex), true);
    } else {
      delete canTakeBackTax;
      modifyParameters(_collateralType, _secondaryReceiversAt(_receiverIndex), false);
    }
  }

  function modifyParameters(
    bytes32 _collateralType,
    uint256 _receiverIndex, // position (legacy compatibility)
    uint256 _taxPercentage,
    address _receiver
  ) external isAuthorized {
    if (!_secondaryReceivers.contains(_receiver)) latestSecondaryReceiver = ++secondaryReceiverNonce;
    modifyParameters(_collateralType, _taxPercentage, _receiver);
    if (!_secondaryReceivers.contains(_receiver)) {
      if (_receiverIndex == latestSecondaryReceiver) latestSecondaryReceiver = _secondaryReceivers.length();
    } else if (_secondaryReceiverRevenueSources[_receiver].contains(_collateralType)) {
      // NOTE: if trying to add a secondary receiver that exists for that collateral but in another index
      if (_secondaryReceivers._inner._indexes[bytes32(uint256(uint160(_receiver)))] != _receiverIndex) {
        revert('TaxCollector/account-already-used'); // (legacy test compatibility)
      }
    }
  }
}

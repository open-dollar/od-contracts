// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine as SAFEEngineLike} from '@interfaces/ISAFEEngine.sol';
import {IAuthorizable} from '@interfaces/IAuthorizable.sol';

interface ITaxCollector is IAuthorizable {
  // --- Events ---
  event InitializeCollateralType(bytes32 _collateralType);
  event ModifyParameters(bytes32 _collateralType, bytes32 _parameter, uint256 _data);
  event ModifyParameters(bytes32 _parameter, uint256 _data);
  event ModifyParameters(bytes32 _parameter, address _data);
  event ModifyParameters(bytes32 _collateralType, uint256 _position, uint256 _val);
  event ModifyParameters(bytes32 _collateralType, uint256 _position, uint256 _taxPercentage, address _receiverAccount);
  event AddSecondaryReceiver(
    bytes32 indexed _collateralType,
    uint256 _secondaryReceiverNonce,
    uint256 _latestSecondaryReceiver,
    uint256 _secondaryReceiverAllotedTax,
    uint256 _secondaryReceiverRevenueSources
  );
  event ModifySecondaryReceiver(
    bytes32 indexed _collateralType,
    uint256 _secondaryReceiverNonce,
    uint256 _latestSecondaryReceiver,
    uint256 _secondaryReceiverAllotedTax,
    uint256 _secondaryReceiverRevenueSources
  );
  event CollectTax(bytes32 indexed _collateralType, uint256 _latestAccumulatedRate, int256 _deltaRate);
  event DistributeTax(bytes32 indexed _collateralType, address indexed _target, int256 _taxCut);

  // --- Data ---
  struct CollateralType {
    // Per second borrow rate for this specific collateral type
    uint256 stabilityFee;
    // When SF was last collected for this collateral type
    uint256 updateTime;
  }

  // SF receiver
  struct TaxReceiver {
    // Whether this receiver can accept a negative rate (taking SF from it)
    uint256 canTakeBackTax; // [bool]
    // Percentage of SF allocated to this receiver
    uint256 taxPercentage; // [ray%]
  }

  function collateralTypes(bytes32 _collateralType) external view returns (uint256 _stabilityFee, uint256 _updateTime);
  function secondaryReceiverAllotedTax(bytes32 _collateralType)
    external
    view
    returns (uint256 _secondaryReceiverAllotedTax);
  function usedSecondaryReceiver(address _receiverAccount) external view returns (uint256 _usedSecondaryReceiver);
  function secondaryReceiverAccounts(uint256 _position) external view returns (address _receiverAccount);
  function secondaryReceiverRevenueSources(address _receiverAccount)
    external
    view
    returns (uint256 _secondaryReceiverRevenueSources);
  function secondaryTaxReceivers(
    bytes32 _collateralType,
    uint256 _position
  ) external view returns (uint256 _canTakeBackTax, uint256 _taxPercentage);
  function primaryTaxReceiver() external view returns (address _primaryTaxReceiver);
  function globalStabilityFee() external view returns (uint256 _globalStabilityFee);
  function secondaryReceiverNonce() external view returns (uint256 _secondaryReceiverNonce);
  function maxSecondaryReceivers() external view returns (uint256 _maxSecondaryReceivers);
  function latestSecondaryReceiver() external view returns (uint256 _latestSecondaryReceiver);
  function WHOLE_TAX_CUT() external view returns (uint256 _WHOLE_TAX_CUT);
  function collateralList(uint256 _position) external view returns (bytes32 _collateralType);
  function safeEngine() external view returns (SAFEEngineLike _safeEngine);

  // --- Administration ---
  function initializeCollateralType(bytes32 _collateralType) external;
  function modifyParameters(bytes32 _collateralType, bytes32 _parameter, uint256 _data) external;
  function modifyParameters(bytes32 _parameter, uint256 _data) external;
  function modifyParameters(bytes32 _parameter, address _data) external;
  function modifyParameters(bytes32 _collateralType, uint256 _position, uint256 _val) external;
  function modifyParameters(
    bytes32 _collateralType,
    uint256 _position,
    uint256 _taxPercentage,
    address _receiverAccount
  ) external;

  // --- Tax Collection Utils ---
  function collectedManyTax(uint256 _start, uint256 _end) external view returns (bool _ok);
  function taxManyOutcome(uint256 _start, uint256 _end) external view returns (bool _ok, int256 _rad);
  function taxSingleOutcome(bytes32 _collateralType)
    external
    view
    returns (uint256 _newlyAccumulatedRate, int256 _deltaRate);

  // --- Tax Receiver Utils ---
  function secondaryReceiversAmount() external view returns (uint256 _secondaryReceiversAmount);
  function collateralListLength() external view returns (uint256 _collateralListLength);
  function isSecondaryReceiver(uint256 _receiver) external view returns (bool _isSecondaryReceiver);

  // --- Tax (Stability Fee) Collection ---
  function taxMany(uint256 _start, uint256 _end) external;
  function taxSingle(bytes32 _collateralType) external returns (uint256 _latestAccumulatedRate);
}

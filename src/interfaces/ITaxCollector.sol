// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine as SAFEEngineLike} from '@interfaces/ISAFEEngine.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface ITaxCollector is IAuthorizable {
  // --- Events ---
  event InitializeCollateralType(bytes32 _cType);
  event ModifyParameters(bytes32 _cType, bytes32 _param, uint256 _data);
  event ModifyParameters(bytes32 _param, uint256 _data);
  event ModifyParameters(bytes32 _param, address _data);
  event ModifyParameters(bytes32 _cType, address _receiver, bool _val);
  event ModifyParameters(bytes32 _cType, uint256 _taxPercentage, address _receiver);
  // NOTE: bytes32(collateralType) is left for future compatibility
  event SetPrimaryReceiver(bytes32 indexed _cType, address indexed _receiver);
  // NOTE: (taxPercentage, canTakeBackTax) = (0, false) means that the receiver is removed
  event SetSecondaryReceiver(
    bytes32 indexed _cType, address indexed _receiver, uint128 _taxPercentage, bool _canTakeBackTax
  );
  event CollectTax(bytes32 indexed _cType, uint256 _latestAccumulatedRate, int256 _deltaRate);
  event DistributeTax(bytes32 indexed _cType, address indexed _target, int256 _taxCut);

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
    bool canTakeBackTax; // [bool]
    // Percentage of SF allocated to this receiver
    uint128 taxPercentage; // [ray%]
  }

  function collateralTypes(bytes32 _cType) external view returns (uint256 _stabilityFee, uint256 _updateTime);
  function secondaryReceiverAllotedTax(bytes32 _cType) external view returns (uint256 _secondaryReceiverAllotedTax);
  function _secondaryTaxReceivers(
    bytes32 _cType,
    address _receiver
  ) external view returns (bool _canTakeBackTax, uint128 _taxPercentage);
  function primaryTaxReceiver() external view returns (address _primaryTaxReceiver);
  function globalStabilityFee() external view returns (uint256 _globalStabilityFee);
  function maxSecondaryReceivers() external view returns (uint256 _maxSecondaryReceivers);
  function WHOLE_TAX_CUT() external view returns (uint256 _WHOLE_TAX_CUT);
  function safeEngine() external view returns (SAFEEngineLike _safeEngine);

  // --- Administration ---
  function initializeCollateralType(bytes32 _cType) external;
  function modifyParameters(bytes32 _cType, bytes32 _param, uint256 _data) external;
  function modifyParameters(bytes32 _param, uint256 _data) external;
  function modifyParameters(bytes32 _param, address _data) external;
  function modifyParameters(bytes32 _cType, address _receiver, bool _val) external;
  function modifyParameters(bytes32 _cType, uint256 _taxPercentage, address _receiver) external;

  // --- Tax Collection Utils ---
  function collectedManyTax(uint256 _start, uint256 _end) external view returns (bool _ok);
  function taxManyOutcome(uint256 _start, uint256 _end) external view returns (bool _ok, int256 _rad);
  function taxSingleOutcome(bytes32 _cType) external view returns (uint256 _newlyAccumulatedRate, int256 _deltaRate);

  // --- Tax Receiver Utils ---
  function secondaryReceiversListLength() external view returns (uint256 _secondaryReceiversListLength);
  function collateralListLength() external view returns (uint256 _collateralListLength);
  function isSecondaryReceiver(address _receiver) external view returns (bool _isSecondaryReceiver);

  // --- Views ---
  function collateralListList() external view returns (bytes32[] memory _collateralListList);
  function secondaryReceiversList() external view returns (address[] memory _secondaryReceiversList);
  function secondaryReceiverRevenueSourcesList(address _secondaryReceiver)
    external
    view
    returns (bytes32[] memory _secondaryReceiverRevenueSourcesList);

  // --- Tax (Stability Fee) Collection ---
  function taxMany(uint256 _start, uint256 _end) external;
  function taxSingle(bytes32 _cType) external returns (uint256 _latestAccumulatedRate);
}

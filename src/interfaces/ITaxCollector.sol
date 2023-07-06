// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface ITaxCollector is IAuthorizable, IModifiable {
  // --- Events ---
  event InitializeCollateralType(bytes32 _cType);
  event SetPrimaryReceiver(bytes32 indexed _cType, address indexed _receiver);
  // NOTE: (taxPercentage, canTakeBackTax) = (0, false) means that the receiver is removed
  event SetSecondaryReceiver(
    bytes32 indexed _cType, address indexed _receiver, uint256 _taxPercentage, bool _canTakeBackTax
  );
  event CollectTax(bytes32 indexed _cType, uint256 _latestAccumulatedRate, int256 _deltaRate);
  event DistributeTax(bytes32 indexed _cType, address indexed _target, int256 _taxCut);

  // --- Errors ---
  error TaxCollector_CollateralTypeAlreadyInitialized();
  error TaxCollector_InvalidIndexes();
  error TaxCollector_NullAccount();
  error TaxCollector_PrimaryReceiverCannotBeSecondary();
  error TaxCollector_CollateralTypeNotInitialized();
  error TaxCollector_ExceedsMaxReceiverLimit();
  error TaxCollector_NullSF();
  error TaxCollector_TaxCutExceedsHundred();
  error TaxCollector_TaxCutTooBig();

  // --- Data ---
  struct TaxCollectorParams {
    address primaryTaxReceiver;
    uint256 globalStabilityFee;
    uint256 maxSecondaryReceivers;
  }

  struct TaxCollectorCollateralParams {
    uint256 stabilityFee;
  }

  struct TaxCollectorCollateralData {
    // Per second borrow rate for this specific collateral type to be applied at the next taxation
    uint256 nextStabilityFee;
    // When Stability Fee was last collected for this collateral type
    uint256 updateTime;
    // Percentage of each collateral's SF that goes to other addresses apart from the primary receiver
    uint256 secondaryReceiverAllotedTax; // [%ray]
  }

  // SF receiver
  struct TaxReceiver {
    address receiver;
    // Whether this receiver can accept a negative rate (taking SF from it)
    bool canTakeBackTax; // [bool]
    // Percentage of SF allocated to this receiver
    uint256 taxPercentage; // [ray%]
  }

  // solhint-disable-next-line func-name-mixedcase
  function WHOLE_TAX_CUT() external view returns (uint256 _wholeTaxCut);

  function params() external view returns (TaxCollectorParams memory _taxCollectorParams);
  // solhint-disable-next-line private-vars-leading-underscore
  function _params()
    external
    view
    returns (address _primaryTaxReceiver, uint256 _globalStabilityFee, uint256 _maxSecondaryReceivers);

  function cParams(bytes32 _cType) external view returns (TaxCollectorCollateralParams memory _taxCollectorCParams);
  // solhint-disable-next-line private-vars-leading-underscore
  function _cParams(bytes32 _cType) external view returns (uint256 _stabilityFee);

  function cData(bytes32 _cType) external view returns (TaxCollectorCollateralData memory _taxCollectorCData);
  // solhint-disable-next-line private-vars-leading-underscore
  function _cData(bytes32 _cType)
    external
    view
    returns (uint256 _nextStabilityFee, uint256 _updateTime, uint256 _secondaryReceiverAllotedTax);

  function secondaryTaxReceivers(
    bytes32 _cType,
    address _receiver
  ) external view returns (TaxReceiver memory _secondaryTaxReceiver);
  // solhint-disable-next-line private-vars-leading-underscore
  function _secondaryTaxReceivers(
    bytes32 _cType,
    address _receiver
  ) external view returns (address _secondaryReceiver, bool _canTakeBackTax, uint256 _taxPercentage);

  function safeEngine() external view returns (ISAFEEngine _safeEngine);

  // --- Administration ---
  function initializeCollateralType(bytes32 _cType, TaxCollectorCollateralParams memory _collateralParams) external;

  // --- Tax Collection Utils ---
  function collectedManyTax(uint256 _start, uint256 _end) external view returns (bool _ok);
  function taxManyOutcome(uint256 _start, uint256 _end) external view returns (bool _ok, int256 _rad);
  function taxSingleOutcome(bytes32 _cType) external view returns (uint256 _newlyAccumulatedRate, int256 _deltaRate);

  // --- Tax Receiver Utils ---
  function secondaryReceiversListLength() external view returns (uint256 _secondaryReceiversListLength);
  function collateralListLength() external view returns (uint256 _collateralListLength);
  function isSecondaryReceiver(address _receiver) external view returns (bool _isSecondaryReceiver);

  // --- Views ---
  function collateralList() external view returns (bytes32[] memory _collateralList);
  function secondaryReceiversList() external view returns (address[] memory _secondaryReceiversList);
  function secondaryReceiverRevenueSourcesList(address _secondaryReceiver)
    external
    view
    returns (bytes32[] memory _secondaryReceiverRevenueSourcesList);

  // --- Tax (Stability Fee) Collection ---
  function taxMany(uint256 _start, uint256 _end) external;
  function taxSingle(bytes32 _cType) external returns (uint256 _latestAccumulatedRate);
}

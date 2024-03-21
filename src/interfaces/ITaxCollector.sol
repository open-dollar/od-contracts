// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiablePerCollateral} from '@interfaces/utils/IModifiablePerCollateral.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

interface ITaxCollector is IAuthorizable, IModifiable, IModifiablePerCollateral {
  // --- Events ---

  /**
   * @notice Emitted when a new primary tax receiver is set
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _receiver Address of the new primary tax receiver
   */
  event SetPrimaryReceiver(bytes32 indexed _cType, address indexed _receiver);

  /**
   * @notice Emitted when a new secondary tax receiver is set
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _receiver Address of the new secondary tax receiver
   * @param  _taxPercentage Percentage of SF allocated to this receiver
   * @param  _canTakeBackTax Whether this receiver can accept a negative rate (taking SF from it)
   * @dev    (taxPercentage, canTakeBackTax) = (0, false) means that the receiver is removed
   */
  event SetSecondaryReceiver(
    bytes32 indexed _cType, address indexed _receiver, uint256 _taxPercentage, bool _canTakeBackTax
  );

  /**
   * @notice Emitted once when a collateral type taxation is processed
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _latestAccumulatedRate The newly accumulated rate
   * @param  _deltaRate The delta between the new and the last accumulated rates
   */
  event CollectTax(bytes32 indexed _cType, uint256 _latestAccumulatedRate, int256 _deltaRate);

  /**
   * @notice Emitted when a collateral type taxation is distributed (one event per receiver)
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _target Address of the tax receiver
   * @param  _taxCut Amount of SF collected for this receiver
   * @dev    SF can be negative if the receiver can take back tax
   */
  event DistributeTax(bytes32 indexed _cType, address indexed _target, int256 _taxCut);

  // --- Errors ---

  /// @notice Throws when inputting an invalid index for the collateral type list
  error TaxCollector_InvalidIndexes();
  /// @notice Throws when trying to add a null address as a tax receiver
  error TaxCollector_NullAccount();
  /// @notice Throws when trying to add a tax receiver that is already the primary receiver
  error TaxCollector_PrimaryReceiverCannotBeSecondary();
  /// @notice Throws when trying to modify parameters for a collateral type that is not initialized
  error TaxCollector_CollateralTypeNotInitialized();
  /// @notice Throws when trying to add a tax receiver that would surpass the max number of receivers
  error TaxCollector_ExceedsMaxReceiverLimit();
  /// @notice Throws when trying to collect tax for a receiver with null tax percentage
  error TaxCollector_NullSF();
  /// @notice Throws when trying to add a receiver such that the total tax percentage would surpass 100%
  error TaxCollector_TaxCutExceedsHundred();
  /// @notice Throws when trying to modify a receiver such that the total tax percentage would surpass 100%
  error TaxCollector_TaxCutTooBig();

  // --- Structs ---

  struct TaxCollectorParams {
    // Address of the primary tax receiver
    address /*     */ primaryTaxReceiver;
    // Global stability fee
    uint256 /* RAY */ globalStabilityFee;
    // Max stability fee range of variation
    uint256 /* RAY */ maxStabilityFeeRange;
    // Max number of secondary tax receivers
    uint256 /*     */ maxSecondaryReceivers;
  }

  struct TaxCollectorCollateralParams {
    // Per collateral stability fee
    uint256 /* RAY */ stabilityFee;
  }

  struct TaxCollectorCollateralData {
    // Per second borrow rate for this specific collateral type to be applied at the next taxation
    uint256 /* RAY   */ nextStabilityFee;
    // When Stability Fee was last collected for this collateral type
    uint256 /* unix  */ updateTime;
    // Percentage of each collateral's SF that goes to other addresses apart from the primary receiver
    uint256 /* WAD % */ secondaryReceiverAllotedTax;
  }

  struct TaxReceiver {
    address receiver;
    // Whether this receiver can accept a negative rate (taking SF from it)
    bool /* bool    */ canTakeBackTax;
    // Percentage of SF allocated to this receiver
    uint256 /* WAD % */ taxPercentage;
  }

  // --- Data ---

  /**
   * @notice Getter for the contract parameters struct
   * @return _taxCollectorParams Tax collector parameters struct
   */
  function params() external view returns (TaxCollectorParams memory _taxCollectorParams);

  /**
   * @notice Getter for the unpacked contract parameters struct
   * @return _primaryTaxReceiver Primary tax receiver address
   * @return _globalStabilityFee Global stability fee [ray]
   * @return _maxStabilityFeeRange Max stability fee range [ray]
   * @return _maxSecondaryReceivers Max number of secondary tax receivers
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _params()
    external
    view
    returns (
      address _primaryTaxReceiver,
      uint256 _globalStabilityFee,
      uint256 _maxStabilityFeeRange,
      uint256 _maxSecondaryReceivers
    );

  /**
   * @notice Getter for the collateral parameters struct
   * @param  _cType Bytes32 representation of the collateral type
   * @return _taxCollectorCParams Tax collector collateral parameters struct
   */
  function cParams(bytes32 _cType) external view returns (TaxCollectorCollateralParams memory _taxCollectorCParams);

  /**
   * @notice Getter for the unpacked collateral parameters struct
   * @param  _cType Bytes32 representation of the collateral type
   * @return _stabilityFee Stability fee [ray]
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _cParams(bytes32 _cType) external view returns (uint256 _stabilityFee);

  /**
   * @notice Getter for the collateral data struct
   * @param  _cType Bytes32 representation of the collateral type
   * @return _taxCollectorCData Tax collector collateral data struct
   */
  function cData(bytes32 _cType) external view returns (TaxCollectorCollateralData memory _taxCollectorCData);

  /**
   * @notice Getter for the unpacked collateral data struct
   * @param  _cType Bytes32 representation of the collateral type
   * @return _nextStabilityFee Per second borrow rate to be applied at the next taxation [ray]
   * @return _updateTime When Stability Fee was last collected
   * @return _secondaryReceiverAllotedTax Percentage of SF that goes to other addresses apart from the primary receiver
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _cData(bytes32 _cType)
    external
    view
    returns (uint256 _nextStabilityFee, uint256 _updateTime, uint256 _secondaryReceiverAllotedTax);

  /**
   * @notice Getter for the data about a specific secondary tax receiver
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _receiver Tax receiver address to check
   * @return _secondaryTaxReceiver Tax receiver struct
   */
  function secondaryTaxReceivers(
    bytes32 _cType,
    address _receiver
  ) external view returns (TaxReceiver memory _secondaryTaxReceiver);

  /**
   * @notice Getter for the unpacked data about a specific secondary tax receiver
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _receiver Tax receiver address to check
   * @return _secondaryReceiver Secondary tax receiver address
   * @return _canTakeBackTax Whether this receiver can accept a negative rate (taking SF from it)
   * @return _taxPercentage Percentage of SF allocated to this receiver
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _secondaryTaxReceivers(
    bytes32 _cType,
    address _receiver
  ) external view returns (address _secondaryReceiver, bool _canTakeBackTax, uint256 _taxPercentage);

  /// @notice Address of the SAFEEngine contract
  function safeEngine() external view returns (ISAFEEngine _safeEngine);

  // --- Administration ---

  // --- Tax Collection Utils ---

  /**
   * @notice Check if multiple collateral types are up to date with taxation
   * @param  _start Index of the first collateral type to check
   * @param  _end Index of the last collateral type to check
   * @return _ok Whether all collateral types are up to date
   */
  function collectedManyTax(uint256 _start, uint256 _end) external view returns (bool _ok);

  /**
   * @notice Check how much SF will be charged (to collateral types between indexes 'start' and 'end'
   *         in the collateralList) during the next taxation
   * @param  _start Index in collateralList from which to start looping and calculating the tax outcome
   * @param  _end Index in collateralList at which we stop looping and calculating the tax outcome
   * @return _ok Whether the tax outcome can be computed
   * @return _rad The total amount of SF that will be charged during the next taxation
   */
  function taxManyOutcome(uint256 _start, uint256 _end) external view returns (bool _ok, int256 _rad);

  /**
   * @notice Get how much SF will be distributed after taxing a specific collateral type
   * @param _cType Collateral type to compute the taxation outcome for
   * @return _newlyAccumulatedRate The newly accumulated rate
   * @return _deltaRate The delta between the new and the last accumulated rates
   */
  function taxSingleOutcome(bytes32 _cType) external view returns (uint256 _newlyAccumulatedRate, int256 _deltaRate);

  // --- Tax Receiver Utils ---

  /**
   * @notice Get the secondary tax receiver list length
   */
  function secondaryReceiversListLength() external view returns (uint256 _secondaryReceiversListLength);

  /**
   * @notice Get the collateralList length
   */
  function collateralListLength() external view returns (uint256 _collateralListLength);

  /**
   * @notice Check if a tax receiver is at a certain position in the list
   * @param  _receiver Tax receiver address to check
   * @return _isSecondaryReceiver Whether the tax receiver for at least one collateral type
   */
  function isSecondaryReceiver(address _receiver) external view returns (bool _isSecondaryReceiver);

  // --- Views ---

  /// @notice Get the list of all secondary tax receivers
  function secondaryReceiversList() external view returns (address[] memory _secondaryReceiversList);

  /**
   * @notice Get the list of all collateral types for which a specific address is a secondary tax receiver
   * @param  _secondaryReceiver Secondary tax receiver address to check
   * @return _secondaryReceiverRevenueSourcesList List of collateral types for which the address is a secondary tax receiver
   */
  function secondaryReceiverRevenueSourcesList(address _secondaryReceiver)
    external
    view
    returns (bytes32[] memory _secondaryReceiverRevenueSourcesList);

  // --- Tax (Stability Fee) Collection ---

  /**
   * @notice Collect tax from multiple collateral types at once
   * @param _start Index in collateralList from which to start looping and calculating the tax outcome
   * @param _end Index in collateralList at which we stop looping and calculating the tax outcome
   */
  function taxMany(uint256 _start, uint256 _end) external;

  /**
   * @notice Collect tax from a single collateral type
   * @param _cType Collateral type to tax
   * @return _latestAccumulatedRate The newly accumulated rate after taxation
   */
  function taxSingle(bytes32 _cType) external returns (uint256 _latestAccumulatedRate);
}

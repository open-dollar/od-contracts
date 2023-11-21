// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {IModifiablePerCollateral} from '@interfaces/utils/IModifiablePerCollateral.sol';
import {IDisableable} from '@interfaces/utils/IDisableable.sol';

interface ISAFEEngine is IAuthorizable, IDisableable, IModifiable, IModifiablePerCollateral {
  // --- Events ---

  /**
   * @notice Emitted when an address authorizes another address to modify its SAFE
   * @param _sender Address that sent the authorization
   * @param _account Address that is authorized to modify the SAFE
   */
  event ApproveSAFEModification(address _sender, address _account);

  /**
   * @notice Emitted when an address denies another address to modify its SAFE
   * @param _sender Address that sent the denial
   * @param _account Address that is denied to modify the SAFE
   */
  event DenySAFEModification(address _sender, address _account);

  /**
   * @notice Emitted when collateral is transferred between accounts
   * @param _cType Bytes32 representation of the collateral type
   * @param _src Address that sent the collateral
   * @param _dst Address that received the collateral
   * @param _wad Amount of collateral transferred
   */
  event TransferCollateral(bytes32 indexed _cType, address indexed _src, address indexed _dst, uint256 _wad);

  /**
   * @notice Emitted when internal coins are transferred between accounts
   * @param _src Address that sent the coins
   * @param _dst Address that received the coins
   * @param _rad Amount of coins transferred
   */
  event TransferInternalCoins(address indexed _src, address indexed _dst, uint256 _rad);

  /**
   * @notice Emitted when the SAFE state is modified by the owner or authorized accounts
   * @param _cType Bytes32 representation of the collateral type
   * @param _safe Address of the SAFE
   * @param _collateralSource Address that sent/receives the collateral
   * @param _debtDestination Address that sent/receives the debt
   * @param _deltaCollateral Amount of collateral added/extracted from the SAFE [wad]
   * @param _deltaDebt Amount of debt to generate/repay [wad]
   */
  event ModifySAFECollateralization(
    bytes32 indexed _cType,
    address indexed _safe,
    address _collateralSource,
    address _debtDestination,
    int256 _deltaCollateral,
    int256 _deltaDebt
  );

  /**
   * @notice Emitted when collateral and/or debt is transferred between SAFEs
   * @param _cType Bytes32 representation of the collateral type
   * @param _src Address that sent the collateral
   * @param _dst Address that received the collateral
   * @param _deltaCollateral Amount of collateral to take/add into src and give/take from dst [wad]
   * @param _deltaDebt Amount of debt to take/add into src and give/take from dst [wad]
   */
  event TransferSAFECollateralAndDebt(
    bytes32 indexed _cType, address indexed _src, address indexed _dst, int256 _deltaCollateral, int256 _deltaDebt
  );

  /**
   * @notice Emitted when collateral and debt is confiscated from a SAFE
   * @param _cType Bytes32 representation of the collateral type
   * @param _safe Address of the SAFE
   * @param _collateralSource Address that sent/receives the collateral
   * @param _debtDestination Address that sent/receives the debt
   * @param _deltaCollateral Amount of collateral added/extracted from the SAFE [wad]
   * @param _deltaDebt Amount of debt to generate/repay [wad]
   */
  event ConfiscateSAFECollateralAndDebt(
    bytes32 indexed _cType,
    address indexed _safe,
    address _collateralSource,
    address _debtDestination,
    int256 _deltaCollateral,
    int256 _deltaDebt
  );

  /**
   * @notice Emitted when an account's debt is settled with coins
   * @dev    Accounts (not SAFEs) can only settle unbacked debt
   * @param _account Address of the account
   * @param _rad Amount of debt & coins to destroy
   */
  event SettleDebt(address indexed _account, uint256 _rad);

  /**
   * @notice Emitted when an unbacked debt is created to an account
   * @param _debtDestination Address that received the newly created debt
   * @param _coinDestination Address that received the newly created coins
   * @param _rad Amount of debt to create
   */
  event CreateUnbackedDebt(address indexed _debtDestination, address indexed _coinDestination, uint256 _rad);

  /**
   * @notice Emit when the accumulated rate of a collateral type is updated
   * @param _cType Bytes32 representation of the collateral type
   * @param _surplusDst Address that received the newly created surplus
   * @param _rateMultiplier Delta of the accumulated rate [ray]
   */
  event UpdateAccumulatedRate(bytes32 indexed _cType, address _surplusDst, int256 _rateMultiplier);

  /**
   * @notice Emitted when the safety price and liquidation price of a collateral type is updated
   * @param _cType Bytes32 representation of the collateral type
   * @param _safetyPrice New price at which a SAFE is allowed to generate debt [ray]
   * @param _liquidationPrice New price at which a SAFE gets liquidated [ray]
   */
  event UpdateCollateralPrice(bytes32 indexed _cType, uint256 _safetyPrice, uint256 _liquidationPrice);

  // --- Errors ---

  /// @notice Throws when trying to modify parameters of an uninitialized collateral type
  error SAFEEng_CollateralTypeNotInitialized();
  /// @notice Throws when trying to modify a SAFE into an unsafe state
  error SAFEEng_SAFENotSafe();
  /// @notice Throws when trying to modify a SAFE into a dusty safe (debt non-zero and below `debtFloor`)
  error SAFEEng_DustySAFE();
  /// @notice Throws when trying to generate debt that would put the system over the global debt ceiling
  error SAFEEng_GlobalDebtCeilingHit();
  /// @notice Throws when trying to generate debt that would put the system over the collateral debt ceiling
  error SAFEEng_CollateralDebtCeilingHit();
  /// @notice Throws when trying to generate debt that would put the SAFE over the SAFE debt ceiling
  error SAFEEng_SAFEDebtCeilingHit();
  /// @notice Throws when an account tries to modify a SAFE without the proper permissions
  error SAFEEng_NotSAFEAllowed();
  /// @notice Throws when an account tries to pull collateral from a SAFE without the proper permissions
  error SAFEEng_NotCollateralSrcAllowed();
  /// @notice Throws when an account tries to push debt to a SAFE without the proper permissions
  error SAFEEng_NotDebtDstAllowed();

  // --- Structs ---

  struct SAFE {
    // Total amount of collateral locked in a SAFE
    uint256 /* WAD */ lockedCollateral;
    // Total amount of debt generated by a SAFE
    uint256 /* WAD */ generatedDebt;
  }

  struct SAFEEngineParams {
    // Total amount of debt that a single safe can generate
    uint256 /* WAD */ safeDebtCeiling;
    // Maximum amount of debt that can be issued across all safes
    uint256 /* RAD */ globalDebtCeiling;
  }

  struct SAFEEngineCollateralData {
    // Total amount of debt issued by the collateral type
    uint256 /* WAD */ debtAmount;
    // Total amount of collateral locked in SAFEs using the collateral type
    uint256 /* WAD */ lockedAmount;
    // Accumulated rate of the collateral type
    uint256 /* RAY */ accumulatedRate;
    // Floor price at which a SAFE is allowed to generate debt
    uint256 /* RAY */ safetyPrice;
    // Price at which a SAFE gets liquidated
    uint256 /* RAY */ liquidationPrice;
  }

  struct SAFEEngineCollateralParams {
    // Maximum amount of debt that can be generated with the collateral type
    uint256 /* RAD */ debtCeiling;
    // Minimum amount of debt that must be generated by a SAFE using the collateral
    uint256 /* RAD */ debtFloor;
  }

  // --- Data ---

  /**
   * @notice Getter for the contract parameters struct
   * @return _safeEngineParams The active SAFEEngineParams
   */
  function params() external view returns (SAFEEngineParams memory _safeEngineParams);

  /**
   * @notice Getter for the unpacked contract parameters struct
   * @return _safeDebtCeiling Total amount of debt that a single safe can generate [wad]
   * @return _globalDebtCeiling Maximum amount of debt that can be issued [rad]
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _params() external view returns (uint256 _safeDebtCeiling, uint256 _globalDebtCeiling);

  /**
   * @notice Getter for the collateral parameters struct
   * @param  _cType Bytes32 representation of the collateral type
   * @return  _safeEngineCParams SAFEEngineCollateralParams for the collateral type
   */
  function cParams(bytes32 _cType) external view returns (SAFEEngineCollateralParams memory _safeEngineCParams);

  /**
   * @notice Getter for the unpacked collateral parameters struct
   * @param  _cType Bytes32 representation of the collateral type
   * @return _debtCeiling Maximum amount of debt that can be generated with this collateral type
   * @return _debtFloor Minimum amount of debt that must be generated by a SAFE using this collateral
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _cParams(bytes32 _cType) external view returns (uint256 _debtCeiling, uint256 _debtFloor);

  /**
   * @notice Getter for the collateral data struct
   * @param  _cType Bytes32 representation of the collateral type
   * @return  _safeEngineCData SAFEEngineCollateralData for the collateral type
   */
  function cData(bytes32 _cType) external view returns (SAFEEngineCollateralData memory _safeEngineCData);

  /**
   * @notice Getter for the unpacked collateral data struct
   * @param  _cType Bytes32 representation of the collateral type
   * @return _debtAmount Total amount of debt issued by a collateral type [wad]
   * @return _lockedAmount Total amount of collateral locked in all SAFEs of the collateral type [wad]
   * @return _accumulatedRate Accumulated rate of a collateral type [ray]
   * @return _safetyPrice Floor price at which a SAFE is allowed to generate debt [ray]
   * @return _liquidationPrice Price at which a SAFE gets liquidated [ray]
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _cData(bytes32 _cType)
    external
    view
    returns (
      uint256 _debtAmount,
      uint256 _lockedAmount,
      uint256 _accumulatedRate,
      uint256 _safetyPrice,
      uint256 _liquidationPrice
    );

  /**
   * @notice Data about each SAFE
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _safeAddress Address of the SAFE
   * @return _safeData SAFE data for the specified collateral type of the specified safe.
   */
  function safes(bytes32 _cType, address _safeAddress) external view returns (SAFE memory _safeData);

  /**
   * @notice Unpacked data about each SAFE
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _safeAddress Address of the SAFE
   * @return _lockedCollateral Total amount of collateral locked in a SAFE [wad]
   * @return _generatedDebt Total amount of debt generated by a SAFE [wad]
   */
  // solhint-disable-next-line private-vars-leading-underscore
  function _safes(
    bytes32 _cType,
    address _safeAddress
  ) external view returns (uint256 _lockedCollateral, uint256 _generatedDebt);

  /**
   * @notice Who can transfer collateral & debt in/out of a SAFE
   * @param  _caller Address to check for SAFE permissions for
   * @param  _account Account to check if caller has permissions for
   * @return _safeRights Boolean representation of the SAFE rights (0/1)
   */
  function safeRights(address _caller, address _account) external view returns (bool _safeRights);

  // --- Balances ---

  /**
   * @notice Balance of each collateral type
   * @param  _cType Bytes32 representation of the collateral type to check balance for
   * @param  _account Account to check balance for
   * @return _collateralBalance Collateral balance of the account [wad]
   */
  function tokenCollateral(bytes32 _cType, address _account) external view returns (uint256 _collateralBalance);

  /**
   * @notice Internal balance of system coins held by an account
   * @param  _account Account to check balance for
   * @return _balance Internal coin balance of the account [rad]
   */
  function coinBalance(address _account) external view returns (uint256 _balance);

  /**
   * @notice Amount of debt held by an account
   * @param  _account Account to check balance for
   * @return _debtBalance Debt balance of the account [rad]
   */
  function debtBalance(address _account) external view returns (uint256 _debtBalance);

  /**
   * @notice Total amount of debt (coins) currently issued
   * @return _globalDebt Global debt [rad]
   */
  function globalDebt() external returns (uint256 _globalDebt);

  /**
   * @notice 'Bad' debt that's not covered by collateral
   * @return _globalUnbackedDebt Global unbacked debt [rad]
   */
  function globalUnbackedDebt() external view returns (uint256 _globalUnbackedDebt);

  // --- Init ---

  // --- Fungibility ---

  /**
   * @notice Transfer collateral between accounts
   * @param _cType Collateral type transferred
   * @param _source Collateral source
   * @param _destination Collateral destination
   * @param _wad Amount of collateral transferred
   */
  function transferCollateral(bytes32 _cType, address _source, address _destination, uint256 _wad) external;

  /**
   * @notice Transfer internal coins (does not affect external balances from Coin.sol)
   * @param  _source Coins source
   * @param  _destination Coins destination
   * @param  _rad Amount of coins transferred
   */
  function transferInternalCoins(address _source, address _destination, uint256 _rad) external;

  /**
   * @notice Join/exit collateral into and and out of the system
   * @param _cType Collateral type to join/exit
   * @param _account Account that gets credited/debited
   * @param _wad Amount of collateral
   */
  function modifyCollateralBalance(bytes32 _cType, address _account, int256 _wad) external;

  // --- SAFE Manipulation ---

  /**
   * @notice Add/remove collateral or put back/generate more debt in a SAFE
   * @param _cType Type of collateral to withdraw/deposit in and from the SAFE
   * @param _safe Target SAFE
   * @param _collateralSource Account we take collateral from/put collateral into
   * @param _debtDestination Account from which we credit/debit coins and debt
   * @param _deltaCollateral Amount of collateral added/extracted from the SAFE [wad]
   * @param _deltaDebt Amount of debt to generate/repay [wad]
   */
  function modifySAFECollateralization(
    bytes32 _cType,
    address _safe,
    address _collateralSource,
    address _debtDestination,
    int256 /* WAD */ _deltaCollateral,
    int256 /* WAD */ _deltaDebt
  ) external;

  // --- SAFE Fungibility ---

  /**
   * @notice Transfer collateral and/or debt between SAFEs
   * @param _cType Collateral type transferred between SAFEs
   * @param _src Source SAFE
   * @param _dst Destination SAFE
   * @param _deltaCollateral Amount of collateral to take/add into src and give/take from dst [wad]
   * @param _deltaDebt Amount of debt to take/add into src and give/take from dst [wad]
   */
  function transferSAFECollateralAndDebt(
    bytes32 _cType,
    address _src,
    address _dst,
    int256 /* WAD */ _deltaCollateral,
    int256 /* WAD */ _deltaDebt
  ) external;

  // --- SAFE Confiscation ---

  /**
   * @notice Normally used by the LiquidationEngine in order to confiscate collateral and
   *      debt from a SAFE and give them to someone else
   * @param _cType Collateral type the SAFE has locked inside
   * @param _safe Target SAFE
   * @param _collateralSource Who we take/give collateral to
   * @param _debtDestination Who we take/give debt to
   * @param _deltaCollateral Amount of collateral taken/added into the SAFE [wad]
   * @param _deltaDebt Amount of debt taken/added into the SAFE [wad]
   */
  function confiscateSAFECollateralAndDebt(
    bytes32 _cType,
    address _safe,
    address _collateralSource,
    address _debtDestination,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) external;

  // --- Settlement ---

  /**
   * @notice Nullify an amount of coins with an equal amount of debt
   * @dev    Coins & debt are like matter and antimatter, they nullify each other
   * @param  _rad Amount of debt & coins to destroy
   */
  function settleDebt(uint256 _rad) external;

  /**
   * @notice Allows an authorized contract to create debt without collateral
   * @param _debtDestination The account that will receive the newly created debt
   * @param _coinDestination The account that will receive the newly created coins
   * @param _rad Amount of debt to create
   * @dev   Usually called by DebtAuctionHouse in order to terminate auctions prematurely post settlement
   */
  function createUnbackedDebt(address _debtDestination, address _coinDestination, uint256 _rad) external;

  // --- Update ---

  /**
   * @notice Allows an authorized contract to accrue interest on a specific collateral type
   * @param _cType Collateral type we accrue interest for
   * @param _surplusDst Destination for the newly created surplus
   * @param _rateMultiplier Multiplier applied to the debtAmount in order to calculate the surplus [ray]
   * @dev   The rateMultiplier is usually calculated by the TaxCollector contract
   */
  function updateAccumulatedRate(bytes32 _cType, address _surplusDst, int256 _rateMultiplier) external;

  /**
   * @notice Allows an authorized contract to update the safety price and liquidation price of a collateral type
   * @param _cType Collateral type we update the prices for
   * @param _safetyPrice New safety price [ray]
   * @param _liquidationPrice New liquidation price [ray]
   */
  function updateCollateralPrice(bytes32 _cType, uint256 _safetyPrice, uint256 _liquidationPrice) external;

  // --- Authorization ---

  /**
   * @notice Allow an address to modify your SAFE
   * @param _account Account to give SAFE permissions to
   */
  function approveSAFEModification(address _account) external;

  /**
   * @notice Deny an address the rights to modify your SAFE
   * @param _account Account that is denied SAFE permissions
   */
  function denySAFEModification(address _account) external;

  /**
   * @notice Checks whether an account has the right to modify a SAFE
   * @param _safe The safe to check
   * @param _account The account to check
   * @return _allowed Whether the account can modify the safe
   */
  function canModifySAFE(address _safe, address _account) external view returns (bool _allowed);
}

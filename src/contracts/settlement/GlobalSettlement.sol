// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {
  IGlobalSettlement,
  ISAFEEngine,
  ILiquidationEngine,
  IOracleRelayer
} from '@interfaces/settlement/IGlobalSettlement.sol';

import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';
import {Disableable, IDisableable} from '@contracts/utils/Disableable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Math, RAY} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

/**
 * @title  Global Settlement
 * @notice This contract is responsible for processing the system settlement, a stateful process that takes place over nine steps.
 * @notice #### System shutdown:
 *         > We must freeze the system and start the cooldown period before we can process any system state.
 *         > In particular, oracle prices are frozen, and no more debt can be generated from the SAFEEngine.
 *
 *         1) `shutdownSystem()`
 *             - freeze the system and start the cooldown period
 *
 *         2) `freezeCollateralType(_cType)`
 *             - reads and store the final price for each collateral type
 *             - initializes `collateralTotalDebt` to the total debt registered in safe engine
 *
 *         #### Cooldown period:
 *         > We must process some system state before it is possible to calculate the final coin / collateral price.
 *         > In particular, we need to determine:
 *         >
 *         > + (a) `collateralShortfall` (considers under-collateralized SAFEs)
 *         > + (b) `outstandingCoinSupply` (after including system surplus / deficit)
 *         >
 *         > - We determine (a) by processing all under-collateralized SAFEs.
 *         > - We determine (b) by processing ongoing coin generating processes, i.e. auctions. We need to ensure that auctions will not generate any further coin income.
 *
 *
 *         3) `processSAFE(_cType, _safe)`
 *           - confiscates SAFE debt and backing collateral (excess of collateral remains).
 *
 *         4) Auctions at SAH and DAH can be terminated prematurely, while CAH auctions are handled by this contract
 *           + 4.a. `SAH.terminateAuctionPrematurely(_id)`
 *             - settles the auction
 *             - transfers the surplus to the highest bidder
 *           + 4.b. `DAH.terminateAuctionPrematurely(_id)`
 *             - settles the auction
 *             - returns the coins to the highest bidder
 *             - registers the unbacked debt at the accounting engine
 *           + 4.c. `this.fastTrackAuction(_cType, _id)`
 *             - settles the auction: returns collateral and debt to the SAFE
 *             - registers returned debt in `collateralTotalDebt`
 *
 *         > When an overcollateralized SAFE has been processed and has no debt remaining, the remaining collateral can be withdrawn:
 *
 *         5) `freeCollateral(_cType)`
 *             - remove collateral from the caller's SAFE (requires SAFE to have no debt)
 *
 *         #### After cooldown period:
 *         > We enable calculation of the final price for each collateral type.
 *         > Requires accounting engine to have no surplus.
 *
 *         7) `setOutstandingCoinSupply()`
 *             - fixes the total outstanding supply of coin
 *         6) `calculateCashPrice(_cType)`
 *             - calculate `collateralCashPrice` adjusted in the case of deficit / surplus
 *
 *         #### Redeeming:
 *         > At this point we have computed the final price for each collateral type and coin holders can now turn their coin into collateral.
 *
 *         8) `prepareCoinsForRedeeming(_wad)`
 *           - deposit the amount of coins to redeem in caller's accountance
 *           - Each unit of coin can claim a proportional amount of all of the system's collateral
 *           - At any point a user can get and prepare more coins to redeem for more collateral
 *
 *         9) `redeemCollateral(_cType, _wad)`
 *           - claim tokens from a specific collateral type given the amount of coins caller has deposited
 *           - The amount of collateral to redeem depends exclusively in the state variables calculated in the previous steps
 *           - The amount of collaterals left when all circulating coins are redeemed should be 0
 */
contract GlobalSettlement is Authorizable, Modifiable, Disableable, IGlobalSettlement {
  using Math for uint256;
  using Assertions for address;
  using Encoding for bytes;

  // --- Data ---
  /// @inheritdoc IGlobalSettlement
  uint256 public shutdownTime;
  /// @inheritdoc IGlobalSettlement
  uint256 /* RAD */ public outstandingCoinSupply;

  /// @inheritdoc IGlobalSettlement
  mapping(bytes32 _cType => uint256 _ray) public finalCoinPerCollateralPrice;
  /// @inheritdoc IGlobalSettlement
  mapping(bytes32 _cType => uint256 _wad) public collateralShortfall;
  /// @inheritdoc IGlobalSettlement
  mapping(bytes32 _cType => uint256 _wad) public collateralTotalDebt;
  /// @inheritdoc IGlobalSettlement
  mapping(bytes32 _cType => uint256 _ray) public collateralCashPrice;

  /// @inheritdoc IGlobalSettlement
  mapping(address _usr => uint256 _wad) public coinBag;
  /// @inheritdoc IGlobalSettlement
  mapping(bytes32 _cType => mapping(address _usr => uint256 _wad)) public coinsUsedToRedeem;

  // --- Registry ---

  /// @inheritdoc IGlobalSettlement
  ISAFEEngine public safeEngine;
  /// @inheritdoc IGlobalSettlement
  ILiquidationEngine public liquidationEngine;
  /// @inheritdoc IGlobalSettlement
  IOracleRelayer public oracleRelayer;

  /// @inheritdoc IGlobalSettlement
  IDisableable public coinJoin;
  /// @inheritdoc IGlobalSettlement
  IDisableable public collateralJoinFactory;
  /// @inheritdoc IGlobalSettlement
  IDisableable public collateralAuctionHouseFactory;
  /// @inheritdoc IGlobalSettlement
  IDisableable public stabilityFeeTreasury;
  /// @inheritdoc IGlobalSettlement
  IDisableable public accountingEngine;

  /// @inheritdoc IGlobalSettlement
  // solhint-disable-next-line private-vars-leading-underscore
  GlobalSettlementParams public _params;

  /// @inheritdoc IGlobalSettlement
  function params() external view returns (GlobalSettlementParams memory _globalSettlementParams) {
    return _params;
  }

  // --- Init ---

  /**
   * @param  _safeEngine Address of the SAFEEngine contract
   * @param  _liquidationEngine Address of the LiquidationEngine contract
   * @param  _oracleRelayer Address of the OracleRelayer contract
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _collateralJoinFactory Address of the CollateralJoinFactory contract
   * @param  _collateralAuctionHouseFactory Address of the CollateralAuctionHouseFactory contract
   * @param  _stabilityFeeTreasury Address of the StabilityFeeTreasury contract
   * @param  _accountingEngine Address of the AccountingEngine contract
   * @param  _gsParams Initial valid GlobalSettlement parameters struct
   */
  constructor(
    address _safeEngine,
    address _liquidationEngine,
    address _oracleRelayer,
    address _coinJoin,
    address _collateralJoinFactory,
    address _collateralAuctionHouseFactory,
    address _stabilityFeeTreasury,
    address _accountingEngine,
    GlobalSettlementParams memory _gsParams
  ) Authorizable(msg.sender) validParams {
    safeEngine = ISAFEEngine(_safeEngine.assertNonNull());
    liquidationEngine = ILiquidationEngine(_liquidationEngine);
    oracleRelayer = IOracleRelayer(_oracleRelayer);
    coinJoin = IDisableable(_coinJoin);
    collateralJoinFactory = IDisableable(_collateralJoinFactory);
    collateralAuctionHouseFactory = IDisableable(_collateralAuctionHouseFactory);
    stabilityFeeTreasury = IDisableable(_stabilityFeeTreasury);
    accountingEngine = IDisableable(_accountingEngine);

    _params = _gsParams;
  }

  // --- Shutdown ---

  /**
   * @dev   Method override avoids externally disabling this contract
   * @inheritdoc Disableable
   */
  function _onContractDisable() internal pure override {
    revert NonDisableable();
  }

  // --- Settlement ---

  /// @inheritdoc IGlobalSettlement
  function shutdownSystem() external isAuthorized whenEnabled {
    shutdownTime = block.timestamp;
    contractEnabled = false;

    // Locks the system (SAFEs cannot be modified through the SAFEEngine)
    safeEngine.disableContract();
    // Locks the oracle relayer (no more price updates)
    oracleRelayer.disableContract();
    // Avoids further liquidations
    liquidationEngine.disableContract();
    // Avoids further collateral being bought at auctions
    collateralAuctionHouseFactory.disableContract();
    // Avoids further coins from exiting the system (being minted for internal balance)
    coinJoin.disableContract();
    // Avoids further collateral from entering the system (join)
    collateralJoinFactory.disableContract();
    // Transfers all surplus treasury funds to the accounting engine
    stabilityFeeTreasury.disableContract();
    // Disables DAH and SAH and tries to settle as much debt as possible
    accountingEngine.disableContract();

    emit ShutdownSystem();
  }

  /// @inheritdoc IGlobalSettlement
  function freezeCollateralType(bytes32 _cType) external whenDisabled {
    if (finalCoinPerCollateralPrice[_cType] != 0) revert GS_FinalCollateralPriceAlreadyDefined();
    collateralTotalDebt[_cType] = safeEngine.cData(_cType).debtAmount;
    IBaseOracle _oracle = oracleRelayer.cParams(_cType).oracle;

    // redemptionPrice is a ray, orcl returns a wad, finalCoinPerCollateralPrice is a ray
    finalCoinPerCollateralPrice[_cType] = oracleRelayer.redemptionPrice().wdiv(_oracle.read());
    emit FreezeCollateralType(_cType, finalCoinPerCollateralPrice[_cType]);
  }

  /// @inheritdoc IGlobalSettlement
  function fastTrackAuction(bytes32 _cType, uint256 _auctionId) external {
    if (finalCoinPerCollateralPrice[_cType] == 0) revert GS_FinalCollateralPriceNotDefined();

    ICollateralAuctionHouse _collateralAuctionHouse =
      ICollateralAuctionHouse(liquidationEngine.cParams(_cType).collateralAuctionHouse);
    uint256 _accumulatedRate = safeEngine.cData(_cType).accumulatedRate;

    ICollateralAuctionHouse.Auction memory _auction = _collateralAuctionHouse.auctions(_auctionId);

    // Creates an unbacked debt at the accounting engine
    safeEngine.createUnbackedDebt({
      _debtDestination: address(accountingEngine),
      _coinDestination: address(accountingEngine),
      _rad: _auction.amountToRaise
    });

    // Returns debt to the SAFE owner and withdraw the collateral from the auction (to this contract)
    _collateralAuctionHouse.terminateAuctionPrematurely(_auctionId);

    uint256 _debt = _auction.amountToRaise / _accumulatedRate;
    collateralTotalDebt[_cType] += _debt;

    // Transfers the collateral (from this) and the unbacked debt (from accounting engine) to the SAFE owner
    safeEngine.confiscateSAFECollateralAndDebt({
      _cType: _cType,
      _safe: _auction.forgoneCollateralReceiver,
      _collateralSource: address(this),
      _debtDestination: address(accountingEngine),
      _deltaCollateral: _auction.amountToSell.toInt(),
      _deltaDebt: _debt.toInt()
    });

    emit FastTrackAuction(_cType, _auctionId, collateralTotalDebt[_cType]);
  }

  /// @inheritdoc IGlobalSettlement
  function processSAFE(bytes32 _cType, address _safe) external {
    if (finalCoinPerCollateralPrice[_cType] == 0) revert GS_FinalCollateralPriceNotDefined();

    ISAFEEngine.SAFE memory _safeData = safeEngine.safes(_cType, _safe);
    uint256 _accumulatedRate = safeEngine.cData(_cType).accumulatedRate;
    uint256 _amountOwed = _safeData.generatedDebt.rmul(_accumulatedRate).rmul(finalCoinPerCollateralPrice[_cType]);
    uint256 _minCollateral = Math.min(_safeData.lockedCollateral, _amountOwed);

    // If the SAFE is undercollateralized, add the difference to the collateral shortfall
    collateralShortfall[_cType] += _amountOwed - _minCollateral;

    safeEngine.confiscateSAFECollateralAndDebt({
      _cType: _cType,
      _safe: _safe,
      _collateralSource: address(this),
      _debtDestination: address(accountingEngine),
      _deltaCollateral: -int256(_minCollateral), // safe cast
      _deltaDebt: -_safeData.generatedDebt.toInt()
    });

    emit ProcessSAFE(_cType, _safe, collateralShortfall[_cType]);
  }

  /// @inheritdoc IGlobalSettlement
  function freeCollateral(bytes32 _cType) external whenDisabled {
    ISAFEEngine.SAFE memory _safeData = safeEngine.safes(_cType, msg.sender);
    if (_safeData.generatedDebt != 0) revert GS_SafeDebtNotZero();

    safeEngine.confiscateSAFECollateralAndDebt({
      _cType: _cType,
      _safe: msg.sender,
      _collateralSource: msg.sender,
      _debtDestination: address(accountingEngine),
      _deltaCollateral: -_safeData.lockedCollateral.toInt(),
      _deltaDebt: 0
    });

    emit FreeCollateral(_cType, msg.sender, _safeData.lockedCollateral);
  }

  /// @inheritdoc IGlobalSettlement
  function setOutstandingCoinSupply() external whenDisabled {
    if (outstandingCoinSupply != 0) revert GS_OutstandingCoinSupplyNotZero();
    if (safeEngine.coinBalance(address(accountingEngine)) != 0) revert GS_SurplusNotZero();
    if (block.timestamp < shutdownTime + _params.shutdownCooldown) revert GS_ShutdownCooldownNotFinished();

    outstandingCoinSupply = safeEngine.globalDebt();

    emit SetOutstandingCoinSupply(outstandingCoinSupply);
  }

  /// @inheritdoc IGlobalSettlement
  function calculateCashPrice(bytes32 _cType) external {
    if (outstandingCoinSupply == 0) revert GS_OutstandingCoinSupplyZero();
    if (collateralCashPrice[_cType] != 0) revert GS_CollateralCashPriceAlreadyDefined();

    uint256 _accumulatedRate = safeEngine.cData(_cType).accumulatedRate;
    uint256 _redemptionAdjustedDebt =
      collateralTotalDebt[_cType].rmul(_accumulatedRate).rmul(finalCoinPerCollateralPrice[_cType]);

    collateralCashPrice[_cType] =
      (_redemptionAdjustedDebt - collateralShortfall[_cType]).rdiv(outstandingCoinSupply / RAY);

    emit CalculateCashPrice(_cType, collateralCashPrice[_cType]);
  }

  /// @inheritdoc IGlobalSettlement
  function prepareCoinsForRedeeming(uint256 _coinAmount) external {
    if (outstandingCoinSupply == 0) revert GS_OutstandingCoinSupplyZero();

    safeEngine.transferInternalCoins(msg.sender, address(accountingEngine), _coinAmount * RAY);
    coinBag[msg.sender] += _coinAmount;

    emit PrepareCoinsForRedeeming(msg.sender, coinBag[msg.sender]);
  }

  /// @inheritdoc IGlobalSettlement
  function redeemCollateral(bytes32 _cType, uint256 _coinsAmount) external {
    if (collateralCashPrice[_cType] == 0) revert GS_CollateralCashPriceNotDefined();

    uint256 _collateralAmount = _coinsAmount.rmul(collateralCashPrice[_cType]);

    safeEngine.transferCollateral({
      _cType: _cType,
      _source: address(this),
      _destination: msg.sender,
      _wad: _collateralAmount
    });

    coinsUsedToRedeem[_cType][msg.sender] += _coinsAmount;

    if (coinsUsedToRedeem[_cType][msg.sender] > coinBag[msg.sender]) revert GS_InsufficientBagBalance();
    emit RedeemCollateral(_cType, msg.sender, _coinsAmount, _collateralAmount);
  }

  // --- Administration ---

  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override whenEnabled {
    address _address = _data.toAddress();

    if (_param == 'oracleRelayer') oracleRelayer = IOracleRelayer(_address);
    else if (_param == 'liquidationEngine') liquidationEngine = ILiquidationEngine(_address);
    else if (_param == 'coinJoin') coinJoin = IDisableable(_address);
    else if (_param == 'collateralJoinFactory') collateralJoinFactory = IDisableable(_address);
    else if (_param == 'collateralAuctionHouseFactory') collateralAuctionHouseFactory = IDisableable(_address);
    else if (_param == 'stabilityFeeTreasury') stabilityFeeTreasury = IDisableable(_address);
    else if (_param == 'accountingEngine') accountingEngine = IDisableable(_address);
    else if (_param == 'shutdownCooldown') _params.shutdownCooldown = _data.toUint256();
    else revert UnrecognizedParam();
  }

  /// @inheritdoc Modifiable
  function _validateParameters() internal view override {
    address(liquidationEngine).assertHasCode();
    address(oracleRelayer).assertHasCode();
    address(coinJoin).assertHasCode();
    address(collateralJoinFactory).assertHasCode();
    address(collateralAuctionHouseFactory).assertHasCode();
    address(stabilityFeeTreasury).assertHasCode();
    address(accountingEngine).assertHasCode();
  }
}

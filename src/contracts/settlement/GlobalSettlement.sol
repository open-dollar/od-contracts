// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

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
 *
 *         !System shutdown:
 *         1. `shutdownSystem()`: freeze the system and start the cooldown period
 *         2. `freezeCollateralType(_cType)`: read and store the final price for each collateral type
 *           - initializes `collateralTotalDebt` to the total debt registered in safe engine
 *
 *         !Cooldown period:
 *         We must process some system state before it is possible to calculate the final coin / collateral price.
 *         In particular, we need to determine:
 *           a. `collateralShortfall` (considers under-collateralized SAFEs)
 *           b. `outstandingCoinSupply` (after including system surplus / deficit)
 *
 *         We determine (a) by processing all under-collateralized SAFEs:
 *         3. `processSAFE(_cType, _safe)`: confiscates SAFE debt and backing collateral (excess of collateral remains)
 *
 *         We determine (b) by processing ongoing coin generating processes, i.e. auctions.
 *         We need to ensure that auctions will not generate any further coin income.
 *         4. Auctions at SAH and DAH can be terminated prematurely, while CAH auctions are handled by this contract
 *           4.a) `SAH.terminateAuctionPrematurely` settles the auction: transfers the surplus to the highest bidder
 *           4.b) `DAH.terminateAuctionPrematurely` settles the auction:
 *             - returns the coins to the highest bidder
 *             - registers the unbacked debt at the accounting engine
 *           4.c) `this.fastTrackAuction`
 *             - settles the auction: returns collateral and debt to the SAFE
 *             - registers returned debt in `collateralTotalDebt`
 *
 *         When an overcollateralized SAFE has been processed and has no debt remaining, the remaining collateral can be withdrawn:
 *         5. `freeCollateral(_cType)`: remove collateral from the caller's SAFE (requires SAFE to have no debt)
 *
 *         !After cooldown period:
 *         We enable calculation of the final price for each collateral type, requires accounting engine to have no surplus
 *         6. `setOutstandingCoinSupply()`: fixes the total outstanding supply of coin
 *         7. `calculateCashPrice(_cType)`: calculate `collateralCashPrice` adjusted in the case of deficit / surplus
 *
 *         !Redeeming:
 *         At this point we have computed the final price for each collateral type and coin holders can now turn their coin into collateral:
 *         8. `prepareCoinsForRedeeming(_coinAmount)`: deposit the amount of coins to redeem in caller's accountance
 *           - Each unit of coin can claim a proportional amount of all of the system's collateral
 *           - At any point can a user get more coins to redeem for more collateral
 *         9. `redeemCollateral(_cType, _wad)`: claim tokens from a specific collateral type given the amount of coins caller has deposited
 *           - The amount of collateral to redeem depends exclusively in the state variables calculated in the previous steps
 *           - The amount of collaterals left when all circulating coins are redeemed should be 0
 */

contract GlobalSettlement is Authorizable, Modifiable, Disableable, IGlobalSettlement {
  using Math for uint256;
  using Assertions for address;
  using Encoding for bytes;

  // --- Data ---
  // The timestamp when settlement was triggered
  uint256 public shutdownTime;

  // The outstanding supply of system coins computed during the setOutstandingCoinSupply() phase
  uint256 /* RAD */ public outstandingCoinSupply;

  // The amount of collateral that a system coin can redeem
  mapping(bytes32 _cType => uint256 _ray) public finalCoinPerCollateralPrice;
  // Total amount of bad debt in SAFEs per collateral
  mapping(bytes32 _cType => uint256 _wad) public collateralShortfall;
  // Total debt backed by every collateral type
  mapping(bytes32 _cType => uint256 _wad) public collateralTotalDebt;
  // Final collateral prices in terms of system coins (applying system surplus/deficit & finalCoinPerCollateralPrices)
  mapping(bytes32 _cType => uint256 _ray) public collateralCashPrice;

  // Bags of coins ready to be used for collateral redemption
  mapping(address _usr => uint256 _wad) public coinBag;
  // Amount of coins already used for collateral redemption per user per collateral types
  mapping(bytes32 _cType => mapping(address _usr => uint256 _wad)) public coinsUsedToRedeem;

  // --- Registry ---
  ISAFEEngine public safeEngine;
  ILiquidationEngine public liquidationEngine;
  IOracleRelayer public oracleRelayer;

  IDisableable public coinJoin;
  IDisableable public collateralJoinFactory;
  IDisableable public collateralAuctionHouseFactory;
  IDisableable public stabilityFeeTreasury;
  IDisableable public accountingEngine;

  // solhint-disable-next-line private-vars-leading-underscore
  GlobalSettlementParams public _params;

  function params() external view returns (GlobalSettlementParams memory _globalSettlementParams) {
    return _params;
  }

  // --- Init ---
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

  /// @dev Avoids externally disabling this contract
  function _onContractDisable() internal pure override {
    revert NonDisableable();
  }

  // --- Settlement ---

  /**
   * @notice Freeze the system and start the cooldown period
   */
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

  /**
   * @notice Calculate a collateral type's final price according to the latest system coin redemption price
   * @param _cType The collateral type to calculate the price for
   */
  function freezeCollateralType(bytes32 _cType) external whenDisabled {
    if (finalCoinPerCollateralPrice[_cType] != 0) revert GS_FinalCollateralPriceAlreadyDefined();
    collateralTotalDebt[_cType] = safeEngine.cData(_cType).debtAmount;
    IBaseOracle _oracle = oracleRelayer.cParams(_cType).oracle;

    // redemptionPrice is a ray, orcl returns a wad, finalCoinPerCollateralPrice is a ray
    finalCoinPerCollateralPrice[_cType] = oracleRelayer.redemptionPrice().wdiv(_oracle.read());
    emit FreezeCollateralType(_cType, finalCoinPerCollateralPrice[_cType]);
  }

  /**
   * @notice Fast track an ongoing collateral auction
   * @param _cType The collateral type associated with the auction contract
   * @param _auctionId The ID of the auction to be fast tracked
   */
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

  /**
   * @notice Cancel a SAFE's debt and leave any extra collateral in it
   * @param _cType The collateral type associated with the SAFE
   * @param _safe The SAFE to be processed
   */
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

  /**
   * @notice Remove collateral from the caller's SAFE (requires SAFE to have no debt)
   * @param _cType The collateral type to free
   */
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

  /**
   * @notice Set the final outstanding supply of system coins
   * @dev There must be no remaining surplus in the accounting engine
   */
  function setOutstandingCoinSupply() external whenDisabled {
    if (outstandingCoinSupply != 0) revert GS_OutstandingCoinSupplyNotZero();
    if (safeEngine.coinBalance(address(accountingEngine)) != 0) revert GS_SurplusNotZero();
    if (block.timestamp < shutdownTime + _params.shutdownCooldown) revert GS_ShutdownCooldownNotFinished();

    outstandingCoinSupply = safeEngine.globalDebt();

    emit SetOutstandingCoinSupply(outstandingCoinSupply);
  }

  /**
   * @notice Calculate a collateral's price taking into consideration system surplus/deficit and the finalCoinPerCollateralPrice
   * @param _cType The collateral whose cash price will be calculated
   */
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

  /**
   * @notice Add coins into a 'bag' so that you can use them to redeem collateral
   * @param _coinAmount The amount of internal system coins to add into the bag
   */
  function prepareCoinsForRedeeming(uint256 _coinAmount) external {
    if (outstandingCoinSupply == 0) revert GS_OutstandingCoinSupplyZero();

    safeEngine.transferInternalCoins(msg.sender, address(accountingEngine), _coinAmount * RAY);
    coinBag[msg.sender] += _coinAmount;

    emit PrepareCoinsForRedeeming(msg.sender, coinBag[msg.sender]);
  }

  /**
   * @notice Redeem a specific collateral type using an amount of internal system coins from your bag
   * @param _cType The collateral type to redeem
   * @param _coinsAmount The amount of internal coins to use from your bag
   */
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

  function _validateParameters() internal view override {
    address(liquidationEngine).assertNonNull();
    address(oracleRelayer).assertNonNull();
    address(coinJoin).assertNonNull();
    address(collateralJoinFactory).assertNonNull();
    address(collateralAuctionHouseFactory).assertNonNull();
    address(stabilityFeeTreasury).assertNonNull();
    address(accountingEngine).assertNonNull();
  }
}

// SPDX-License-Identifier: GPL-3.0
/// GlobalSettlement.sol

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
// Copyright (C) 2018 Lev Livnev <lev@liv.nev.org.uk>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

// TODO: address all contracts as IDisableable unless we need the interface to interact with them
import {
  IGlobalSettlement,
  ISAFEEngine,
  ILiquidationEngine,
  IAccountingEngine,
  IOracleRelayer,
  IStabilityFeeTreasury,
  ICollateralAuctionHouse,
  IBaseOracle
} from '@interfaces/settlement/IGlobalSettlement.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';
import {Disableable} from '@contracts/utils/Disableable.sol';

import {Encoding} from '@libraries/Encoding.sol';
import {Math, RAY} from '@libraries/Math.sol';

/*
    This is the Global Settlement module. It is an
    involved, stateful process that takes place over nine steps.
    First we freeze the system and lock the prices for each collateral type.
    1. `shutdownSystem()`:
        - freezes user entrypoints
        - starts cooldown period
    2. `freezeCollateralType(collateralType)`:
       - set the final price for each collateralType, reading off the price feed
    We must process some system state before it is possible to calculate
    the final coin / collateral price. In particular, we need to determine:
      a. `collateralShortfall` (considers under-collateralised SAFEs)
      b. `outstandingCoinSupply` (after including system surplus / deficit)
    We determine (a) by processing all under-collateralised SAFEs with
    `processSAFE`
    3. `processSAFE(collateralType, safe)`:
       - cancels SAFE debt
       - any excess collateral remains
       - backing collateral taken
    We determine (b) by processing ongoing coin generating processes,
    i.e. auctions. We need to ensure that auctions will not generate any
    further coin income. In the two-way auction model this occurs when
    all auctions are in the reverse (`decreaseSoldAmount`) phase. There are two ways
    of ensuring this:
    4.  i) `shutdownCooldown`: set the cooldown period to be at least as long as the
           longest auction duration, which needs to be determined by the
           shutdown administrator.
           This takes a fairly predictable time to occur but with altered
           auction dynamics due to the now varying price of the system coin.
       ii) `fastTrackAuction`: cancel all ongoing auctions and seize the collateral.
           This allows for faster processing at the expense of more
           processing calls. This option allows coin holders to retrieve
           their collateral faster.
           `fastTrackAuction(collateralType, auctionId)`:
            - cancel individual collateral auctions in the `increaseBidSize` (forward) phase
            - retrieves collateral and returns coins to bidder
            - `decreaseSoldAmount` (reverse) phase auctions can continue normally
    Option (i), `shutdownCooldown`, is sufficient for processing the system
    settlement but option (ii), `fastTrackAuction`, will speed it up. Both options
    are available in this implementation, with `fastTrackAuction` being enabled on a
    per-auction basis.
    When a SAFE has been processed and has no debt remaining, the
    remaining collateral can be removed.
    5. `freeCollateral(collateralType)`:
        - remove collateral from the caller's SAFE
        - owner can call as needed
    After the processing period has elapsed, we enable calculation of
    the final price for each collateral type.
    6. `setOutstandingCoinSupply()`:
       - only callable after processing time period elapsed
       - assumption that all under-collateralised SAFEs are processed
       - fixes the total outstanding supply of coin
       - may also require extra SAFE processing to cover system surplus
    7. `calculateCashPrice(collateralType)`:
        - calculate `collateralCashPrice`
        - adjusts `collateralCashPrice` in the case of deficit / surplus
    At this point we have computed the final price for each collateral
    type and coin holders can now turn their coin into collateral. Each
    unit coin can claim a fixed basket of collateral.
    Coin holders must first `prepareCoinsForRedeeming` into a `coinBag`. Once prepared,
    coins cannot be transferred out of the bag. More coin can be added to a bag later.
    8. `prepareCoinsForRedeeming(coinAmount)`:
        - put some coins into a bag in order to 'redeemCollateral'. The bigger the bag, the more collateral the user can claim.
    9. `redeemCollateral(collateralType, collateralAmount)`:
        - exchange some coin from your bag for tokens from a specific collateral type
        - the amount of collateral available to redeem is limited by how big your bag is
*/

contract GlobalSettlement is Authorizable, Modifiable, Disableable, IGlobalSettlement {
  using Math for uint256;
  using Encoding for bytes;

  // --- Data ---
  // The timestamp when settlement was triggered
  uint256 public shutdownTime;
  // The amount of time post settlement during which no processing takes place
  uint256 public shutdownCooldown;
  // The outstanding supply of system coins computed during the setOutstandingCoinSupply() phase
  uint256 public outstandingCoinSupply; // [rad]

  // The amount of collateral that a system coin can redeem
  mapping(bytes32 => uint256) public finalCoinPerCollateralPrice; // [ray]
  // Total amount of bad debt in SAFEs with different collateral types
  mapping(bytes32 => uint256) public collateralShortfall; // [wad]
  // Total debt backed by every collateral type
  mapping(bytes32 => uint256) public collateralTotalDebt; // [wad]
  // Mapping of collateral prices in terms of system coins after taking into account system surplus/deficit and finalCoinPerCollateralPrices
  mapping(bytes32 => uint256) public collateralCashPrice; // [ray]

  // Bags of coins ready to be used for collateral redemption
  mapping(address => uint256) public coinBag; // [wad]
  // Amount of coins already used for collateral redemption by every address and for different collateral types
  mapping(bytes32 => mapping(address => uint256)) public coinsUsedToRedeem; // [wad]

  // --- Registry ---
  ISAFEEngine public safeEngine;
  ILiquidationEngine public liquidationEngine;
  IAccountingEngine public accountingEngine;
  IOracleRelayer public oracleRelayer;
  IStabilityFeeTreasury public stabilityFeeTreasury;

  // --- Init ---
  constructor() Authorizable(msg.sender) {}

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
    contractEnabled = 0;

    safeEngine.disableContract();
    liquidationEngine.disableContract();
    // treasury must be disabled before the accounting engine so that all surplus is gathered in one place
    if (address(stabilityFeeTreasury) != address(0)) stabilityFeeTreasury.disableContract();
    accountingEngine.disableContract();
    oracleRelayer.disableContract();
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
    // redemptionPrice is a ray, orcl returns a wad
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

    address _auctionHouse = liquidationEngine.cParams(_cType).collateralAuctionHouse;
    ICollateralAuctionHouse _collateralAuctionHouse = ICollateralAuctionHouse(_auctionHouse);
    uint256 _accumulatedRate = safeEngine.cData(_cType).accumulatedRate;

    uint256 _bidAmount = _collateralAuctionHouse.bidAmount(_auctionId);
    uint256 _raisedAmount = _collateralAuctionHouse.raisedAmount(_auctionId);
    uint256 _collateralToSell = _collateralAuctionHouse.remainingAmountToSell(_auctionId);
    address _forgoneCollateralReceiver = _collateralAuctionHouse.forgoneCollateralReceiver(_auctionId);
    uint256 _amountToRaise = _collateralAuctionHouse.amountToRaise(_auctionId);

    safeEngine.createUnbackedDebt(address(accountingEngine), address(accountingEngine), _amountToRaise - _raisedAmount);
    safeEngine.createUnbackedDebt(address(accountingEngine), address(this), _bidAmount);
    safeEngine.approveSAFEModification(address(_collateralAuctionHouse));
    _collateralAuctionHouse.terminateAuctionPrematurely(_auctionId);

    uint256 _debt = (_amountToRaise - _raisedAmount) / _accumulatedRate;
    collateralTotalDebt[_cType] += _debt;
    safeEngine.confiscateSAFECollateralAndDebt(
      _cType,
      _forgoneCollateralReceiver,
      address(this),
      address(accountingEngine),
      _collateralToSell.toIntNotOverflow(),
      _debt.toIntNotOverflow()
    );
    emit FastTrackAuction(_cType, _auctionId, collateralTotalDebt[_cType]);
  }

  /**
   * @notice Cancel a SAFE's debt and leave any extra collateral in it
   * @param _cType The collateral type associated with the SAFE
   * @param _safe The SAFE to be processed
   */
  function processSAFE(bytes32 _cType, address _safe) external {
    if (finalCoinPerCollateralPrice[_cType] == 0) revert GS_FinalCollateralPriceNotDefined();
    uint256 _accumulatedRate = safeEngine.cData(_cType).accumulatedRate;
    ISAFEEngine.SAFE memory _safeData = safeEngine.safes(_cType, _safe);

    uint256 _amountOwed = _safeData.generatedDebt.rmul(_accumulatedRate).rmul(finalCoinPerCollateralPrice[_cType]);
    uint256 _minCollateral = Math.min(_safeData.lockedCollateral, _amountOwed);
    collateralShortfall[_cType] += _amountOwed - _minCollateral;

    safeEngine.confiscateSAFECollateralAndDebt(
      _cType,
      _safe,
      address(this),
      address(accountingEngine),
      -int256(_minCollateral), // safe cast: cannot overflow because result of rmul
      -_safeData.generatedDebt.toIntNotOverflow()
    );

    emit ProcessSAFE(_cType, _safe, collateralShortfall[_cType]);
  }

  /**
   * @notice Remove collateral from the caller's SAFE
   * @param _cType The collateral type to free
   */
  function freeCollateral(bytes32 _cType) external whenDisabled {
    ISAFEEngine.SAFE memory _safeData = safeEngine.safes(_cType, msg.sender);
    if (_safeData.generatedDebt != 0) revert GS_SafeDebtNotZero();
    safeEngine.confiscateSAFECollateralAndDebt(
      _cType, msg.sender, msg.sender, address(accountingEngine), -_safeData.lockedCollateral.toIntNotOverflow(), 0
    );
    emit FreeCollateral(_cType, msg.sender, -_safeData.lockedCollateral.toIntNotOverflow());
  }

  /**
   * @notice Set the final outstanding supply of system coins
   * @dev There must be no remaining surplus in the accounting engine
   */
  function setOutstandingCoinSupply() external whenDisabled {
    if (outstandingCoinSupply != 0) revert GS_OutstandingCoinSupplyNotZero();
    if (safeEngine.coinBalance(address(accountingEngine)) != 0) revert GS_SurplusNotZero();
    if (block.timestamp < shutdownTime + shutdownCooldown) revert GS_ShutdownCooldownNotFinished();
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
      (_redemptionAdjustedDebt - collateralShortfall[_cType]) * RAY / (outstandingCoinSupply / RAY);

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
    safeEngine.transferCollateral(_cType, address(this), msg.sender, _collateralAmount);
    coinsUsedToRedeem[_cType][msg.sender] += _coinsAmount;
    if (coinsUsedToRedeem[_cType][msg.sender] > coinBag[msg.sender]) revert GS_InsufficientBagBalance();
    emit RedeemCollateral(_cType, msg.sender, _coinsAmount, _collateralAmount);
  }

  // --- Administration ---

  function _modifyParameters(bytes32 _param, bytes memory _data) internal override whenEnabled {
    address _address = _data.toAddress();

    if (_param == 'safeEngine') safeEngine = ISAFEEngine(_address);
    else if (_param == 'liquidationEngine') liquidationEngine = ILiquidationEngine(_address);
    else if (_param == 'accountingEngine') accountingEngine = IAccountingEngine(_address);
    else if (_param == 'oracleRelayer') oracleRelayer = IOracleRelayer(_address);
    else if (_param == 'stabilityFeeTreasury') stabilityFeeTreasury = IStabilityFeeTreasury(_address);
    else if (_param == 'shutdownCooldown') shutdownCooldown = _data.toUint256();
    else revert UnrecognizedParam();
  }
}

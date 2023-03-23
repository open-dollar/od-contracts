// SPDX-License-Identifier: GPL-3.0
/// LiquidationEngine.sol

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
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

import {ICollateralAuctionHouse as CollateralAuctionHouseLike} from '../interfaces/ICollateralAuctionHouse.sol';
import {ISAFESaviour as SAFESaviourLike} from '../interfaces/external/ISAFESaviour.sol';
import {ISAFEEngine as SAFEEngineLike} from '../interfaces/ISAFEEngine.sol';
import {IAccountingEngine as AccountingEngineLike} from '../interfaces/IAccountingEngine.sol';

import {Math} from './utils/Math.sol';

contract LiquidationEngine is Math {
  // --- Auth ---
  mapping(address => uint256) public authorizedAccounts;
  /**
   * @notice Add auth to an account
   * @param account Account to add auth to
   */

  function addAuthorization(address account) external isAuthorized {
    authorizedAccounts[account] = 1;
    emit AddAuthorization(account);
  }
  /**
   * @notice Remove auth from an account
   * @param account Account to remove auth from
   */

  function removeAuthorization(address account) external isAuthorized {
    authorizedAccounts[account] = 0;
    emit RemoveAuthorization(account);
  }
  /**
   * @notice Checks whether msg.sender can call an authed function
   *
   */

  modifier isAuthorized() {
    require(authorizedAccounts[msg.sender] == 1, 'LiquidationEngine/account-not-authorized');
    _;
  }

  // --- SAFE Saviours ---
  // Contracts that can save SAFEs from liquidation
  mapping(address => uint256) public safeSaviours;
  /**
   * @notice Authed function to add contracts that can save SAFEs from liquidation
   * @param saviour SAFE saviour contract to be whitelisted
   *
   */

  function connectSAFESaviour(address saviour) external isAuthorized {
    (bool ok, uint256 collateralAdded, uint256 liquidatorReward) =
      SAFESaviourLike(saviour).saveSAFE(address(this), '', address(0));
    require(ok, 'LiquidationEngine/saviour-not-ok');
    require(
      collateralAdded == uint256(int256(-1)) && liquidatorReward == uint256(int256(-1)),
      'LiquidationEngine/invalid-amounts'
    );
    safeSaviours[saviour] = 1;
    emit ConnectSAFESaviour(saviour);
  }
  /**
   * @notice Governance used function to remove contracts that can save SAFEs from liquidation
   * @param saviour SAFE saviour contract to be removed
   *
   */

  function disconnectSAFESaviour(address saviour) external isAuthorized {
    safeSaviours[saviour] = 0;
    emit DisconnectSAFESaviour(saviour);
  }

  // --- Data ---
  struct CollateralType {
    // Address of the collateral auction house handling liquidations for this collateral type
    address collateralAuctionHouse;
    // Penalty applied to every liquidation involving this collateral type. Discourages SAFE users from bidding on their own SAFEs
    uint256 liquidationPenalty; // [wad]
    // Max amount of system coins to request in one auction
    uint256 liquidationQuantity; // [rad]
  }

  // Collateral types included in the system
  mapping(bytes32 => CollateralType) public collateralTypes;
  // Saviour contract chosen for each SAFE by its creator
  mapping(bytes32 => mapping(address => address)) public chosenSAFESaviour;
  // Mutex used to block against re-entrancy when 'liquidateSAFE' passes execution to a saviour
  mapping(bytes32 => mapping(address => uint8)) public mutex;

  // Max amount of system coins that can be on liquidation at any time
  uint256 public onAuctionSystemCoinLimit; // [rad]
  // Current amount of system coins out for liquidation
  uint256 public currentOnAuctionSystemCoins; // [rad]
  // Whether this contract is enabled
  uint256 public contractEnabled;

  SAFEEngineLike public safeEngine;
  AccountingEngineLike public accountingEngine;

  // --- Events ---
  event AddAuthorization(address account);
  event RemoveAuthorization(address account);
  event ConnectSAFESaviour(address saviour);
  event DisconnectSAFESaviour(address saviour);
  event UpdateCurrentOnAuctionSystemCoins(uint256 currentOnAuctionSystemCoins);
  event ModifyParameters(bytes32 parameter, uint256 data);
  event ModifyParameters(bytes32 parameter, address data);
  event ModifyParameters(bytes32 collateralType, bytes32 parameter, uint256 data);
  event ModifyParameters(bytes32 collateralType, bytes32 parameter, address data);
  event DisableContract();
  event Liquidate(
    bytes32 indexed collateralType,
    address indexed safe,
    uint256 collateralAmount,
    uint256 debtAmount,
    uint256 amountToRaise,
    address collateralAuctioneer,
    uint256 auctionId
  );
  event SaveSAFE(bytes32 indexed collateralType, address indexed safe, uint256 collateralAddedOrDebtRepaid);
  event FailedSAFESave(bytes failReason);
  event ProtectSAFE(bytes32 indexed collateralType, address indexed safe, address saviour);

  // --- Init ---
  constructor(address _safeEngine) {
    authorizedAccounts[msg.sender] = 1;

    safeEngine = SAFEEngineLike(_safeEngine);
    onAuctionSystemCoinLimit = uint256(int256(-1));
    contractEnabled = 1;

    emit AddAuthorization(msg.sender);
    emit ModifyParameters('onAuctionSystemCoinLimit', uint256(int256(-1)));
  }

  // --- Administration ---
  /*
    * @notice Modify uint256 parameters
    * @param paramter The name of the parameter modified
    * @param data Value for the new parameter
    */
  function modifyParameters(bytes32 parameter, uint256 data) external isAuthorized {
    if (parameter == 'onAuctionSystemCoinLimit') onAuctionSystemCoinLimit = data;
    else revert('LiquidationEngine/modify-unrecognized-param');
    emit ModifyParameters(parameter, data);
  }
  /**
   * @notice Modify contract integrations
   * @param parameter The name of the parameter modified
   * @param data New address for the parameter
   */

  function modifyParameters(bytes32 parameter, address data) external isAuthorized {
    if (parameter == 'accountingEngine') accountingEngine = AccountingEngineLike(data);
    else revert('LiquidationEngine/modify-unrecognized-param');
    emit ModifyParameters(parameter, data);
  }
  /**
   * @notice Modify liquidation params
   * @param collateralType The collateral type we change parameters for
   * @param parameter The name of the parameter modified
   * @param data New value for the parameter
   */

  function modifyParameters(bytes32 collateralType, bytes32 parameter, uint256 data) external isAuthorized {
    if (parameter == 'liquidationPenalty') {
      collateralTypes[collateralType].liquidationPenalty = data;
    } else if (parameter == 'liquidationQuantity') {
      require(data <= MAX_LIQUIDATION_QUANTITY, 'LiquidationEngine/liquidation-quantity-overflow');
      collateralTypes[collateralType].liquidationQuantity = data;
    } else {
      revert('LiquidationEngine/modify-unrecognized-param');
    }
    emit ModifyParameters(collateralType, parameter, data);
  }
  /**
   * @notice Modify collateral auction address
   * @param collateralType The collateral type we change parameters for
   * @param parameter The name of the integration modified
   * @param data New address for the integration contract
   */

  function modifyParameters(bytes32 collateralType, bytes32 parameter, address data) external isAuthorized {
    if (parameter == 'collateralAuctionHouse') {
      safeEngine.denySAFEModification(collateralTypes[collateralType].collateralAuctionHouse);
      collateralTypes[collateralType].collateralAuctionHouse = data;
      safeEngine.approveSAFEModification(data);
    } else {
      revert('LiquidationEngine/modify-unrecognized-param');
    }
    emit ModifyParameters(collateralType, parameter, data);
  }
  /**
   * @notice Disable this contract (normally called by GlobalSettlement)
   */

  function disableContract() external isAuthorized {
    contractEnabled = 0;
    emit DisableContract();
  }

  // --- SAFE Liquidation ---
  /**
   * @notice Choose a saviour contract for your SAFE
   * @param collateralType The SAFE's collateral type
   * @param safe The SAFE's address
   * @param saviour The chosen saviour
   */
  function protectSAFE(bytes32 collateralType, address safe, address saviour) external {
    require(safeEngine.canModifySAFE(safe, msg.sender), 'LiquidationEngine/cannot-modify-safe');
    require(saviour == address(0) || safeSaviours[saviour] == 1, 'LiquidationEngine/saviour-not-authorized');
    chosenSAFESaviour[collateralType][safe] = saviour;
    emit ProtectSAFE(collateralType, safe, saviour);
  }
  /**
   * @notice Liquidate a SAFE
   * @param collateralType The SAFE's collateral type
   * @param safe The SAFE's address
   */

  function liquidateSAFE(bytes32 collateralType, address safe) external returns (uint256 auctionId) {
    require(mutex[collateralType][safe] == 0, 'LiquidationEngine/non-null-mutex');
    mutex[collateralType][safe] = 1;

    (, uint256 accumulatedRate,,, uint256 debtFloor, uint256 liquidationPrice) =
      safeEngine.collateralTypes(collateralType);
    (uint256 safeCollateral, uint256 safeDebt) = safeEngine.safes(collateralType, safe);

    require(contractEnabled == 1, 'LiquidationEngine/contract-not-enabled');
    require(
      liquidationPrice > 0 && multiply(safeCollateral, liquidationPrice) < multiply(safeDebt, accumulatedRate),
      'LiquidationEngine/safe-not-unsafe'
    );
    require(
      currentOnAuctionSystemCoins < onAuctionSystemCoinLimit
        && subtract(onAuctionSystemCoinLimit, currentOnAuctionSystemCoins) >= debtFloor,
      'LiquidationEngine/liquidation-limit-hit'
    );

    if (
      chosenSAFESaviour[collateralType][safe] != address(0)
        && safeSaviours[chosenSAFESaviour[collateralType][safe]] == 1
    ) {
      try SAFESaviourLike(chosenSAFESaviour[collateralType][safe]).saveSAFE(msg.sender, collateralType, safe) returns (
        bool ok, uint256 collateralAddedOrDebtRepaid, uint256
      ) {
        if (ok && collateralAddedOrDebtRepaid > 0) {
          emit SaveSAFE(collateralType, safe, collateralAddedOrDebtRepaid);
        }
      } catch (bytes memory revertReason) {
        emit FailedSAFESave(revertReason);
      }
    }

    // Checks that the saviour didn't take collateral or add more debt to the SAFE
    {
      (uint256 newSafeCollateral, uint256 newSafeDebt) = safeEngine.safes(collateralType, safe);
      require(
        newSafeCollateral >= safeCollateral && newSafeDebt <= safeDebt,
        'LiquidationEngine/invalid-safe-saviour-operation'
      );
    }

    (, accumulatedRate,,,, liquidationPrice) = safeEngine.collateralTypes(collateralType);
    (safeCollateral, safeDebt) = safeEngine.safes(collateralType, safe);

    if ((liquidationPrice > 0) && (multiply(safeCollateral, liquidationPrice) < multiply(safeDebt, accumulatedRate))) {
      CollateralType memory collateralData = collateralTypes[collateralType];

      uint256 limitAdjustedDebt = minimum(
        safeDebt,
        multiply(
          minimum(collateralData.liquidationQuantity, subtract(onAuctionSystemCoinLimit, currentOnAuctionSystemCoins)),
          WAD
        ) / accumulatedRate / collateralData.liquidationPenalty
      );
      require(limitAdjustedDebt > 0, 'LiquidationEngine/null-auction');
      require(
        (limitAdjustedDebt == safeDebt)
          || (multiply(subtract(safeDebt, limitAdjustedDebt), accumulatedRate) >= debtFloor),
        'LiquidationEngine/dusty-safe'
      );

      uint256 collateralToSell = minimum(safeCollateral, multiply(safeCollateral, limitAdjustedDebt) / safeDebt);

      require(collateralToSell > 0, 'LiquidationEngine/null-collateral-to-sell');
      require(
        collateralToSell <= 2 ** 255 && limitAdjustedDebt <= 2 ** 255, 'LiquidationEngine/collateral-or-debt-overflow'
      );

      safeEngine.confiscateSAFECollateralAndDebt(
        collateralType,
        safe,
        address(this),
        address(accountingEngine),
        -int256(collateralToSell),
        -int256(limitAdjustedDebt)
      );
      accountingEngine.pushDebtToQueue(multiply(limitAdjustedDebt, accumulatedRate));

      {
        // This calcuation will overflow if multiply(limitAdjustedDebt, accumulatedRate) exceeds ~10^14,
        // i.e. the maximum amountToRaise is roughly 100 trillion system coins.
        uint256 amountToRaise_ =
          multiply(multiply(limitAdjustedDebt, accumulatedRate), collateralData.liquidationPenalty) / WAD;
        currentOnAuctionSystemCoins = addition(currentOnAuctionSystemCoins, amountToRaise_);

        auctionId = CollateralAuctionHouseLike(collateralData.collateralAuctionHouse).startAuction({
          _forgoneCollateralReceiver: safe,
          _initialBidder: address(accountingEngine),
          _amountToRaise: amountToRaise_,
          _collateralToSell: collateralToSell,
          _initialBid: 0
        });

        emit UpdateCurrentOnAuctionSystemCoins(currentOnAuctionSystemCoins);
      }

      emit Liquidate(
        collateralType,
        safe,
        collateralToSell,
        limitAdjustedDebt,
        multiply(limitAdjustedDebt, accumulatedRate),
        collateralData.collateralAuctionHouse,
        auctionId
      );
    }

    mutex[collateralType][safe] = 0;
  }
  /**
   * @notice Remove debt that was being auctioned
   * @param rad The amount of debt to withdraw from currentOnAuctionSystemCoins
   */

  function removeCoinsFromAuction(uint256 rad) public isAuthorized {
    currentOnAuctionSystemCoins = subtract(currentOnAuctionSystemCoins, rad);
    emit UpdateCurrentOnAuctionSystemCoins(currentOnAuctionSystemCoins);
  }

  // --- Getters ---
  /*
    * @notice Get the amount of debt that can currently be covered by a collateral auction for a specific safe
    * @param collateralType The collateral type stored in the SAFE
    * @param safe The SAFE's address/handler
    */
  function getLimitAdjustedDebtToCover(bytes32 collateralType, address safe) external view returns (uint256) {
    (, uint256 accumulatedRate,,,,) = safeEngine.collateralTypes(collateralType);
    (uint256 safeCollateral, uint256 safeDebt) = safeEngine.safes(collateralType, safe);
    CollateralType memory collateralData = collateralTypes[collateralType];

    return minimum(
      safeDebt,
      multiply(
        minimum(collateralData.liquidationQuantity, subtract(onAuctionSystemCoinLimit, currentOnAuctionSystemCoins)),
        WAD
      ) / accumulatedRate / collateralData.liquidationPenalty
    );
  }
}

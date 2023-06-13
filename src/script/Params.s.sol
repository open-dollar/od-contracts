// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Contracts} from '@script/Contracts.s.sol';

import {
  IBaseOracle,
  IAccountingEngine,
  ICollateralAuctionHouse,
  IDebtAuctionHouse,
  ISurplusAuctionHouse,
  IOracleRelayer,
  ISAFEEngine,
  ILiquidationEngine,
  IStabilityFeeTreasury,
  IPIDController,
  IPIDRateSetter,
  ITaxCollector,
  IGlobalSettlement,
  IModifiable
} from '@script/Contracts.s.sol';

import {WAD, RAY, RAD} from '@libraries/Math.sol';

// --- Utils ---

// HAI Params
bytes32 constant HAI = bytes32('HAI');
uint256 constant HAI_INITIAL_PRICE = 1e18; // 1 HAI = 1 USD

// Collateral Names
bytes32 constant ETH_A = bytes32('ETH-A');
bytes32 constant WETH = bytes32('WETH');
bytes32 constant WSTETH = bytes32('WSTETH');
bytes32 constant OP = bytes32('OP');

uint256 constant MINUS_0_5_PERCENT_PER_HOUR = 999_998_607_628_240_588_157_433_861;
uint256 constant MINUS_1_PERCENT_PER_HOUR = 999_997_208_243_937_652_252_849_536;
uint256 constant HALF_LIFE_30_DAYS = 999_999_711_200_000_000_000_000_000;

// NOTE: imported from https://etherscan.io/address/0x5CC4878eA3E6323FdA34b3D28551E1543DEe54C6
uint256 constant PROPORTIONAL_GAIN = 222_002_205_862;
uint256 constant INTEGRAL_GAIN = 16_442;

address constant SURPLUS_AUCTION_BID_RECEIVER = address(420); // address that receives protocol tokens

/**
 * @title Params
 * @notice This contract initializes all the contract parameters structs, so that they're inherited and available throughout scripts scopes.
 */
abstract contract Params {
  /**
   * @notice Initializes the parameters of the contracts, as many depend on the contracts addresses and need to be dynamically loaded.
   */
  function _getEnvironmentParams() internal virtual;

  // --- Contracts params ---

  ISAFEEngine.SAFEEngineParams _safeEngineParams;
  mapping(bytes32 => ISAFEEngine.SAFEEngineCollateralParams) _safeEngineCParams;

  IOracleRelayer.OracleRelayerParams _oracleRelayerParams;
  mapping(bytes32 => IOracleRelayer.OracleRelayerCollateralParams) _oracleRelayerCParams;
  IPIDController.PIDControllerParams _pidControllerParams;
  IPIDController.ControllerGains _pidControllerGains;
  IPIDRateSetter.PIDRateSetterParams _pidRateSetterParams;

  IAccountingEngine.AccountingEngineParams _accountingEngineParams;
  IDebtAuctionHouse.DebtAuctionHouseParams _debtAuctionHouseParams;
  ISurplusAuctionHouse.SurplusAuctionHouseParams _surplusAuctionHouseParams;
  ILiquidationEngine.LiquidationEngineParams _liquidationEngineParams;
  mapping(bytes32 => ILiquidationEngine.LiquidationEngineCollateralParams) _liquidationEngineCParams;
  ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams _collateralAuctionHouseSystemCoinParams;
  mapping(bytes32 => ICollateralAuctionHouse.CollateralAuctionHouseParams) _collateralAuctionHouseCParams;

  IStabilityFeeTreasury.StabilityFeeTreasuryParams _stabilityFeeTreasuryParams;
  ITaxCollector.TaxCollectorParams _taxCollectorParams;
  mapping(bytes32 => ITaxCollector.TaxCollectorCollateralParams) _taxCollectorCParams;
  ITaxCollector.TaxReceiver _taxCollectorSecondaryTaxReceiver;

  IGlobalSettlement.GlobalSettlementParams _globalSettlementParams;
}

/**
 * @title ParamSetter
 * @notice This library sets the parameters of the contracts, one by one, ensuring that they're set fully and correctly.
 */
library ParamSetter {
  function _setupSAFEEngine(ISAFEEngine _safeEngine, ISAFEEngine.SAFEEngineParams memory _params) internal {
    _safeEngine.modifyParameters('safeDebtCeiling', abi.encode(_params.safeDebtCeiling));
    _safeEngine.modifyParameters('globalDebtCeiling', abi.encode(_params.globalDebtCeiling));

    _checkParams(address(_safeEngine), abi.encode(_params));
  }

  function _setupSAFEEngineCollateral(
    bytes32 _cType,
    ISAFEEngine _safeEngine,
    ISAFEEngine.SAFEEngineCollateralParams memory _cParams
  ) internal {
    _safeEngine.modifyParameters(_cType, 'debtCeiling', abi.encode(_cParams.debtCeiling));
    _safeEngine.modifyParameters(_cType, 'debtFloor', abi.encode(_cParams.debtFloor));

    _checkCParams(address(_safeEngine), _cType, abi.encode(_cParams));
  }

  function _setupAccountingEngine(
    IAccountingEngine _accountingEngine,
    IAccountingEngine.AccountingEngineParams memory _params
  ) internal {
    _accountingEngine.modifyParameters('surplusIsTransferred', abi.encode(_params.surplusIsTransferred));
    _accountingEngine.modifyParameters('surplusDelay', abi.encode(_params.surplusDelay));
    _accountingEngine.modifyParameters('popDebtDelay', abi.encode(_params.popDebtDelay));
    _accountingEngine.modifyParameters('disableCooldown', abi.encode(_params.disableCooldown));
    _accountingEngine.modifyParameters('surplusAmount', abi.encode(_params.surplusAmount));
    _accountingEngine.modifyParameters('surplusBuffer', abi.encode(_params.surplusBuffer));
    _accountingEngine.modifyParameters('debtAuctionMintedTokens', abi.encode(_params.debtAuctionMintedTokens));
    _accountingEngine.modifyParameters('debtAuctionBidSize', abi.encode(_params.debtAuctionBidSize));
    _checkParams(address(_accountingEngine), abi.encode(_params));
  }

  function _setupLiquidationEngine(
    ILiquidationEngine _liquidationEngine,
    ILiquidationEngine.LiquidationEngineParams memory _params
  ) internal {
    _liquidationEngine.modifyParameters('onAuctionSystemCoinLimit', abi.encode(_params.onAuctionSystemCoinLimit));
    _checkParams(address(_liquidationEngine), abi.encode(_params));
  }

  function _setupLiquidationEngineCollateral(
    bytes32 _cType,
    ILiquidationEngine _liquidationEngine,
    ILiquidationEngine.LiquidationEngineCollateralParams memory _params
  ) internal {
    _liquidationEngine.modifyParameters(_cType, 'collateralAuctionHouse', abi.encode(_params.collateralAuctionHouse));
    _liquidationEngine.modifyParameters(_cType, 'liquidationPenalty', abi.encode(_params.liquidationPenalty));
    _liquidationEngine.modifyParameters(_cType, 'liquidationQuantity', abi.encode(_params.liquidationQuantity));

    _checkCParams(address(_liquidationEngine), _cType, abi.encode(_params));
  }

  function _setupDebtAuctionHouse(
    IDebtAuctionHouse _debtAuctionHouse,
    IDebtAuctionHouse.DebtAuctionHouseParams memory _params
  ) internal {
    _debtAuctionHouse.modifyParameters('bidDecrease', abi.encode(_params.bidDecrease));
    _debtAuctionHouse.modifyParameters('amountSoldIncrease', abi.encode(_params.amountSoldIncrease));
    _debtAuctionHouse.modifyParameters('bidDuration', abi.encode(_params.bidDuration));
    _debtAuctionHouse.modifyParameters('totalAuctionLength', abi.encode(_params.totalAuctionLength));

    _checkParams(address(_debtAuctionHouse), abi.encode(_params));
  }

  function _setupSurplusAuctionHouse(
    ISurplusAuctionHouse _surplusAuctionHouse,
    ISurplusAuctionHouse.SurplusAuctionHouseParams memory _params
  ) internal {
    _surplusAuctionHouse.modifyParameters('bidIncrease', abi.encode(_params.bidIncrease));
    _surplusAuctionHouse.modifyParameters('bidDuration', abi.encode(_params.bidDuration));
    _surplusAuctionHouse.modifyParameters('totalAuctionLength', abi.encode(_params.totalAuctionLength));
    _surplusAuctionHouse.modifyParameters('recyclingPercentage', abi.encode(_params.recyclingPercentage));

    _checkParams(address(_surplusAuctionHouse), abi.encode(_params));
  }

  function _setupTaxCollector(ITaxCollector _taxCollector, ITaxCollector.TaxCollectorParams memory _params) internal {
    _taxCollector.modifyParameters('primaryTaxReceiver', abi.encode(_params.primaryTaxReceiver));
    _taxCollector.modifyParameters('globalStabilityFee', abi.encode(_params.globalStabilityFee));
    _taxCollector.modifyParameters('maxSecondaryReceivers', abi.encode(_params.maxSecondaryReceivers));

    _checkParams(address(_taxCollector), abi.encode(_params));
  }

  function _setupTaxCollectorCollateral(
    bytes32 _cType,
    ITaxCollector _taxCollector,
    ITaxCollector.TaxCollectorCollateralParams memory _params,
    ITaxCollector.TaxReceiver memory _secondaryTaxReceiver
  ) internal {
    _taxCollector.modifyParameters(_cType, 'stabilityFee', abi.encode(_params.stabilityFee));
    _taxCollector.modifyParameters(_cType, 'secondaryTaxReceiver', abi.encode(_secondaryTaxReceiver));

    _checkCParams(address(_taxCollector), _cType, abi.encode(_params));
    // TODO: test secondaryTaxReceiver
  }

  function _setupCollateralAuctionHouse(
    bytes32 _cType,
    ICollateralAuctionHouse _collateralAuctionHouse,
    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cParams,
    ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams memory _params
  ) internal {
    _collateralAuctionHouse.modifyParameters('minimumBid', abi.encode(_cParams.minimumBid));
    _collateralAuctionHouse.modifyParameters('minDiscount', abi.encode(_cParams.minDiscount));
    _collateralAuctionHouse.modifyParameters('maxDiscount', abi.encode(_cParams.maxDiscount));
    _collateralAuctionHouse.modifyParameters(
      'perSecondDiscountUpdateRate', abi.encode(_cParams.perSecondDiscountUpdateRate)
    );
    _collateralAuctionHouse.modifyParameters('lowerCollateralDeviation', abi.encode(_cParams.lowerCollateralDeviation));
    _collateralAuctionHouse.modifyParameters('upperCollateralDeviation', abi.encode(_cParams.upperCollateralDeviation));

    _collateralAuctionHouse.modifyParameters('minSystemCoinDeviation', abi.encode(_params.minSystemCoinDeviation));
    _collateralAuctionHouse.modifyParameters('lowerSystemCoinDeviation', abi.encode(_params.lowerSystemCoinDeviation));
    _collateralAuctionHouse.modifyParameters('upperSystemCoinDeviation', abi.encode(_params.upperSystemCoinDeviation));

    _checkParams(address(_collateralAuctionHouse), abi.encode(_params));
    // _checkCParams(address(_collateralAuctionHouse), _cType, abi.encode(_cParams));

    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _emptyCParams;
    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _storedCParams = _collateralAuctionHouse.cParams(); // NOTE: doesnt input _cType
    require(keccak256(abi.encode(_storedCParams)) == keccak256(abi.encode(_cParams)));
    require(keccak256(abi.encode(_emptyCParams)) != keccak256(abi.encode(_cParams)));
  }

  function _setupStabilityFeeTreasury(
    IStabilityFeeTreasury _stabilityFeeTreasury,
    IStabilityFeeTreasury.StabilityFeeTreasuryParams memory _params
  ) internal {
    _stabilityFeeTreasury.modifyParameters('expensesMultiplier', abi.encode(_params.expensesMultiplier));
    _stabilityFeeTreasury.modifyParameters('treasuryCapacity', abi.encode(_params.treasuryCapacity));
    _stabilityFeeTreasury.modifyParameters('minFundsRequired', abi.encode(_params.minFundsRequired));
    _stabilityFeeTreasury.modifyParameters('pullFundsMinThreshold', abi.encode(_params.pullFundsMinThreshold));
    _stabilityFeeTreasury.modifyParameters('surplusTransferDelay', abi.encode(_params.surplusTransferDelay));

    _checkParams(address(_stabilityFeeTreasury), abi.encode(_params));
  }

  function _setupPidController(
    IPIDController _pidController,
    IPIDController.PIDControllerParams memory _params,
    IPIDController.ControllerGains memory _gains
  ) internal {
    _pidController.modifyParameters('kp', abi.encode(_gains.kp));
    _pidController.modifyParameters('ki', abi.encode(_gains.ki));
    _pidController.modifyParameters('perSecondCumulativeLeak', abi.encode(_params.perSecondCumulativeLeak));
    _pidController.modifyParameters('integralPeriodSize', abi.encode(_params.integralPeriodSize));
    _pidController.modifyParameters('noiseBarrier', abi.encode(_params.noiseBarrier));
    _pidController.modifyParameters('feedbackOutputUpperBound', abi.encode(_params.feedbackOutputUpperBound));
    _pidController.modifyParameters('feedbackOutputLowerBound', abi.encode(_params.feedbackOutputLowerBound));

    _checkParams(address(_pidController), abi.encode(_params));

    IPIDController.ControllerGains memory _emptyGains;
    IPIDController.ControllerGains memory _storedGains = _pidController.controllerGains();
    require(keccak256(abi.encode(_storedGains)) == keccak256(abi.encode(_gains)));
    require(keccak256(abi.encode(_emptyGains)) != keccak256(abi.encode(_gains)));
  }

  function _setupPidRateSetter(
    IPIDRateSetter _pidRateSetter,
    IPIDRateSetter.PIDRateSetterParams memory _params
  ) internal {
    _pidRateSetter.modifyParameters('updateRateDelay', abi.encode(_params.updateRateDelay));

    _checkParams(address(_pidRateSetter), abi.encode(_params));
  }

  function _setupOracleRelayer(
    IOracleRelayer _oracleRelayer,
    IOracleRelayer.OracleRelayerParams memory _params
  ) internal {
    _oracleRelayer.modifyParameters('redemptionRateLowerBound', abi.encode(_params.redemptionRateLowerBound));
    _oracleRelayer.modifyParameters('redemptionRateUpperBound', abi.encode(_params.redemptionRateUpperBound));

    _checkParams(address(_oracleRelayer), abi.encode(_params));
  }

  function _setupOracleRelayerCollateral(
    bytes32 _cType,
    IOracleRelayer _oracleRelayer,
    IOracleRelayer.OracleRelayerCollateralParams memory _cParams
  ) internal {
    _oracleRelayer.modifyParameters(_cType, 'oracle', abi.encode(_cParams.oracle));
    _oracleRelayer.modifyParameters(_cType, 'safetyCRatio', abi.encode(_cParams.safetyCRatio));
    _oracleRelayer.modifyParameters(_cType, 'liquidationCRatio', abi.encode(_cParams.liquidationCRatio));

    _checkCParams(address(_oracleRelayer), _cType, abi.encode(_cParams));
  }

  function _setupGlobalSettlement(
    IGlobalSettlement _globalSettlement,
    IGlobalSettlement.GlobalSettlementParams memory _params
  ) internal {
    _globalSettlement.modifyParameters('shutdownCooldown', abi.encode(_params.shutdownCooldown));

    _checkParams(address(_globalSettlement), abi.encode(_params));
  }

  // --- Helper functions ---

  function _checkParams(address _modifiable, bytes memory _params) internal view {
    bytes memory _callData = abi.encodeWithSignature('params()');
    (, bytes memory _returnData) = _modifiable.staticcall(_callData);

    bytes memory _empty = new bytes(_params.length);

    require(keccak256(_params) != keccak256(_empty), 'Empty params');
    require(keccak256(_params) == keccak256(_returnData), 'Incomplete params');
  }

  function _checkCParams(address _modifiable, bytes32 _cType, bytes memory _cParams) internal view {
    bytes memory _callData = abi.encodeWithSignature('cParams(bytes32)', _cType);
    (, bytes memory _returnData) = _modifiable.staticcall(_callData);

    bytes memory _empty = new bytes(_cParams.length);

    require(keccak256(_cParams) != keccak256(_empty), 'Empty params');
    require(keccak256(_cParams) == keccak256(_returnData), 'Incomplete params');
  }
}

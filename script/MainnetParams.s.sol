// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Params.s.sol';

abstract contract MainnetParams is Contracts, Params {
  // --- Mainnet Params ---
  function _getEnvironmentParams() internal override {
    _safeEngineParams = ISAFEEngine.SAFEEngineParams({
      safeDebtCeiling: 3_000_000 * WAD, // WAD
      globalDebtCeiling: 0 // RAD
    });

    _accountingEngineParams = IAccountingEngine.AccountingEngineParams({
      surplusTransferPercentage: 0, // percent of surplus that is transfered
      surplusDelay: 1 days,
      popDebtDelay: 1 days,
      disableCooldown: 3 days,
      surplusAmount: 100 * RAD, // 100 COINs
      surplusBuffer: 1000 * RAD, // 1000 COINs
      debtAuctionMintedTokens: 1000 * WAD, // 1000 PROTOCOL TOKEN
      debtAuctionBidSize: 100 * RAD // 100 COINs
    });

    _debtAuctionHouseParams = IDebtAuctionHouse.DebtAuctionHouseParams({
      bidDecrease: 1.05e18, // -5 %
      amountSoldIncrease: 1.5e18, // +50 %
      bidDuration: 3 hours,
      totalAuctionLength: 2 days
    });

    _surplusAuctionHouseParams = ISurplusAuctionHouse.SurplusAuctionHouseParams({
      bidIncrease: 1.01e18, // +1 %
      bidDuration: 6 hours,
      totalAuctionLength: 1 days,
      bidReceiver: governor,
      recyclingPercentage: 0.5e18 // 50% is burned
    });

    _liquidationEngineParams = ILiquidationEngine.LiquidationEngineParams({
      onAuctionSystemCoinLimit: 100_000 * RAD, // 10_000 COINs
      saviourGasLimit: 10_000_000 // 10M gas
    });

    _stabilityFeeTreasuryParams = IStabilityFeeTreasury.StabilityFeeTreasuryParams({
      treasuryCapacity: 1_000_000 * RAD, // 1M COINs
      pullFundsMinThreshold: 0, // no threshold
      surplusTransferDelay: 1 days
    });

    _taxCollectorParams = ITaxCollector.TaxCollectorParams({
      primaryTaxReceiver: address(accountingEngine),
      globalStabilityFee: RAY, // no global SF
      maxStabilityFeeRange: RAY - MINUS_0_5_PERCENT_PER_HOUR, // +- 0.5% per hour
      maxSecondaryReceivers: 1 // stabilityFeeTreasury
    });

    _taxCollectorSecondaryTaxReceiver = ITaxCollector.TaxReceiver({
      receiver: address(stabilityFeeTreasury),
      canTakeBackTax: true, // [bool]
      taxPercentage: 0.5e18 // [wad%]
    });

    // --- PID Params ---

    _oracleRelayerParams = IOracleRelayer.OracleRelayerParams({
      redemptionRateUpperBound: RAY * WAD, // RAY
      redemptionRateLowerBound: 1 // RAY
    });

    _pidControllerParams = IPIDController.PIDControllerParams({
      perSecondCumulativeLeak: HALF_LIFE_30_DAYS, // 0.999998e27
      noiseBarrier: 0.995e18, // 0.5%
      feedbackOutputLowerBound: -int256(RAY - 1), // unbounded
      feedbackOutputUpperBound: RAD, // unbounded
      integralPeriodSize: 1 hours
    });

    _pidControllerGains = IPIDController.ControllerGains({kp: int256(PROPORTIONAL_GAIN), ki: int256(INTEGRAL_GAIN)});

    _pidRateSetterParams = IPIDRateSetter.PIDRateSetterParams({updateRateDelay: 1 hours});

    // --- Global Settlement Params ---
    _globalSettlementParams = IGlobalSettlement.GlobalSettlementParams({shutdownCooldown: 3 days});
    _postSettlementSAHParams = IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams({
      bidIncrease: 1.01e18, // +1 %
      bidDuration: 3 hours,
      totalAuctionLength: 1 days
    });

    // --- Collateral Default Params ---
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];

      _oracleRelayerCParams[_cType] = IOracleRelayer.OracleRelayerCollateralParams({
        oracle: delayedOracle[_cType],
        safetyCRatio: 1.25e27, // 125%
        liquidationCRatio: 1.2e27 // 120%
      });

      _taxCollectorCParams[_cType] = ITaxCollector.TaxCollectorCollateralParams({
        // NOTE: 5%/yr => 1.05^(1/yr) = 1 + 1.54713e-9
        stabilityFee: RAY + 6.27857e17 // RAY
      });

      _safeEngineCParams[_cType] = ISAFEEngine.SAFEEngineCollateralParams({
        debtCeiling: 10_000_000 * RAD, // 10M COINs
        debtFloor: 200 * RAD // 1 COIN
      });

      _liquidationEngineCParams[_cType] = ILiquidationEngine.LiquidationEngineCollateralParams({
        collateralAuctionHouse: address(collateralAuctionHouse[_cType]),
        liquidationPenalty: 1.05e18, // WAD
        liquidationQuantity: 100_000e45 // RAD
      });

      _collateralAuctionHouseParams[_cType] = ICollateralAuctionHouse.CollateralAuctionHouseParams({
        minimumBid: 100e18, // 5 COINs
        minDiscount: 1e18, // no discount
        maxDiscount: 0.9e18, // no discount
        perSecondDiscountUpdateRate: MINUS_0_5_PERCENT_PER_HOUR // RAY
      });
    }

    // --- Collateral Specific Params ---
    // ------------ WSTETH ------------
    _oracleRelayerCParams[WSTETH] = IOracleRelayer.OracleRelayerCollateralParams({
      oracle: delayedOracle[WSTETH],
      safetyCRatio: 1.25e27, // 125%
      liquidationCRatio: 1.2e27 // 120%
    });

    _safeEngineCParams[WSTETH] = ISAFEEngine.SAFEEngineCollateralParams({
      debtCeiling: 10_000_000 * RAD, // 10M
      debtFloor: 200 * RAD // 200
    });

    _taxCollectorCParams[WSTETH].stabilityFee = PLUS_1_85_PERCENT_PER_YEAR;

    _liquidationEngineCParams[WSTETH] = ILiquidationEngine.LiquidationEngineCollateralParams({
      collateralAuctionHouse: address(collateralAuctionHouse[WSTETH]),
      liquidationPenalty: 1.05e18, // 5%
      liquidationQuantity: 100_000 * RAD // 100k
    });

    _collateralAuctionHouseParams[WSTETH] = ICollateralAuctionHouse.CollateralAuctionHouseParams({
      minimumBid: 100 * WAD, // 100
      minDiscount: 1e18, // no discount
      maxDiscount: 0.9e18, // -10%
      perSecondDiscountUpdateRate: 0.99998575212e27 // -5%/hr
    });

    // ------------ RETH ------------
    _oracleRelayerCParams[RETH] = IOracleRelayer.OracleRelayerCollateralParams({
      oracle: delayedOracle[RETH],
      safetyCRatio: 1.25e27, // 125%
      liquidationCRatio: 1.2e27 // 120%
    });

    _safeEngineCParams[RETH] = ISAFEEngine.SAFEEngineCollateralParams({
      debtCeiling: 10_000_000 * RAD, // 10M
      debtFloor: 200 * RAD // 200
    });

    _taxCollectorCParams[RETH].stabilityFee = PLUS_1_75_PERCENT_PER_YEAR;

    _liquidationEngineCParams[RETH] = ILiquidationEngine.LiquidationEngineCollateralParams({
      collateralAuctionHouse: address(collateralAuctionHouse[RETH]),
      liquidationPenalty: 1.05e18, // 5%
      liquidationQuantity: 100_000 * RAD // 100k
    });

    _collateralAuctionHouseParams[RETH] = ICollateralAuctionHouse.CollateralAuctionHouseParams({
      minimumBid: 100 * WAD, // 100
      minDiscount: 1e18, // no discount
      maxDiscount: 0.9e18, // -10%
      perSecondDiscountUpdateRate: 0.99998575212e27 // -5%/hr
    });

    // ------------ ARB ------------
    _oracleRelayerCParams[ARB] = IOracleRelayer.OracleRelayerCollateralParams({
      oracle: delayedOracle[ARB],
      safetyCRatio: 1.85e27, // 185%
      liquidationCRatio: 1.75e27 // 120%
    });

    _safeEngineCParams[ARB] = ISAFEEngine.SAFEEngineCollateralParams({
      debtCeiling: 5_000_000 * RAD, // 5M
      debtFloor: 200 * RAD // 200
    });

    _taxCollectorCParams[ARB].stabilityFee = PLUS_5_PERCENT_PER_YEAR;

    _liquidationEngineCParams[ARB] = ILiquidationEngine.LiquidationEngineCollateralParams({
      collateralAuctionHouse: address(collateralAuctionHouse[ARB]),
      liquidationPenalty: 1.1e18, // 10%
      liquidationQuantity: 100_000 * RAD // 100k
    });

    _collateralAuctionHouseParams[ARB] = ICollateralAuctionHouse.CollateralAuctionHouseParams({
      minimumBid: 100 * WAD, // 100
      minDiscount: 1e18, // no discount
      maxDiscount: 0.9e18, // -10%
      perSecondDiscountUpdateRate: 0.99998575212e27 // -5%/hr
    });
  }
}

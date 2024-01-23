// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Params.s.sol';

abstract contract SepoliaParams is Contracts, Params {
  // --- Testnet Params ---
  uint256 constant GOERLI_ARB_ETH_PRICE_FEED = 0.001e18; // 1000 OP = 1 ETH
  uint256 constant GOERLI_ARB_PRICE_DEVIATION = 0.995e18; // -0.5%

  function _getEnvironmentParams() internal override {
    // Setup delegated collateral joins
    delegatee[ARB] = governor;

    _safeEngineParams = ISAFEEngine.SAFEEngineParams({
      safeDebtCeiling: 2_000_000 * WAD, // 2M COINs
      globalDebtCeiling: 25_000_000 * RAD // 25M COINs
    });

    _accountingEngineParams = IAccountingEngine.AccountingEngineParams({
      surplusTransferPercentage: 0, // percent of surplus that is transfered
      surplusDelay: 1800,
      popDebtDelay: 1800,
      disableCooldown: 3 days,
      surplusAmount: 100 * RAD, // 100 COINs
      surplusBuffer: 1000 * RAD, // 1000 COINs
      debtAuctionMintedTokens: 1e18, // 1 PROTOCOL TOKEN
      debtAuctionBidSize: 100 * RAD // 100 COINs
    });

    _debtAuctionHouseParams = IDebtAuctionHouse.DebtAuctionHouseParams({
      bidDecrease: 1.05e18, // - 5%
      amountSoldIncrease: 1.05e18, // + 5%
      bidDuration: 900, // 15 minutes
      totalAuctionLength: 1800 // 30 minutes
    });

    _surplusAuctionHouseParams = ISurplusAuctionHouse.SurplusAuctionHouseParams({
      bidIncrease: 1.01e18, // +1 %
      bidDuration: 900, // 15 minutes
      totalAuctionLength: 1800, // 30 minutes
      bidReceiver: governor,
      recyclingPercentage: 50 // 100% - recyclingPercentage is burned
    });

    _liquidationEngineParams = ILiquidationEngine.LiquidationEngineParams({
      onAuctionSystemCoinLimit: 500_000 * RAD, // 500k COINs
      saviourGasLimit: 10_000_000 // 10M gas
    });

    _stabilityFeeTreasuryParams = IStabilityFeeTreasury.StabilityFeeTreasuryParams({
      treasuryCapacity: 1_000_000e45, // 1M COINs
      pullFundsMinThreshold: 0, // no threshold
      surplusTransferDelay: 1 days
    });

    _taxCollectorParams = ITaxCollector.TaxCollectorParams({
      primaryTaxReceiver: address(accountingEngine),
      globalStabilityFee: RAY, // no global SF
      maxStabilityFeeRange: RAY - MINUS_0_5_PERCENT_PER_HOUR, // +- 0.5% per hour
      maxSecondaryReceivers: 1
    });

    _taxCollectorSecondaryTaxReceiver = ITaxCollector.TaxReceiver({
      receiver: address(stabilityFeeTreasury),
      canTakeBackTax: true, // can take back tax
      taxPercentage: 0.5e18 // 50%
    });

    // --- PID Params ---

    _oracleRelayerParams = IOracleRelayer.OracleRelayerParams({
      redemptionRateUpperBound: RAY * WAD, // unbounded
      redemptionRateLowerBound: 1 // unbounded
    });

    _pidControllerParams = IPIDController.PIDControllerParams({
      perSecondCumulativeLeak: HALF_LIFE_30_DAYS, // 0.999998e27
      noiseBarrier: WAD, // no noise barrier
      feedbackOutputLowerBound: -int256(RAY - 1), // unbounded
      feedbackOutputUpperBound: RAD, // unbounded
      integralPeriodSize: 1 hours
    });

    _pidControllerGains = IPIDController.ControllerGains({
      kp: int256(PROPORTIONAL_GAIN), // imported from RAI
      ki: int256(INTEGRAL_GAIN) // imported from RAI
    });

    _pidRateSetterParams = IPIDRateSetter.PIDRateSetterParams({updateRateDelay: 1 hours});

    // --- Global Settlement Params ---
    _globalSettlementParams = IGlobalSettlement.GlobalSettlementParams({shutdownCooldown: 3 days});
    _postSettlementSAHParams = IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams({
      bidIncrease: 1.01e18, // +1 %
      bidDuration: 900, // 15 minutes
      totalAuctionLength: 1800 // 30 minutes
    });

    // --- Collateral Default Params ---
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];

      _oracleRelayerCParams[_cType] = IOracleRelayer.OracleRelayerCollateralParams({
        oracle: delayedOracle[_cType],
        safetyCRatio: 1.5e27, // 150%
        liquidationCRatio: 1.5e27 // 150%
      });

      _taxCollectorCParams[_cType] = ITaxCollector.TaxCollectorCollateralParams({
        // NOTE: 42%/yr => 1.42^(1/yr) = 1 + 11,11926e-9
        stabilityFee: RAY + 11.11926e18 // + 42%/yr
      });

      _safeEngineCParams[_cType] = ISAFEEngine.SAFEEngineCollateralParams({
        debtCeiling: 10_000_000 * RAD, // 10M COINs
        debtFloor: 1 * RAD // 1 COINs
      });

      _liquidationEngineCParams[_cType] = ILiquidationEngine.LiquidationEngineCollateralParams({
        collateralAuctionHouse: address(collateralAuctionHouse[_cType]),
        liquidationPenalty: 1.1e18, // 10%
        liquidationQuantity: 1000 * RAD // 1000 COINs
      });

      _collateralAuctionHouseParams[_cType] = ICollateralAuctionHouse.CollateralAuctionHouseParams({
        minimumBid: WAD, // 1 COINs
        minDiscount: WAD, // no discount
        maxDiscount: 0.9e18, // -10%
        perSecondDiscountUpdateRate: MINUS_0_5_PERCENT_PER_HOUR // RAY
      });
    }

    // --- Collateral Specific Params ---
    _oracleRelayerCParams[WSTETH].safetyCRatio = 1.35e27; // 135%
    _oracleRelayerCParams[WSTETH].liquidationCRatio = 1.35e27; // 135%
    _taxCollectorCParams[WSTETH].stabilityFee = RAY + 1.54713e18; // + 5%/yr
    _safeEngineCParams[WSTETH].debtCeiling = 100_000_000 * RAD; // 100M COINs

    _liquidationEngineCParams[ARB].liquidationPenalty = 1.2e18; // 20%
    _collateralAuctionHouseParams[ARB].maxDiscount = 0.5e18; // -50%
  }
}

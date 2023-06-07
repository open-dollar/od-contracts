// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Params.s.sol';

abstract contract GoerliParams is Params, Contracts {
  // --- Testnet Params ---
  uint256 constant OP_GOERLI_OP_ETH_PRICE_FEED = 0.001e18;

  function _getEnvironmentParams() internal override {
    _safeEngineParams = ISAFEEngine.SAFEEngineParams({
      safeDebtCeiling: 10_000_000 * WAD, // 10M COINs
      globalDebtCeiling: 10_000_000_000 * RAD // 10B COINs
    });

    _accountingEngineParams = IAccountingEngine.AccountingEngineParams({
      surplusIsTransferred: 0, // surplus is auctioned
      surplusDelay: 1 days,
      popDebtDelay: 1 days,
      disableCooldown: 3 days,
      surplusAmount: 100 * RAD, // 100 COINs
      surplusBuffer: 1000 * RAD, // 1000 COINs
      debtAuctionMintedTokens: 1e18, // 1 PROTOCOL TOKEN
      debtAuctionBidSize: 100 * RAD // 100 COINs
    });

    _debtAuctionHouseParams = IDebtAuctionHouse.DebtAuctionHouseParams({
      bidDecrease: 1.05e18, // - 5%
      amountSoldIncrease: 1.05e18, // + 5%
      bidDuration: 3 hours,
      totalAuctionLength: 2 days
    });

    _surplusAuctionHouseParams = ISurplusAuctionHouse.SurplusAuctionHouseParams({
      bidIncrease: 1.01e18, // +1 %
      bidDuration: 1 hours,
      totalAuctionLength: 1 days,
      recyclingPercentage: 0 // 100% is burned
    });

    _collateralAuctionHouseSystemCoinParams = ICollateralAuctionHouse.CollateralAuctionHouseSystemCoinParams({
      lowerSystemCoinDeviation: WAD, // 0% deviation
      upperSystemCoinDeviation: WAD, // 0% deviation
      minSystemCoinDeviation: 0.999e18 // 0.1% deviation
    });

    _liquidationEngineParams = ILiquidationEngine.LiquidationEngineParams({
      onAuctionSystemCoinLimit: 10_000 * RAD // 10_000 COINs
    });

    _stabilityFeeTreasuryParams = IStabilityFeeTreasury.StabilityFeeTreasuryParams({
      expensesMultiplier: 100, // no multiplier
      treasuryCapacity: 1_000_000e45, // 1M COINs
      minFundsRequired: 10_000e45, // 10_000 COINs
      pullFundsMinThreshold: 0, // no threshold
      surplusTransferDelay: 1 days
    });

    _taxCollectorParams = ITaxCollector.TaxCollectorParams({
      primaryTaxReceiver: address(accountingEngine),
      globalStabilityFee: 0, // no global SF
      maxSecondaryReceivers: 1
    });

    _taxCollectorSecondaryTaxReceiver = ITaxCollector.TaxReceiver({
      receiver: address(stabilityFeeTreasury),
      canTakeBackTax: true, // can take back tax
      taxPercentage: 50e27 // 50%
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

    // --- Collaterals Params ---

    _oracleRelayerCParams[WETH] = IOracleRelayer.OracleRelayerCollateralParams({
      oracle: oracle[WETH],
      safetyCRatio: 1.35e27, // 135%
      liquidationCRatio: 1.35e27 // 135%
    });

    _oracleRelayerCParams[OP] = IOracleRelayer.OracleRelayerCollateralParams({
      oracle: oracle[OP],
      safetyCRatio: 1.5e27, // 150%
      liquidationCRatio: 1.5e27 // 150%
    });

    _taxCollectorCParams[WETH] = ITaxCollector.TaxCollectorCollateralParams({
      // NOTE: 5%/yr => 1.05^(1/yr) = 1 + 1.54713e-9
      stabilityFee: RAY + 1.54713e18 // + 5%/yr
    });

    _taxCollectorCParams[OP] = ITaxCollector.TaxCollectorCollateralParams({
      // NOTE: 42%/yr => 1.42^(1/yr) = 1 + 11,11926e-9
      stabilityFee: RAY + 11.11926e18 // + 42%/yr
    });

    _safeEngineCParams[WETH] = ISAFEEngine.SAFEEngineCollateralParams({
      debtCeiling: 100_000_000 * RAD, // 100M COINs
      debtFloor: 1 * RAD // 1 COINS
    });

    _safeEngineCParams[OP] = ISAFEEngine.SAFEEngineCollateralParams({
      debtCeiling: 10_000_000 * RAD, // 10M COINs
      debtFloor: 1 * RAD // 1 COINs
    });

    _liquidationEngineCParams[WETH] = ILiquidationEngine.LiquidationEngineCollateralParams({
      collateralAuctionHouse: address(collateralAuctionHouse[WETH]),
      liquidationPenalty: 1.1e18, // 10%
      liquidationQuantity: 1000 * RAD // 1000 COINs
    });

    _liquidationEngineCParams[OP] = ILiquidationEngine.LiquidationEngineCollateralParams({
      collateralAuctionHouse: address(collateralAuctionHouse[OP]),
      liquidationPenalty: 1.2e18, // 20%
      liquidationQuantity: 1000 * RAD // 1000 COINs
    });

    _collateralAuctionHouseCParams[WETH] = ICollateralAuctionHouse.CollateralAuctionHouseParams({
      minimumBid: WAD, // 1 COINs
      minDiscount: WAD, // no discount
      maxDiscount: 0.9e18, // -10%
      perSecondDiscountUpdateRate: MINUS_0_5_PERCENT_PER_HOUR, // RAY
      lowerCollateralDeviation: 0.99e18, // -1%
      upperCollateralDeviation: 0.99e18 // +1%
    });

    _collateralAuctionHouseCParams[OP] = ICollateralAuctionHouse.CollateralAuctionHouseParams({
      minimumBid: WAD, // 1 COINs
      minDiscount: WAD, // no discount
      maxDiscount: 0.5e18, // -50%
      perSecondDiscountUpdateRate: MINUS_0_5_PERCENT_PER_HOUR, // -1%/hr
      lowerCollateralDeviation: 0.99e18, // -1%
      upperCollateralDeviation: 0.99e18 // +1%
    });

    // --- Global Settlement Params ---

    _globalSettlementParams = IGlobalSettlement.GlobalSettlementParams({shutdownCooldown: 3 days});
  }
}

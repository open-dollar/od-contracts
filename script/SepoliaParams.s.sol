// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Params.s.sol';

abstract contract SepoliaParams is Contracts, Params {
  // --- Testnet Params ---
  uint256 constant GOERLI_ARB_ETH_PRICE_FEED = 0.001e18; // 1000 OP = 1 ETH
  uint256 constant GOERLI_ARB_PRICE_DEVIATION = 0.995e18; // -0.5%

  function _getEnvironmentParams() internal override {
    // Setup delegated collateral joins
    delegatee[ARB] = tlcGov;

    _safeEngineParams = ISAFEEngine.SAFEEngineParams({
      safeDebtCeiling: 10_000_000 * WAD, // WAD
      globalDebtCeiling: 25_000_000 * RAD // RAD
    });

    _accountingEngineParams = IAccountingEngine.AccountingEngineParams({
      surplusTransferPercentage: 0, // percent of surplus that is transfered
      surplusDelay: 1 days,
      popDebtDelay: 1 days,
      disableCooldown: 3 days,
      surplusAmount: 100e45, // 100 COINs
      surplusBuffer: 1000e45, // 1000 COINs
      debtAuctionMintedTokens: 1e18, // 1 PROTOCOL TOKEN
      debtAuctionBidSize: 100e45 // 100 COINs
    });

    _debtAuctionHouseParams = IDebtAuctionHouse.DebtAuctionHouseParams({
      bidDecrease: 1.05e18, // -5 %
      amountSoldIncrease: 1.5e18, // +50 %
      bidDuration: 3 hours,
      totalAuctionLength: 2 days
    });

    _surplusAuctionHouseParams = ISurplusAuctionHouse.SurplusAuctionHouseParams({
      bidIncrease: 1.01e18, // +1 %
      bidDuration: 1 hours,
      totalAuctionLength: 1 days,
      bidReceiver: tlcGov,
      recyclingPercentage: 0.5e18 // 50% is burned
    });

    _liquidationEngineParams = ILiquidationEngine.LiquidationEngineParams({
      onAuctionSystemCoinLimit: 10_000 * RAD, // 10_000 COINs
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
      bidDuration: 3 hours,
      totalAuctionLength: 2 days
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
        minimumBid: 5e18, // 5 COINs
        minDiscount: 1e18, // no discount
        maxDiscount: 1e18, // no discount
        perSecondDiscountUpdateRate: MINUS_0_5_PERCENT_PER_HOUR // RAY
      });
    }

    // --- Collateral Specific Params ---
    _taxCollectorCParams[WSTETH].stabilityFee = RAY + 11.11926e18; // + 42%/yr
    _safeEngineCParams[WSTETH].debtFloor = 5000 * RAD; // 5_000 COINs
    _liquidationEngineCParams[WSTETH].liquidationPenalty = 1.15e18; // WAD
    _oracleRelayerCParams[ARB].safetyCRatio = 1.4e27;
    _oracleRelayerCParams[ARB].liquidationCRatio = 1.35e27;
  }
}

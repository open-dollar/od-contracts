// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Params.s.sol';

bytes32 constant TKN = bytes32('TKN');
uint256 constant TEST_ETH_PRICE = 1000e18; // 1 ETH = 1000 HAI
uint256 constant TEST_TKN_PRICE = 1e18; // 1 TKN = 1 HAI

uint256 constant INITIAL_DEBT_AUCTION_MINTED_TOKENS = 1e18;
uint256 constant ONE_HUNDRED_COINS = 100e45;
uint256 constant PERCENTAGE_OF_STABILITY_FEE_TO_TREASURY = 50e27;

address constant SURPLUS_AUCTION_BID_RECEIVER = address(420);

abstract contract TestParams is Contracts, Params {
  // --- ForTest Params ---

  function _getEnvironmentParams() internal override {
    _safeEngineParams = ISAFEEngine.SAFEEngineParams({
      safeDebtCeiling: type(uint256).max, // WAD
      globalDebtCeiling: type(uint256).max // RAD
    });

    _accountingEngineParams = IAccountingEngine.AccountingEngineParams({
      surplusIsTransferred: 0, // surplus is auctioned
      surplusDelay: 0, // no delay
      popDebtDelay: 0, // no delay
      disableCooldown: 0, // no cooldown
      surplusAmount: ONE_HUNDRED_COINS, // 100 COINs
      surplusBuffer: 0, // no buffer
      debtAuctionMintedTokens: INITIAL_DEBT_AUCTION_MINTED_TOKENS, // 1 PROTOCOL TOKEN
      debtAuctionBidSize: ONE_HUNDRED_COINS // 100 COINs
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
      bidReceiver: SURPLUS_AUCTION_BID_RECEIVER,
      recyclingPercentage: 0.5e18 // 50% is burned
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
      minFundsRequired: 0, // no min
      pullFundsMinThreshold: 0, // no threshold
      surplusTransferDelay: 1 days
    });

    _taxCollectorParams = ITaxCollector.TaxCollectorParams({
      primaryTaxReceiver: address(accountingEngine),
      globalStabilityFee: 0, // no global SF
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
      perSecondCumulativeLeak: MINUS_1_PERCENT_PER_HOUR, // RAD
      noiseBarrier: WAD, // no noise barrier
      feedbackOutputLowerBound: -int256(RAY - 1), // unbounded
      feedbackOutputUpperBound: RAD, // unbounded
      integralPeriodSize: 1 hours
    });

    _pidControllerGains = IPIDController.ControllerGains({
      kp: 1e18, // WAD
      ki: 1e18 // WAD
    });

    _pidRateSetterParams = IPIDRateSetter.PIDRateSetterParams({updateRateDelay: 1 days});

    // --- Collateral Params ---
    // NOTE: all collateral types have the same params in test environment
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];

      _oracleRelayerCParams[_cType] = IOracleRelayer.OracleRelayerCollateralParams({
        oracle: delayedOracle[_cType],
        safetyCRatio: 1.35e27, // 135%
        liquidationCRatio: 1.35e27 // 135%
      });

      _taxCollectorCParams[_cType] = ITaxCollector.TaxCollectorCollateralParams({
        // NOTE: 5%/yr => 1.05^(1/yr) = 1 + 1.54713e-9
        stabilityFee: RAY + 1.54713e18 // RAY
      });

      _safeEngineCParams[_cType] = ISAFEEngine.SAFEEngineCollateralParams({
        debtCeiling: 1_000_000_000 * RAD, // RAD
        debtFloor: 0 // RAD
      });

      _liquidationEngineCParams[_cType] = ILiquidationEngine.LiquidationEngineCollateralParams({
        collateralAuctionHouse: address(collateralAuctionHouse[_cType]),
        liquidationPenalty: 1.1e18, // WAD
        liquidationQuantity: 100_000e45 // RAD
      });

      _collateralAuctionHouseCParams[_cType] = ICollateralAuctionHouse.CollateralAuctionHouseParams({
        minimumBid: 0, // no min
        minDiscount: WAD, // no discount
        maxDiscount: 0.9e18, // -10%
        perSecondDiscountUpdateRate: MINUS_0_5_PERCENT_PER_HOUR, // RAY
        lowerCollateralDeviation: 0.99e18, // -1%
        upperCollateralDeviation: 0.99e18 // 1%
      });
    }

    // --- Global Settlement Params ---

    _globalSettlementParams = IGlobalSettlement.GlobalSettlementParams({shutdownCooldown: 3 days});
  }
}

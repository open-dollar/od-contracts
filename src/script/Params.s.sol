// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

struct CollateralParams {
  bytes32 name;
  uint256 /* wad */ liquidationPenalty;
  uint256 /* rad */ liquidationQuantity;
  uint256 /* rad */ debtCeiling;
  uint256 /* ray */ safetyCRatio;
  uint256 /* ray */ liquidationRatio;
  uint256 /* ray */ stabilityFee;
}

struct GlobalParams {
  uint256 /* wad */ initialDebtAuctionMintedTokens;
  uint256 /* wad */ bidAuctionSize;
  uint256 /* wad */ surplusAuctionAmountToSell;
  uint256 /* rad */ globalDebtCeiling;
  uint256 /* ray */ globalStabilityFee;
  address surplusAuctionBidReceiver;
  uint256 surplusAuctionRecyclingPercentage;
}

struct PIDParams {
  int256 /*  wad */ proportionalGain;
  int256 /*  wad */ integralGain;
  uint256 /* wad */ noiseBarrier;
  uint256 /* ray */ perSecondCumulativeLeak;
  int256 /*  ray */ feedbackOutputLowerBound;
  uint256 /* ray */ feedbackOutputUpperBound;
  uint256 periodSize;
  uint256 updateRate;
}

// Global Params
uint256 constant INITIAL_DEBT_AUCTION_MINTED_TOKENS = 1e18;
uint256 constant BID_AUCTION_SIZE = 100e18;
uint256 constant SURPLUS_AUCTION_SIZE = 100e45;
address constant SURPLUS_AUCTION_BID_RECEIVER = address(420); // address that receives protocol tokens
uint256 constant SURPLUS_AUCTION_RECYCLING_PERCENTAGE = 50;
uint256 constant GLOBAL_DEBT_CEILING = type(uint256).max;
uint256 constant GLOBAL_STABILITY_FEE = 1e27;

// HAI Params
bytes32 constant HAI = bytes32('HAI');
uint256 constant HAI_INITIAL_PRICE = 1e18; // 1 HAI = 1 USD

// PID Params
int256 constant PID_INTEGRAL_GAIN = 1e18;
int256 constant PID_PROPORTIONAL_GAIN = 1e18;
uint256 constant PID_PER_SECOND_CUMULATIVE_LEAK = 999_997_208_243_937_652_252_849_536; // 1% per hour
uint256 constant PID_NOISE_BARRIER = 1e18;
uint256 constant PID_FEEDBACK_OUTPUT_UPPER_BOUND = 1e45; // unbounded
int256 constant PID_FEEDBACK_OUTPUT_LOWER_BOUND = -int256(1e27 - 1); // unbounded
uint256 constant PID_PERIOD_SIZE = 1 hours;
uint256 constant PID_UPDATE_RATE = 1 days;

// ETH Collateral Params
bytes32 constant ETH_A = bytes32('ETH-A');
uint256 constant ETH_A_LIQUIDATION_PENALTY = 1.1e18;
uint256 constant ETH_A_LIQUIDATION_QUANTITY = 100_000e45;
uint256 constant ETH_A_DEBT_CEILING = 100_000_000e45;
uint256 constant ETH_A_SAFETY_C_RATIO = 1.35e27;
uint256 constant ETH_A_LIQUIDATION_RATIO = 1.35e27;
// NOTE: 5%/yr => 1.05^(1/365) = 1 + 1.54713e-9
uint256 constant ETH_A_STABILITY_FEE = 1.54713e18; // 5%/yr
uint256 constant TEST_ETH_A_SF_APR = 1.05e18; // 5%/yr
uint256 constant TEST_ETH_PRICE = 1000e18; // 1 ETH = 1000 HAI

// TKN Collateral Params
bytes32 constant TKN = bytes32('TKN');
uint256 constant TKN_LIQUIDATION_PENALTY = 1.1e18;
uint256 constant TKN_LIQUIDATION_QUANTITY = 100_000e45;
uint256 constant TKN_DEBT_CEILING = 100_000_000e45;
uint256 constant TKN_SAFETY_C_RATIO = 1.35e27;
uint256 constant TKN_LIQUIDATION_RATIO = 1.35e27;
uint256 constant TKN_STABILITY_FEE = 0;
uint256 constant TEST_TKN_PRICE = 1e18; // 1 TKN = 1 HAI

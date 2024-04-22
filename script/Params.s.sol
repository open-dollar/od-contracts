// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

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
  IPostSettlementSurplusAuctionHouse,
  IModifiable
} from '@script/Contracts.s.sol';

import {WAD, RAY, RAD} from '@libraries/Math.sol';

// --- Utils ---

// to replace ARB voting token
bytes32 constant ARB = bytes32('ARB'); // 0x4152420000000000000000000000000000000000000000000000000000000000

// OD Params
bytes32 constant OD = bytes32('OD'); // 0x4f44000000000000000000000000000000000000000000000000000000000000
uint256 constant OD_INITIAL_PRICE = 1e18; // 1 OD = 1 USD

// Collateral Names
bytes32 constant WETH = bytes32('WETH'); // 0x5745544800000000000000000000000000000000000000000000000000000000
bytes32 constant ETH_A = bytes32('ETH-A'); // 0x4554482d41000000000000000000000000000000000000000000000000000000
bytes32 constant WSTETH = bytes32('WSTETH'); // 0x5753544554480000000000000000000000000000000000000000000000000000
bytes32 constant CBETH = bytes32('CBETH'); // 0x4342455448000000000000000000000000000000000000000000000000000000
bytes32 constant RETH = bytes32('RETH'); // 0x5245544800000000000000000000000000000000000000000000000000000000

uint256 constant MINUS_0_5_PERCENT_PER_HOUR = 999_998_607_628_240_588_157_433_861;
uint256 constant MINUS_1_PERCENT_PER_HOUR = 999_997_208_243_937_652_252_849_536;
uint256 constant HALF_LIFE_30_DAYS = 999_999_711_200_000_000_000_000_000;

uint256 constant PLUS_1_5_PERCENT_PER_YEAR = 1_000_000_000_472_114_805_215_157_978;
uint256 constant PLUS_1_75_PERCENT_PER_YEAR = 1_000_000_000_550_051_944_812_439_051;
uint256 constant PLUS_1_85_PERCENT_PER_YEAR = 1_000_000_000_581_197_104_947_698_371;
uint256 constant PLUS_2_PERCENT_PER_YEAR = 1_000_000_000_627_937_192_491_029_810;
uint256 constant PLUS_5_PERCENT_PER_YEAR = 1_000_000_001_547_125_957_863_212_448;

uint256 constant PROPORTIONAL_GAIN = 111_001_102_931;
uint256 constant INTEGRAL_GAIN = 32_884;

// Job Params
uint256 constant JOB_REWARD = 0.2e18; // 0.2 OD

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
  mapping(bytes32 => ICollateralAuctionHouse.CollateralAuctionHouseParams) _collateralAuctionHouseParams;

  IStabilityFeeTreasury.StabilityFeeTreasuryParams _stabilityFeeTreasuryParams;
  ITaxCollector.TaxCollectorParams _taxCollectorParams;
  mapping(bytes32 => ITaxCollector.TaxCollectorCollateralParams) _taxCollectorCParams;
  ITaxCollector.TaxReceiver _taxCollectorSecondaryTaxReceiver;

  IGlobalSettlement.GlobalSettlementParams _globalSettlementParams;
  IPostSettlementSurplusAuctionHouse.PostSettlementSAHParams _postSettlementSAHParams;
}

/**
 * @title ParamChecker
 * @notice This library sets the parameters of the contracts, one by one, ensuring that they're set fully and correctly.
 */
library ParamChecker {
  // --- Helper functions ---

  function _checkParams(address _modifiable, bytes memory _params) internal view {
    bytes memory _callData = abi.encodeWithSignature('params()');
    (, bytes memory _returnData) = _modifiable.staticcall(_callData);

    bytes memory _empty = new bytes(_params.length);

    require(keccak256(_params) != keccak256(_empty), 'Empty params');
    require(keccak256(_params) == keccak256(_returnData), 'Incorrect params');
  }

  function _checkCParams(address _modifiable, bytes32 _cType, bytes memory _cParams) internal view {
    bytes memory _callData = abi.encodeWithSignature('cParams(bytes32)', _cType);
    (, bytes memory _returnData) = _modifiable.staticcall(_callData);

    bytes memory _empty = new bytes(_cParams.length);

    require(keccak256(_cParams) != keccak256(_empty), 'Empty params');
    require(keccak256(_cParams) == keccak256(_returnData), 'Incorrect params');
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';

import {ChainlinkRelayer, IBaseOracle} from '@contracts/oracles/ChainlinkRelayer.sol';
import {UniV3Relayer} from '@contracts/oracles/UniV3Relayer.sol';

import {DenominatedOracle, IDenominatedOracle} from '@contracts/oracles/DenominatedOracle.sol';
import {DelayedOracle, IDelayedOracle} from '@contracts/oracles/DelayedOracle.sol';

import {
  OP_CHAINLINK_ETH_USD_FEED,
  OP_CHAINLINK_WSTETH_ETH_FEED,
  OP_CHAINLINK_SEQUENCER_UPTIME_FEED,
  OP_WETH,
  OP_WBTC
} from '@script/Registry.s.sol';

import {Math, WAD} from '@libraries/Math.sol';

contract OracleSetup is HaiTest {
  using Math for uint256;

  uint256 FORK_BLOCK = 99_000_000;

  uint256 CHAINLINK_ETH_USD_PRICE = 181_865_000_000;
  uint256 CHAINLINK_ETH_USD_PRICE_18_DECIMALS = 1_818_650_000_000_000_000_000;

  uint256 NEW_ETH_USD_PRICE = 200_000_000_000;
  uint256 NEW_ETH_USD_PRICE_18_DECIMALS = 2_000_000_000_000_000_000_000;

  uint256 CHAINLINK_WSTETH_ETH_PRICE = 1_124_766_090_043_756_600; // NOTE: 18 decimals
  uint256 WSTETH_USD_PRICE = CHAINLINK_WSTETH_ETH_PRICE.wmul(CHAINLINK_ETH_USD_PRICE_18_DECIMALS);

  uint24 FEE_TIER = 500;

  uint256 WBTC_ETH_PRICE = 14_864_307_223_256_388_569; // 1 BTC = 14.8 ETH
  uint256 WBTC_USD_PRICE = 27_032_972_331_575_231_071_011; // 1 BTC = 27,032 USD

  IBaseOracle public wethUsdPriceSource;
  IBaseOracle public wstethEthPriceSource;
  IBaseOracle public wbtcWethPriceSource;

  IDenominatedOracle public wstethUsdPriceSource;
  IDenominatedOracle public wbtcUsdPriceSource;

  IDelayedOracle public wethUsdDelayedOracle;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);

    // --- Chainlink ---
    wethUsdPriceSource = new ChainlinkRelayer(OP_CHAINLINK_ETH_USD_FEED, OP_CHAINLINK_SEQUENCER_UPTIME_FEED, 1 days);
    wstethEthPriceSource =
      new ChainlinkRelayer(OP_CHAINLINK_WSTETH_ETH_FEED, OP_CHAINLINK_SEQUENCER_UPTIME_FEED, 1 days);

    // --- UniV3 ---
    wbtcWethPriceSource = new UniV3Relayer(OP_WBTC, OP_WETH, FEE_TIER, 1 days);

    // --- Denominated ---
    wstethUsdPriceSource = new DenominatedOracle(wstethEthPriceSource, wethUsdPriceSource, false);
    wbtcUsdPriceSource = new DenominatedOracle(wbtcWethPriceSource, wethUsdPriceSource, false);

    // --- Delayed ---
    wethUsdDelayedOracle = new DelayedOracle(wethUsdPriceSource, 1 hours);
  }

  function test_OptimismFork() public {
    assertEq(block.number, FORK_BLOCK);
  }

  // --- Chainlink ---

  function test_ChainlinkOracle() public {
    assertEq(IChainlinkOracle(OP_CHAINLINK_ETH_USD_FEED).latestAnswer(), int256(CHAINLINK_ETH_USD_PRICE));
  }

  function test_ChainlinkRelayer() public {
    assertEq(CHAINLINK_ETH_USD_PRICE_18_DECIMALS / 1e18, 1818);
    assertEq(wethUsdPriceSource.read(), CHAINLINK_ETH_USD_PRICE_18_DECIMALS);
  }

  function test_ChainlinkRelayerStalePrice() public {
    vm.warp(block.timestamp + 1 days);
    vm.expectRevert();

    wethUsdPriceSource.read();
  }

  function test_ChainlinkRelayerSymbol() public {
    assertEq(wethUsdPriceSource.symbol(), 'ETH / USD');
  }

  // --- UniV3 ---

  function test_UniV3Relayer() public {
    assertEq(wbtcWethPriceSource.read(), WBTC_ETH_PRICE);
  }

  function test_UniV3RelayerSymbol() public {
    assertEq(wbtcWethPriceSource.symbol(), 'WBTC / WETH');
  }

  // --- Denominated ---

  /**
   * NOTE: deployer needs to check that the symbols of the two oracles
   *       concatenate in the right order, e.g WSTETH/ETH - ETH/USD
   */
  function test_DenominatedOracle() public {
    assertEq(WSTETH_USD_PRICE / 1e18, 2045); // 1818.65 * 1.1247 = 2045
    assertEq(wstethUsdPriceSource.read(), WSTETH_USD_PRICE);
  }

  function test_DenominatedOracleUniV3() public {
    assertEq(WBTC_USD_PRICE / 1e18, 27_032); // 14.864 * 1818.65 = 27032
    assertEq(wbtcUsdPriceSource.read(), WBTC_USD_PRICE);
  }

  function test_DenominatedOracleSymbol() public {
    assertEq(wstethUsdPriceSource.symbol(), '(WSTETH / ETH) * (ETH / USD)');
  }

  /**
   * NOTE: In this case, the symbols are ETH/USD - ETH/USD
   *       Using inverted = true, the resulting symbols are USD/ETH - ETH/USD
   */
  function test_DenominatedOracleInverted() public {
    IDenominatedOracle usdPriceSource = new DenominatedOracle(wethUsdPriceSource, wethUsdPriceSource, true);

    assertApproxEqAbs(usdPriceSource.read(), WAD, 1e9); // 1 USD = 1 USD (with 18 decimals)
  }

  function test_DenominatedOracleInvertedSymbol() public {
    IDenominatedOracle usdPriceSource = new DenominatedOracle(wethUsdPriceSource, wethUsdPriceSource, true);

    assertEq(usdPriceSource.symbol(), '(ETH / USD)^-1 / (ETH / USD)');
  }

  // --- Delayed ---

  function test_DelayedOracle() public {
    assertEq(wethUsdDelayedOracle.read(), CHAINLINK_ETH_USD_PRICE_18_DECIMALS);

    (uint256 _result, bool _validity) = wethUsdDelayedOracle.getResultWithValidity();
    assertTrue(_validity);
    assertEq(_result, CHAINLINK_ETH_USD_PRICE_18_DECIMALS);

    (uint256 _nextResult, bool _nextValidity) = wethUsdDelayedOracle.getNextResultWithValidity();
    assertTrue(_nextValidity);
    assertEq(_nextResult, CHAINLINK_ETH_USD_PRICE_18_DECIMALS);
  }

  function test_DelayedOracleUpdateResult() public {
    vm.mockCall(
      OP_CHAINLINK_ETH_USD_FEED,
      abi.encodeWithSelector(IChainlinkOracle.latestRoundData.selector),
      abi.encode(uint80(0), int256(NEW_ETH_USD_PRICE), uint256(0), block.timestamp, uint80(0))
    );

    assertEq(wethUsdPriceSource.read(), NEW_ETH_USD_PRICE_18_DECIMALS);
    assertEq(wethUsdDelayedOracle.read(), CHAINLINK_ETH_USD_PRICE_18_DECIMALS);

    vm.warp(block.timestamp + 1 hours);
    wethUsdDelayedOracle.updateResult();

    (uint256 _result,) = wethUsdDelayedOracle.getResultWithValidity();
    assertEq(_result, CHAINLINK_ETH_USD_PRICE_18_DECIMALS);

    (uint256 _nextResult,) = wethUsdDelayedOracle.getNextResultWithValidity();
    assertEq(_nextResult, NEW_ETH_USD_PRICE_18_DECIMALS);

    vm.warp(block.timestamp + 1 hours);
    wethUsdDelayedOracle.updateResult();

    (_result,) = wethUsdDelayedOracle.getResultWithValidity();
    assertEq(_result, NEW_ETH_USD_PRICE_18_DECIMALS);
  }

  function test_DelayedOracleUpdateInvalidResult() public {
    // The next update returns an invalid result (for the first 10 minutes)
    vm.mockCall(
      OP_CHAINLINK_ETH_USD_FEED,
      abi.encodeWithSelector(IChainlinkOracle.latestRoundData.selector),
      abi.encode(uint80(0), int256(NEW_ETH_USD_PRICE), uint256(0), block.timestamp + 1 hours + 10 minutes, uint80(0))
    );

    bool _valid;
    vm.warp(block.timestamp + 1 hours);
    wethUsdDelayedOracle.updateResult();

    // The 'next' feed is now the current feed, which will be valid
    (, _valid) = wethUsdDelayedOracle.getResultWithValidity();
    assertEq(_valid, true);
    // The upcoming feed however is invalid
    (, _valid) = wethUsdDelayedOracle.getNextResultWithValidity();
    assertEq(_valid, false);

    // After 10 minutes this result becomes valid and it's updated to reflect this
    vm.warp(block.timestamp + 10 minutes);
    wethUsdDelayedOracle.updateResult();

    // The current feed should stay valid
    (, _valid) = wethUsdDelayedOracle.getResultWithValidity();
    assertEq(_valid, true);
    // Check that the next feed now has also become valid
    (, _valid) = wethUsdDelayedOracle.getNextResultWithValidity();
    assertEq(_valid, true);

    vm.warp(block.timestamp + 1 hours);
    wethUsdDelayedOracle.updateResult();
  }

  function test_DelayedOracleSymbol() public {
    assertEq(wethUsdDelayedOracle.symbol(), 'ETH / USD');
  }
}

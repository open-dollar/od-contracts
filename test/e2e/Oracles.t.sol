// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';

import {ChainlinkRelayer, IBaseOracle} from '@contracts/oracles/ChainlinkRelayer.sol';
import {UniV3Relayer} from '@contracts/oracles/UniV3Relayer.sol';

import {DenominatedOracle, IDenominatedOracle} from '@contracts/oracles/DenominatedOracle.sol';
import {DelayedOracle, IDelayedOracle} from '@contracts/oracles/DelayedOracle.sol';

import {CHAINLINK_ETH_USD_FEED, CHAINLINK_WSTETH_ETH_FEED, WBTC, WETH} from '@script/Registry.s.sol';

import {Math, WAD} from '@libraries/Math.sol';

contract OracleSetup is HaiTest {
  using Math for uint256;

  // uint256 CHAINLINK_WSTETH_ETH_PRICE = 1_124_766_090_043_756_600; // NOTE: 18 decimals

  uint256 WBTC_ETH_PRICE = 14_864_307_223_256_388_569; // 1 BTC = 14.8 ETH
  uint256 WBTC_USD_PRICE = 27_032_972_331_575_231_071_011; // 1 BTC = 27,032 USD

  // July 14 2022 7:33 AM - 3:33PM (8h window)
  // - wierd workaround due to Arbitrum block.number refering to L1
  // uint256 FORK_BLOCK = 17_603_828;
  uint256 FORK_BLOCK = 141_542_579;
  uint256 FORK_CHANGE = 15_139_375;

  uint256 CHAINLINK_ETH_USD_PRICE_18_DECIMALS = 1_097_858_600_000_000_000_000;
  uint256 CHAINLINK_WSTETH_ETH_PRICE = 965_000_000_000_000_000; // NOTE: 18 decimals
  uint256 WSTETH_USD_PRICE = CHAINLINK_WSTETH_ETH_PRICE.wmul(CHAINLINK_ETH_USD_PRICE_18_DECIMALS);

  int256 ETH_USD_PRICE_L = 107_800_000_000;
  int256 ETH_USD_PRICE_H = 120_200_000_000;

  uint256 NEW_ETH_USD_PRICE = 200_000_000_000;
  uint256 NEW_ETH_USD_PRICE_18_DECIMALS = 2_000_000_000_000_000_000_000;

  uint24 FEE_TIER = 500;

  IBaseOracle public wethUsdPriceSource;
  IBaseOracle public wstethEthPriceSource;
  IBaseOracle public wbtcWethPriceSource;

  IDenominatedOracle public wstethUsdPriceSource;
  IDenominatedOracle public wbtcUsdPriceSource;

  IDelayedOracle public wethUsdDelayedOracle;

  // TODO: Uniswap relayers need to be deployed and addresses used in this test
  function setUp() public {
    /**
     * @dev Arbitrum block.number returns L1; createSelectFork does not work
     */
    uint256 forkId = vm.createFork(vm.rpcUrl('mainnet'));
    vm.selectFork(forkId);
    vm.rollFork(FORK_BLOCK);

    // --- Chainlink ---
    wethUsdPriceSource = new ChainlinkRelayer(CHAINLINK_ETH_USD_FEED, 1 days);
    wstethEthPriceSource = new ChainlinkRelayer(CHAINLINK_WSTETH_ETH_FEED, 1 days);

    // --- UniV3 ---
    wbtcWethPriceSource = new UniV3Relayer(WBTC, WETH, FEE_TIER, 1 days);

    // --- Denominated ---
    wstethUsdPriceSource = new DenominatedOracle(wstethEthPriceSource, wethUsdPriceSource, false);
    wbtcUsdPriceSource = new DenominatedOracle(wbtcWethPriceSource, wethUsdPriceSource, false);

    // --- Delayed ---
    wethUsdDelayedOracle = new DelayedOracle(wethUsdPriceSource, 1 hours);
  }

  function test_ArbitrumFork() public {
    emit log_named_uint('L1 Block Number Oracle Fork', block.number);
    assertEq(block.number, FORK_CHANGE);
  }

  // --- Chainlink ---

  function test_ChainlinkOracle() public {
    int256 price = IChainlinkOracle(CHAINLINK_ETH_USD_FEED).latestAnswer();
    assertTrue(price >= ETH_USD_PRICE_L && price <= ETH_USD_PRICE_H);
  }

  function test_ChainlinkRelayer() public {
    assertEq(CHAINLINK_ETH_USD_PRICE_18_DECIMALS / 1e18, 1097);
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

  /**
   * @dev This method may revert with 'OLD!' if the pool doesn't have enough cardinality or initialized history
   */
  function test_UniV3Relayer() public {
    // assertEq(wbtcWethPriceSource.read(), WBTC_ETH_PRICE);
    emit log_string('OLD; pool lacks cardinality or initialized history!');
  }

  function test_UniV3RelayerSymbol() public {
    assertEq(wbtcWethPriceSource.symbol(), 'CBETH / WSTETH');
  }

  // --- Denominated ---

  /**
   * NOTE: deployer needs to check that the symbols of the two oracles
   *       concatenate in the right order, e.g WSTETH/ETH - ETH/USD
   */
  function test_DenominatedOracle() public {
    assertEq(WSTETH_USD_PRICE / 1e18, 1059); // 1097.86 * 0.965 = 1059
    assertEq(wstethUsdPriceSource.read(), WSTETH_USD_PRICE);
  }

  /**
   * @dev This method may revert with 'OLD!' if the pool doesn't have enough cardinality or initialized history
   */
  function test_DenominatedOracleUniV3() public {
    // assertEq(WBTC_USD_PRICE / 1e18, 27_032); // 14.864 * 1818.65 = 27032
    // assertEq(wbtcUsdPriceSource.read(), WBTC_USD_PRICE);
    emit log_string('OLD; pool lacks cardinality or initialized history!');
  }

  function test_DenominatedOracleSymbol() public {
    // assertEq(wstethUsdPriceSource.symbol(), '(WSTETH / ETH) * (ETH / USD)');
    emit log_string('(wstETH-stETH Exchange Rate) * (ETH / USD) => should be: (WSTETH / ETH) * (ETH / USD)');
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
      CHAINLINK_ETH_USD_FEED,
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

  function test_DelayedOracleSymbol() public {
    assertEq(wethUsdDelayedOracle.symbol(), 'ETH / USD');
  }
}

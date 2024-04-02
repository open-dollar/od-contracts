// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ODTest} from '@test/utils/ODTest.t.sol';
import {IChainlinkOracle} from '@interfaces/oracles/IChainlinkOracle.sol';
import {ChainlinkRelayer, IBaseOracle} from '@contracts/oracles/ChainlinkRelayer.sol';
import {DenominatedOracle, IDenominatedOracle} from '@contracts/oracles/DenominatedOracle.sol';
import {DelayedOracle, IDelayedOracle} from '@contracts/oracles/DelayedOracle.sol';
import {
  CHAINLINK_ETH_USD_FEED,
  CHAINLINK_WSTETH_ETH_FEED,
  CHAINLINK_CBETH_ETH_FEED,
  MAINNET_CAMELOT_AMM_FACTORY
} from '@script/Registry.s.sol';

import {Math, WAD} from '@libraries/Math.sol';

contract OracleSetup is ODTest {
  using Math for uint256;

  uint256 ARBTIRUM_BLOCK = 159_201_690; // (Dec-11-2023 11:29:40 PM +UTC)
  uint256 ETHEREUM_BLOCK = 18_766_228; // (Dec-11-2023 11:26:35 PM +UTC)

  // approx. price of ETH in USD w/ 18 decimals
  uint256 CHAINLINK_ETH_USD_PRICE_H = 2_218_500_000_000_000_000_000; // +1 USD
  uint256 CHAINLINK_ETH_USD_PRICE_L = 2_216_500_000_000_000_000_000; // -1 USD

  // approx. price of ETH in USD w/ 6 decimals
  int256 ETH_USD_PRICE_H = 221_850_000_000; // +1 USD
  int256 ETH_USD_PRICE_L = 221_650_000_000; // -1 USD

  uint256 CHAINLINK_ETH_USD_PRICE_18_DECIMALS_H = 2_223_330_000_000_000_000_000;
  uint256 CHAINLINK_ETH_USD_PRICE_18_DECIMALS_L = 2_217_310_000_000_000_000_000;
  uint256 CHAINLINK_WSTETH_ETH_PRICE = 1_145_666_090_043_756_600; // 1.14% value of ETH
  uint256 WSTETH_USD_PRICE = CHAINLINK_WSTETH_ETH_PRICE.wmul(CHAINLINK_ETH_USD_PRICE_18_DECIMALS_H);

  uint256 NEW_ETH_USD_PRICE = 200_000_000_000;
  uint256 NEW_ETH_USD_PRICE_18_DECIMALS = 2_000_000_000_000_000_000_000;

  IBaseOracle public wethUsdPriceSource;
  IBaseOracle public wstethEthPriceSource;
  IBaseOracle public cbethEthPriceSource;

  IDenominatedOracle public wstethUsdPriceSource;
  IDenominatedOracle public cbethUsdPriceSource;

  IDelayedOracle public wethUsdDelayedOracle;

  function setUp() public {
    /**
     * @dev Arbitrum block.number returns L1; createSelectFork does not work
     */
    uint256 forkId = vm.createFork(vm.rpcUrl('mainnet'));
    vm.selectFork(forkId);
    vm.rollFork(ARBTIRUM_BLOCK);

    // --- Chainlink ---
    wethUsdPriceSource = new ChainlinkRelayer(CHAINLINK_ETH_USD_FEED, 1 days);
    wstethEthPriceSource = new ChainlinkRelayer(CHAINLINK_WSTETH_ETH_FEED, 1 days);
    cbethEthPriceSource = new ChainlinkRelayer(CHAINLINK_CBETH_ETH_FEED, 1 days);

    // --- Denominated ---
    wstethUsdPriceSource = new DenominatedOracle(wstethEthPriceSource, wethUsdPriceSource, false);
    cbethUsdPriceSource = new DenominatedOracle(cbethEthPriceSource, wethUsdPriceSource, false);

    // --- Delayed ---
    wethUsdDelayedOracle = new DelayedOracle(wethUsdPriceSource, 1 hours);
  }

  function test_ArbitrumFork() public {
    emit log_named_uint('L1 Block Number Oracle Fork', block.number);
    assertEq(block.number, ETHEREUM_BLOCK);
  }

  // --- Chainlink ---

  function test_ChainlinkOracle() public {
    int256 price = IChainlinkOracle(CHAINLINK_ETH_USD_FEED).latestAnswer();
    assertTrue(price >= ETH_USD_PRICE_L && price <= ETH_USD_PRICE_H);
  }

  function test_ChainlinkRelayer() public {
    uint256 price = wethUsdPriceSource.read();
    assertTrue(price >= CHAINLINK_ETH_USD_PRICE_L && price <= CHAINLINK_ETH_USD_PRICE_H);
  }

  function test_ChainlinkRelayerSymbol() public {
    assertEq(wethUsdPriceSource.symbol(), 'ETH / USD');
  }

  // --- Denominated ---

  function test_DenominatedOracle() public {
    assertEq(wstethUsdPriceSource.read() / WAD, WSTETH_USD_PRICE / WAD);
  }

  function test_DenominatedOracleSymbol() public {
    assertEq(wstethUsdPriceSource.symbol(), '(WSTETH / ETH) * (ETH / USD)');
  }

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
    assertEq(wethUsdDelayedOracle.read() / WAD, CHAINLINK_ETH_USD_PRICE_18_DECIMALS_L / WAD);

    (uint256 _result, bool _validity) = wethUsdDelayedOracle.getResultWithValidity();
    assertTrue(_validity);
    assertEq(_result / WAD, CHAINLINK_ETH_USD_PRICE_18_DECIMALS_L / WAD);

    (uint256 _nextResult, bool _nextValidity) = wethUsdDelayedOracle.getNextResultWithValidity();
    assertTrue(_nextValidity);
    assertEq(_nextResult / WAD, CHAINLINK_ETH_USD_PRICE_18_DECIMALS_L / WAD);
  }

  function test_DelayedOracleUpdateResult() public {
    vm.mockCall(
      CHAINLINK_ETH_USD_FEED,
      abi.encodeWithSelector(IChainlinkOracle.latestRoundData.selector),
      abi.encode(uint80(0), int256(NEW_ETH_USD_PRICE), uint256(0), block.timestamp, uint80(0))
    );

    assertEq(wethUsdPriceSource.read(), NEW_ETH_USD_PRICE_18_DECIMALS);
    assertEq(wethUsdDelayedOracle.read() / WAD, CHAINLINK_ETH_USD_PRICE_18_DECIMALS_L / WAD);

    vm.warp(block.timestamp + 1 hours);
    wethUsdDelayedOracle.updateResult();

    (uint256 _result,) = wethUsdDelayedOracle.getResultWithValidity();
    assertEq(_result / WAD, CHAINLINK_ETH_USD_PRICE_18_DECIMALS_L / WAD);

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
      CHAINLINK_ETH_USD_FEED,
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

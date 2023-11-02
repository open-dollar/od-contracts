// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Contracts.s.sol';
import '@script/Registry.s.sol';
import '@script/Params.s.sol';

import {Script} from 'forge-std/Script.sol';
import {Common} from '@script/Common.s.sol';
import {GoerliParams} from '@script/GoerliParams.s.sol';
import {MainnetParams} from '@script/MainnetParams.s.sol';

abstract contract Deploy is Common, Script {
  function setupEnvironment() public virtual {}
  function setupPostEnvironment() public virtual {}

  function run() public {
    deployer = vm.addr(_deployerPk);
    vm.startBroadcast(deployer);

    // Environment may be different for each network
    setupEnvironment();

    // Common deployment routine for all networks
    deployContracts();
    deployTaxModule();
    _setupContracts();

    deployGlobalSettlement();
    _setupGlobalSettlement();

    // PID Controller contracts
    deployPIDController();
    _setupPIDController();

    // Rewarded Actions contracts
    deployJobContracts();
    _setupJobContracts();

    // Deploy collateral contracts
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];

      deployCollateralContracts(_cType);
      _setupCollateral(_cType);
    }

    // Deploy contracts related to the SafeManager usecase
    deployProxyContracts(address(safeEngine));

    // Deploy and setup contracts that rely on deployed environment
    setupPostEnvironment();

    if (delegate == address(0)) {
      _revokeAllTo(governor);
    } else if (delegate == deployer) {
      _delegateAllTo(governor);
    } else {
      _delegateAllTo(delegate);
      _revokeAllTo(governor);
    }

    vm.stopBroadcast();
  }
}

contract DeployMainnet is MainnetParams, Deploy {
  function setUp() public virtual {
    _deployerPk = uint256(vm.envBytes32('OP_MAINNET_DEPLOYER_PK'));
    chainId = 10;
  }

  function setupEnvironment() public virtual override updateParams {
    // Deploy oracle factories
    chainlinkRelayerFactory = new ChainlinkRelayerFactory(OP_CHAINLINK_SEQUENCER_UPTIME_FEED);
    uniV3RelayerFactory = new UniV3RelayerFactory();
    denominatedOracleFactory = new DenominatedOracleFactory();
    delayedOracleFactory = new DelayedOracleFactory();

    // Setup oracle feeds
    IBaseOracle _ethUSDPriceFeed = chainlinkRelayerFactory.deployChainlinkRelayer(OP_CHAINLINK_ETH_USD_FEED, 1 hours);
    IBaseOracle _wstethETHPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(OP_CHAINLINK_WSTETH_ETH_FEED, 1 hours);

    IBaseOracle _wstethUSDPriceFeed = denominatedOracleFactory.deployDenominatedOracle({
      _priceSource: _wstethETHPriceFeed,
      _denominationPriceSource: _ethUSDPriceFeed,
      _inverted: false
    });

    systemCoinOracle = new HardcodedOracle('HAI / USD', HAI_INITIAL_PRICE); // 1 HAI = 1 USD
    delayedOracle[WETH] = delayedOracleFactory.deployDelayedOracle(_ethUSDPriceFeed, 1 hours);
    delayedOracle[WSTETH] = delayedOracleFactory.deployDelayedOracle(_wstethUSDPriceFeed, 1 hours);

    collateral[WETH] = IERC20Metadata(OP_WETH);
    collateral[WSTETH] = IERC20Metadata(OP_WSTETH);

    collateralTypes.push(WETH);
    collateralTypes.push(WSTETH);
  }

  function setupPostEnvironment() public virtual override updateParams {}
}

contract DeployGoerli is GoerliParams, Deploy {
  function setUp() public virtual {
    _deployerPk = uint256(vm.envBytes32('OP_GOERLI_DEPLOYER_PK'));
    chainId = 420;
  }

  function setupEnvironment() public virtual override updateParams {
    // Deploy oracle factories
    chainlinkRelayerFactory = new ChainlinkRelayerFactory(OP_GOERLI_CHAINLINK_SEQUENCER_UPTIME_FEED);
    uniV3RelayerFactory = new UniV3RelayerFactory();
    denominatedOracleFactory = new DenominatedOracleFactory();
    delayedOracleFactory = new DelayedOracleFactory();

    // Setup oracle feeds

    // HAI
    systemCoinOracle = new HardcodedOracle('HAI / USD', HAI_INITIAL_PRICE); // 1 HAI = 1 USD

    // WETH
    collateral[WETH] = IERC20Metadata(OP_WETH);
    IBaseOracle _ethUSDPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(OP_GOERLI_CHAINLINK_ETH_USD_FEED, 1 hours); // live feed

    // OP
    collateral[OP] = IERC20Metadata(OP_OPTIMISM);
    HardcodedOracle _opETHPriceFeed = new HardcodedOracle('OP / ETH', OP_GOERLI_OP_ETH_PRICE_FEED); // denominated feed
    IBaseOracle _opUSDPriceFeed = denominatedOracleFactory.deployDenominatedOracle({
      _priceSource: _opETHPriceFeed,
      _denominationPriceSource: _ethUSDPriceFeed,
      _inverted: false
    });

    // Test tokens
    collateral[WBTC] = new MintableERC20('Wrapped BTC', 'wBTC', 8);
    collateral[STONES] = new MintableERC20('Stones', 'STN', 3);
    collateral[TOTEM] = new MintableERC20('Totem', 'TTM', 0);

    // BTC: live feed
    IBaseOracle _wbtcUsdOracle =
      chainlinkRelayerFactory.deployChainlinkRelayer(OP_GOERLI_CHAINLINK_BTC_USD_FEED, 1 hours);
    // STN: denominated feed (1000 STN = 1 wBTC)
    IBaseOracle _stonesWbtcOracle = new HardcodedOracle('STN / BTC', 0.001e18);
    IBaseOracle _stonesOracle =
      denominatedOracleFactory.deployDenominatedOracle(_stonesWbtcOracle, _wbtcUsdOracle, false);
    // TTM: hardcoded feed (TTM price is 1)
    IBaseOracle _totemOracle = new HardcodedOracle('TTM', 1e18);

    delayedOracle[WETH] = delayedOracleFactory.deployDelayedOracle(_ethUSDPriceFeed, 1 hours);
    delayedOracle[OP] = delayedOracleFactory.deployDelayedOracle(_opUSDPriceFeed, 1 hours);
    delayedOracle[WBTC] = delayedOracleFactory.deployDelayedOracle(_wbtcUsdOracle, 1 hours);
    delayedOracle[STONES] = delayedOracleFactory.deployDelayedOracle(_stonesOracle, 1 hours);
    delayedOracle[TOTEM] = delayedOracleFactory.deployDelayedOracle(_totemOracle, 1 hours);

    // Setup collateral types
    collateralTypes.push(WETH);
    collateralTypes.push(OP);
    collateralTypes.push(WBTC);
    collateralTypes.push(STONES);
    collateralTypes.push(TOTEM);
  }

  function setupPostEnvironment() public virtual override updateParams {
    // Setup deviated oracle
    systemCoinOracle = new DeviatedOracle({
      _symbol: 'HAI/USD',
      _oracleRelayer: address(oracleRelayer),
      _deviation: OP_GOERLI_HAI_PRICE_DEVIATION
    });

    oracleRelayer.modifyParameters('systemCoinOracle', abi.encode(systemCoinOracle));
  }
}

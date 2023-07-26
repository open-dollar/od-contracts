// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Contracts.s.sol';
import {Script} from 'forge-std/Script.sol';
import {Params, ParamChecker, HAI, WETH, ETH_A, WSTETH, OP, HAI_INITIAL_PRICE} from '@script/Params.s.sol';
import {Common} from '@script/Common.s.sol';
import {GoerliParams} from '@script/GoerliParams.s.sol';
import {MainnetParams} from '@script/MainnetParams.s.sol';
import '@script/Registry.s.sol';

abstract contract Deploy is Common, Script {
  function _setupEnvironment() internal virtual {}

  function run() public {
    deployer = vm.addr(_deployerPk);
    vm.startBroadcast(deployer);

    // Environment may be different for each network
    _setupEnvironment();

    // Common deployment routine for all networks
    deployContracts();
    _setupContracts();

    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];

      if (_cType == ETH_A) deployEthCollateralContracts();
      else deployCollateralContracts(_cType);
    }

    // Get parameters from Params.s.sol
    _getEnvironmentParams();

    deployPIDController();

    // Loop through the collateral types configured in the environment
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      _setupCollateral(_cType);
    }

    deployJobContracts();
    _setupJobContracts();

    revokeAllTo(governor);
    vm.stopBroadcast();
  }
}

contract DeployMainnet is MainnetParams, Deploy {
  function setUp() public virtual {
    _deployerPk = uint256(vm.envBytes32('OP_MAINNET_DEPLOYER_PK'));
    chainId = 10;
  }

  function _setupEnvironment() internal virtual override {
    // Setup oracle feeds
    IBaseOracle _ethUSDPriceFeed = new ChainlinkRelayer(OP_CHAINLINK_ETH_USD_FEED, 1 hours);
    IBaseOracle _wstethETHPriceFeed = new ChainlinkRelayer(OP_CHAINLINK_WSTETH_ETH_FEED, 1 hours);

    IBaseOracle _wstethUSDPriceFeed = new DenominatedOracle({
      _priceSource: _wstethETHPriceFeed,
      _denominationPriceSource: _ethUSDPriceFeed,
      _inverted: false
    });

    systemCoinOracle = new OracleForTest(HAI_INITIAL_PRICE); // 1 HAI = 1 USD
    delayedOracle[WETH] = new DelayedOracle(_ethUSDPriceFeed, 1 hours);
    delayedOracle[WSTETH] = new DelayedOracle(_wstethUSDPriceFeed, 1 hours);

    collateral[WETH] = IERC20Metadata(OP_WETH);
    collateral[WSTETH] = IERC20Metadata(OP_WSTETH);

    collateralTypes.push(WETH);
    collateralTypes.push(WSTETH);

    _getEnvironmentParams();
  }
}

contract DeployGoerli is GoerliParams, Deploy {
  function setUp() public virtual {
    _deployerPk = uint256(vm.envBytes32('OP_GOERLI_DEPLOYER_PK'));
    chainId = 420;
  }

  function _setupEnvironment() internal virtual override {
    // Setup oracle feeds

    systemCoinOracle = new OracleForTestnet(HAI_INITIAL_PRICE); // 1 HAI = 1 USD
    haiOracleForTest = OracleForTestnet(address(systemCoinOracle));

    IBaseOracle _ethUSDPriceFeed = new ChainlinkRelayer(OP_GOERLI_CHAINLINK_ETH_USD_FEED, 1 hours);

    OracleForTestnet _opETHPriceFeed = new OracleForTestnet(OP_GOERLI_OP_ETH_PRICE_FEED);
    opEthOracleForTest = OracleForTestnet(address(_opETHPriceFeed));

    DenominatedOracle _opUSDPriceFeed = new DenominatedOracle({
      _priceSource: _opETHPriceFeed,
      _denominationPriceSource: _ethUSDPriceFeed,
      _inverted: false
    });

    delayedOracle[WETH] = new DelayedOracle(_ethUSDPriceFeed, 1 hours);
    delayedOracle[OP] = new DelayedOracle(_opUSDPriceFeed, 1 hours);

    collateral[WETH] = IERC20Metadata(OP_WETH);
    collateral[OP] = IERC20Metadata(OP_OPTIMISM);

    // Setup collateral params
    collateralTypes.push(WETH);
    collateralTypes.push(OP);

    _getEnvironmentParams();

    // Setup delegated collateral joins
    delegatee[OP] = governor;

    // Revoke oracles authorizations

    if (_shouldRevoke()) {
      haiOracleForTest.addAuthorization(governor);
      opEthOracleForTest.addAuthorization(governor);

      haiOracleForTest.removeAuthorization(deployer);
      opEthOracleForTest.removeAuthorization(deployer);
    }
  }
}

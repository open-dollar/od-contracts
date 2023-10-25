// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';
import {LiquidityBase} from '@script/dexpool/base/LiquidityBase.s.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IAlgebraPool} from '@cryptoalgebra-core/interfaces/IAlgebraPool.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ICamelotRelayer} from '@interfaces/oracles/ICamelotRelayer.sol';
import {ChainlinkRelayerFactory, IChainlinkRelayerFactory} from '@contracts/factories/ChainlinkRelayerFactory.sol';
import {CamelotRelayerFactory, ICamelotRelayerFactory} from '@contracts/factories/CamelotRelayerFactory.sol';
import {DenominatedOracleFactory, IDenominatedOracleFactory} from '@contracts/factories/DenominatedOracleFactory.sol';
import '@script/Registry.s.sol';
import '@script/GoerliDeployment.s.sol';

// BROADCAST
// source .env && forge script ReDeployCamelotOracle --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script ReDeployCamelotOracle --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC

contract ReDeployCamelotOracle is GoerliDeployment, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('GOERLI_PK'));
    uint256 oracleInterval = 1 seconds;

    // authorization work-around + update camelotRelayer contract in factory
    ChainlinkRelayerFactory chainlinkRelayerFactory2 = new ChainlinkRelayerFactory();
    CamelotRelayerFactory camelotRelayerFactory2 = new CamelotRelayerFactory();
    DenominatedOracleFactory denominatedOracleFactory2 = new DenominatedOracleFactory();

    IBaseOracle chainlinkEthUSDPriceFeed =
      chainlinkRelayerFactory2.deployChainlinkRelayer(GOERLI_CHAINLINK_ETH_USD_FEED, oracleInterval);

    // create pool: done

    address pool = algebraFactory.poolByPair(address(systemCoin), address(collateral[WSTETH]));

    IERC20Metadata token0 = IERC20Metadata(IAlgebraPool(pool).token0());
    IERC20Metadata token1 = IERC20Metadata(IAlgebraPool(pool).token1());

    require(keccak256(abi.encodePacked('OD')) == keccak256(abi.encodePacked(token0.symbol())), '!OD');
    require(keccak256(abi.encodePacked('wstETH')) == keccak256(abi.encodePacked(token1.symbol())), '!wstETH');

    // calculate `sqrtPriceX96` and initialize pool: done

    // deploy Camelot relayer to retrieve price from Camelot pool
    IBaseOracle _odWethOracle = camelotRelayerFactory2.deployCamelotRelayer(
      address(systemCoin), address(collateral[WSTETH]), uint32(oracleInterval)
    );

    // deploy denominated oracle of OD/WSTETH denominated against ETH/USD
    systemCoinOracle = denominatedOracleFactory2.deployDenominatedOracle(_odWethOracle, chainlinkEthUSDPriceFeed, false);

    // not authorized to modify params
    // oracleRelayer.modifyParameters('systemCoinOracle', abi.encode(systemCoinOracle));
    vm.stopBroadcast();
  }
}

// BROADCAST
// source .env && forge script TestResultWithValidity --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script TestResultWithValidity --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC

contract TestResultWithValidity is Script {
  // new script to make time break btw runs
  function run() public {
    vm.startBroadcast(vm.envUint('GOERLI_PK'));
    address _odWethOracle = 0x68a16339e061493d67305D1f73701241Df23B931;

    // test getResultWithValidity
    // TODO: error = revert on `getTimepoints` in DataStorage library
    (uint256 _result, bool _validity) = ICamelotRelayer(address(_odWethOracle)).getResultWithValidity();
  }
}

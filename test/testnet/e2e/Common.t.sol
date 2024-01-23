// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {MAINNET_WETH, SEPOLIA_WETH} from '@script/Registry.s.sol';
import {HaiTest} from '@testnet/utils/HaiTest.t.sol';
import {OD, OD_INITIAL_PRICE, ETH_A} from '@script/Params.s.sol';
import {Deploy} from '@script/Deploy.s.sol';
import {TestParams, WSTETH, TKN, TEST_ETH_PRICE, TEST_TKN_PRICE} from '@testnet/e2e/TestParams.t.sol';
import {ERC20ForTest} from '@testnet/mocks/ERC20ForTest.sol';
import {OracleForTest} from '@testnet/mocks/OracleForTest.sol';
import {DelayedOracleForTest} from '@testnet/mocks/DelayedOracleForTest.sol';
import {
  Contracts, ICollateralJoin, MintableERC20, IERC20Metadata, IBaseOracle, ISAFEEngine
} from '@script/Contracts.s.sol';
import {WETH9} from '@testnet/mocks/WETH9.sol';
import {Math, RAY} from '@libraries/Math.sol';

import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';

uint256 constant RAD_DELTA = 0.0001e45;
uint256 constant COLLATERAL_PRICE = 100e18;

uint256 constant COLLAT = 1e18;
uint256 constant DEBT = 500e18; // LVT 50%
uint256 constant TEST_ETH_PRICE_DROP = 100e18; // 1 ETH = 100 OD

/**
 * @title  DeployForTest
 * @notice Contains the deployment initialization routine for test environments
 */
contract DeployForTest is TestParams, Deploy {
  constructor() {
    // NOTE: creates fork in order to have WSTETH at 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1
    vm.createSelectFork(vm.rpcUrl('mainnet'));
  }

  function setupEnvironment() public virtual override {
    WETH9 weth = WETH9(payable(MAINNET_WETH));

    systemCoinOracle = new OracleForTest(OD_INITIAL_PRICE); // 1 OD = 1 USD

    collateral[WSTETH] = IERC20Metadata(address(weth));
    collateral[TKN] = new ERC20ForTest();

    delayedOracle[WSTETH] = new DelayedOracleForTest(TEST_ETH_PRICE, address(0));
    delayedOracle[TKN] = new DelayedOracleForTest(TEST_TKN_PRICE, address(0));
    delayedOracle['TKN-A'] = new DelayedOracleForTest(COLLATERAL_PRICE, address(0));
    delayedOracle['TKN-B'] = new DelayedOracleForTest(COLLATERAL_PRICE, address(0));
    delayedOracle['TKN-C'] = new DelayedOracleForTest(COLLATERAL_PRICE, address(0));
    delayedOracle['TKN-8D'] = new DelayedOracleForTest(COLLATERAL_PRICE, address(0));

    collateral['TKN-A'] = new ERC20ForTest();
    collateral['TKN-B'] = new ERC20ForTest();
    collateral['TKN-C'] = new ERC20ForTest();
    collateral['TKN-8D'] = new MintableERC20('8 Decimals TKN', 'TKN', 8);

    collateralTypes.push(WSTETH);
    collateralTypes.push(TKN);
    collateralTypes.push('TKN-A');
    collateralTypes.push('TKN-B');
    collateralTypes.push('TKN-C');
    collateralTypes.push('TKN-8D');
  }
}

/**
 * @title  Common
 * @notice Abstract contract that contains for test methods, and triggers DeployForTest routine
 * @dev    Used to be inherited by different test contracts with different scopes
 */
abstract contract Common is DeployForTest, HaiTest {
  address alice = address(0x420);
  address bob = address(0x421);
  address carol = address(0x422);
  address dave = address(0x423);

  uint256 auctionId;

  function setUp() public virtual {
    run();

    for (uint256 i = 0; i < collateralTypes.length; i++) {
      bytes32 _cType = collateralTypes[i];
      taxCollector.taxSingle(_cType);
    }

    vm.label(deployer, 'Deployer');
    vm.label(alice, 'Alice');
    vm.label(bob, 'Bob');
    vm.label(carol, 'Carol');
    vm.label(dave, 'Dave');
  }

  function _setCollateralPrice(bytes32 _collateral, uint256 _price) internal {
    IBaseOracle _oracle = oracleRelayer.cParams(_collateral).oracle;
    vm.mockCall(
      address(_oracle), abi.encodeWithSelector(IBaseOracle.getResultWithValidity.selector), abi.encode(_price, true)
    );
    vm.mockCall(address(_oracle), abi.encodeWithSelector(IBaseOracle.read.selector), abi.encode(_price));
    oracleRelayer.updateCollateralPrice(_collateral);
  }

  function _collectFees(bytes32 _cType, uint256 _timeToWarp) internal {
    vm.warp(block.timestamp + _timeToWarp);
    taxCollector.taxSingle(_cType);
  }
}

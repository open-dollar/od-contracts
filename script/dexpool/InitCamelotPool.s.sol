// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {LiquidityBase} from '@script/dexpool/base/LiquidityBase.s.sol';
import {FixedPointMathLib} from '@isolmate/utils/FixedPointMathLib.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IAlgebraPool} from '@interfaces/oracles/IAlgebraPool.sol';
import 'forge-std/console2.sol';

// BROADCAST
// source .env && forge script InitCamelotPool --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script InitCamelotPool --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract InitCamelotPool is LiquidityBase {
  using FixedPointMathLib for uint256;

  uint256 private constant WAD = 1e18;
  address public pool;

  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_PK'));
    // camelotV3Factory.createPool(tokenA, tokenB);

    // tokenA = OD w/ 18 decimal, tokenB = WETH w/ 18 decimal
    pool = camelotV3Factory.poolByPair(tokenA, tokenB);

    IERC20Metadata token0 = IERC20Metadata(IAlgebraPool(pool).token0());
    IERC20Metadata token1 = IERC20Metadata(IAlgebraPool(pool).token1());

    string memory token0Sym = token0.symbol();
    string memory token1Sym = token1.symbol();
    require(keccak256(abi.encodePacked('OD')) == keccak256(abi.encodePacked(token0Sym)), '!OD');
    require(keccak256(abi.encodePacked('WETH')) == keccak256(abi.encodePacked(token1Sym)), '!WETH');

    /**
     * @dev price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
     * @notice price the initial sqrt price (P) of the pool as a Q64.96 (2**96)
     *
     * WETH/OD 1/1656.62 = 0.000603638734290301940094...
     *
     * sqrt(amount1.divWad(amount0) * 1e18) * 2**96 / 1e18
     */

    uint256 initWethAmount = 1 ether;
    uint256 initODAmount = 1656.62 ether;

    // P = amount1 / amount0
    uint256 P = initWethAmount.divWadDown(initODAmount);
    uint256 sqrtPriceX96 = FixedPointMathLib.sqrt(P * WAD) * (2 ** 96);

    // log math
    console2.logUint((sqrtPriceX96 / (2 ** 96)) ** 2);

    IAlgebraPool(pool).initialize(uint160(sqrtPriceX96));

    // returns variables, but reverts
    // (
    //   uint160 price,
    //   int24 tick,
    //   uint16 feeZto,
    //   uint16 feeOtz,
    //   uint16 timepointIndex,
    //   uint8 communityFeeToken0,
    //   uint8 communityFeeToken1,
    //   bool unlocked
    // ) = IAlgebraPool(pool).globalState();

    // console2.logUint((uint256(price)));
    vm.stopBroadcast();
  }
}

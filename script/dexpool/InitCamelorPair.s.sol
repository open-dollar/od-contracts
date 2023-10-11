// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {LiquidityBase} from '@script/dexpool/base/LiquidityBase.s.sol';
import {FixedPointMathLib} from '@isolmate/utils/FixedPointMathLib.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';

// BROADCAST
// source .env && forge script InitCamelotPool --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script InitCamelotPool --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC

interface AlgebraPool {
  function token0() external view returns (address);
  function token1() external view returns (address);
  function initialize(uint160 initPrice) external;
  function globalState()
    external
    view
    returns (
      uint160 price,
      int24 tick,
      uint16 feeZto,
      uint16 feeOtz,
      uint16 timepointIndex,
      uint8 communityFeeToken0,
      uint8 communityFeeToken1,
      bool unlocked
    );
}

contract InitCamelotPool is LiquidityBase {
  using FixedPointMathLib for uint256;

  uint256 private constant WAD = 1e18;
  address public pool;

  function run() public {
    vm.startBroadcast(vm.envUint('GOERLI_PK'));

    // tokenA = OD w/ 18 decimal, tokenB = WETH w/ 18 decimal
    pool = camelotV3Factory.poolByPair(tokenA, tokenB);

    IERC20Metadata token0 = IERC20Metadata(AlgebraPool(pool).token0());
    IERC20Metadata token1 = IERC20Metadata(AlgebraPool(pool).token1());

    string memory token0Sym = token0.symbol();
    string memory token1Sym = token1.symbol();
    require(keccak256(abi.encodePacked('OD')) == keccak256(abi.encodePacked(token0Sym)), '!OD');
    require(keccak256(abi.encodePacked('WETH')) == keccak256(abi.encodePacked(token1Sym)), '!WETH');

    /**
     * @dev price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
     * @notice price the initial sqrt price (P) of the pool as a Q64.96 (2**96)
     *
     * WETH/OD 1/1656.62
     *
     * sqrt(amount1.divWad(amount0) * 1e18) * 2**96 / 1e18
     */

    uint256 initWethAmount = 1 ether;
    uint256 initODAmount = 1656.62 ether;

    uint256 P = initWethAmount.divWadDown(initODAmount);

    AlgebraPool(pool).initialize(uint160(FixedPointMathLib.sqrt(P * WAD) * (2 ** 96) / WAD));

    // returns, but reverts
    (uint160 sqrtPriceX96Existing,,,,,,,) = AlgebraPool(pool).globalState();
    vm.stopBroadcast();
  }
}

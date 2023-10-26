// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {FixedPointMathLib} from '@isolmate/utils/FixedPointMathLib.sol';
import {IAlgebraFactory} from '@cryptoalgebra-core/interfaces/IAlgebraFactory.sol';
import {IAlgebraPool} from '@cryptoalgebra-core/interfaces/IAlgebraPool.sol';
import {IAlgebraMintCallback} from '@cryptoalgebra-core/interfaces/callback/IAlgebraMintCallback.sol';
import {CamelotRelayerFactory} from '@contracts/factories/CamelotRelayerFactory.sol';
import {ICamelotRelayer} from '@interfaces/oracles/ICamelotRelayer.sol';
import {DenominatedOracleFactory} from '@contracts/factories/DenominatedOracleFactory.sol';
import {ChainlinkRelayerFactory, IChainlinkRelayerFactory} from '@contracts/factories/ChainlinkRelayerFactory.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {MintableERC20} from '@contracts/for-test/MintableERC20.sol';
import {MintableVoteERC20} from '@contracts/for-test/MintableVoteERC20.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';

// BROADCAST
// source .env && forge script DeployBase --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployBase --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC

contract DeployBase is IAlgebraMintCallback, Script {
  using FixedPointMathLib for uint256;

  // Constants
  uint256 private constant WAD = 1e18;
  uint256 private constant MINT_AMOUNT = 1_000_000 ether;
  uint256 private constant ORACLE_PERIOD = 1 seconds;

  // Pool & Relayer Factories
  IAlgebraFactory public algebraFactory = IAlgebraFactory(GOERLI_ALGEBRA_FACTORY);
  ChainlinkRelayerFactory public chainlinkRelayerFactory;
  CamelotRelayerFactory public camelotRelayerFactory;
  DenominatedOracleFactory public denominatedOracleFactory;

  // oracles
  IBaseOracle public chainlinkEthUSDPriceFeed;
  IBaseOracle public camelotRelayer;
  IBaseOracle public denominatedOracle;

  // Tokens
  address public tokenA;
  address public tokenB;

  // Liquidity Pool
  IAlgebraPool public pool;

  function setUp() public {
    deployFactories();

    deployTestTokens();
    MintableERC20(tokenA).mint(MINT_AMOUNT);
    MintableERC20(tokenB).mint(MINT_AMOUNT);

    // deploy chainlink oracle
    chainlinkEthUSDPriceFeed =
      chainlinkRelayerFactory.deployChainlinkRelayer(GOERLI_CHAINLINK_ETH_USD_FEED, ORACLE_PERIOD);

    deployPool();

    // check balance before
    (uint256 bal0, uint256 bal1) = getPoolBal(pool);

    // add liquidity
    (int24 bottomTick, int24 topTick) = generateTickParams();
    (uint256 amount0, uint256 amount1, uint128 liquidityActual) =
      IAlgebraPool(pool).mint(address(this), address(pool), bottomTick, topTick, 100, '');

    // check balance after
    (bal0, bal1) = getPoolBal(pool);

    // // create pool relayer
    // camelotRelayer = camelotRelayerFactory.deployCamelotRelayer(tokenA, tokenB, uint32(ORACLE_PERIOD));

    // // create denominated oracle
    // denominatedOracle =
    //   denominatedOracleFactory.deployDenominatedOracle(chainlinkEthUSDPriceFeed, camelotRelayer, false);
  }

  function run() public {}

  /**
   * @dev setup functions
   */
  function deployFactories() public {
    chainlinkRelayerFactory = new ChainlinkRelayerFactory();
    camelotRelayerFactory = new CamelotRelayerFactory();
    denominatedOracleFactory = new DenominatedOracleFactory();
  }

  function deployTestTokens() public returns (address, address) {
    MintableERC20 token0 = new MintableERC20('LST Test1', 'LST1', 18);
    MintableERC20 token1 = new MintableERC20('LST Test2', 'LST2', 18);

    tokenA = address(token0);
    tokenB = address(token1);
  }

  function deployPool() public {
    algebraFactory.createPool(tokenA, tokenB);
    pool = IAlgebraPool(algebraFactory.poolByPair(tokenA, tokenB));
    pool.initialize(getSqrtPrice(1 ether, 1656.62 ether));
  }

  function generateTickParams() public returns (int24 bottomTick, int24 topTick) {
    (, int24 tick,,,,,) = pool.globalState();
    int24 tickSpacing = pool.tickSpacing();
    bottomTick = ((tick / tickSpacing) * tickSpacing) - 3 * tickSpacing;
    topTick = ((tick / tickSpacing) * tickSpacing) + 3 * tickSpacing;
  }

  function getPoolBal(IAlgebraPool _pool) public view returns (uint256, uint256) {
    (address t0, address t1) = getPoolPair(_pool);
    address pool = address(_pool);
    return (IERC20(t0).balanceOf(pool), IERC20(t1).balanceOf(pool));
  }

  function getPoolPair(IAlgebraPool _pool) public view returns (address, address) {
    return (_pool.token0(), _pool.token1());
  }

  function getSqrtPrice(uint256 _initWethAmount, uint256 _initODAmount) public returns (uint160) {
    uint256 price = _initWethAmount.divWadDown(_initODAmount);
    uint256 sqrtPriceX96 = FixedPointMathLib.sqrt(price * WAD) * (2 ** 96);
    return uint160(sqrtPriceX96);
  }

  function getGlobalState(IAlgebraPool pool)
    public
    view
    returns (
      uint160 price,
      int24 tick,
      int24 prevInitializedTick,
      uint16 fee,
      uint16 timepointIndex,
      uint8 communityFee,
      bool unlocked
    )
  {
    (price, tick, prevInitializedTick, fee, timepointIndex, communityFee, unlocked) = pool.globalState();
  }

  function algebraMintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external {
    IERC20(tokenA).transfer(msg.sender, amount0Owed);
    IERC20(tokenB).transfer(msg.sender, amount1Owed);
  }
}

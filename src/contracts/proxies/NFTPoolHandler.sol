// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {NFTPool} from '@contracts/for-test/CamelotDex/NFTPool.sol';
import {INFTHandler} from '@contracts/for-test/CamelotDex/interfaces/INFTHandler.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/token/ERC721/IERC721.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {Initializable} from '@openzeppelin/proxy/utils/Initializable.sol';

interface CamelotRouterV2 {
  function removeLiquidity(
    address tokenA,
    address tokenB,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
  ) external returns (uint256 amountA, uint256 amountB);
}

interface INonfungiblePositionManager {
  struct DecreaseLiquidityParams {
    uint256 tokenId;
    uint128 liquidity;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
  }

  struct CollectParams {
    uint256 tokenId;
    address recipient;
    uint128 amount0Max;
    uint128 amount1Max;
  }

  function decreaseLiquidity(DecreaseLiquidityParams calldata params) external;

  function collect(CollectParams calldata params) external returns (uint256 amount0, uint256 amount1);

  function positions(uint256 tokenId)
    external
    view
    returns (
      uint96 nonce,
      address operator,
      address token0,
      address token1,
      int24 tickLower,
      int24 tickUpper,
      uint128 liquidity,
      uint256 feeGrowthInside0LastX128,
      uint256 feeGrowthInside1LastX128,
      uint128 tokensOwed0,
      uint128 tokensOwed1
    );
}

// Generic interface for a liquidity pool.
interface ILiquidityPool {
  function token0() external view returns (address);
  function token1() external view returns (address);

  function withdraw(
    uint256 shares,
    uint256 amount0Min,
    uint256 amount1Min,
    address to
  ) external returns (uint256 amount0, uint256 amount1);

  // Uniswap V2
  function removeLiquidity(
    address tokenA,
    address tokenB,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
  ) external returns (uint256 amountA, uint256 amountB);
}

/**
 * @title  NFTPoolHandler
 * @notice This contract will unwinds the CamelotDex position and transfer the tokens to the user ODProxy to be deposit on OD protocol
 * @dev This contract is meant to be used by users that already have ODProxy contract
 */
contract NFTPoolHandler is INFTHandler, Initializable {
  error NFT_HANDLER_POSITION_AMOUNT_ZERO();
  error NTF_HANDLER_ROUTER_NOT_SET();

  ODProxy public odProxy;
  address public immutable nftPool;
  address public proxyOwner; // don't call ODProxy.OWNER() multi times to save gas
  address public immutable router; // depending on the version of the pool can be router v2 or v3

  modifier onlyOwner() {
    require(msg.sender == proxyOwner, 'NFTPoolHandler: only ODProxy');
    _;
  }

  constructor(address _nftPool, address _router) {
    nftPool = _nftPool;
    router = _router;
    _disableInitializers();
  }

  // add more checks for each address
  function initialize(ODProxy _odProxy) external initializer {
    odProxy = _odProxy;
    proxyOwner = _odProxy.OWNER();
    assert(proxyOwner != address(0));
  }

  /**
   * @notice Transfers the NFT to this contract
   * @param from Address of the NFT to transfer
   * @param tokenId ID of the NFT to transfer
   * @return True on success
   */
  function transferFrom(address from, uint256 tokenId) public onlyOwner returns (bool) {
    NFTPool(nftPool).safeTransferFrom(from, address(this), tokenId);
    return true;
  }
  /**
   * @notice Withdraws from a V2 position and sends underlying tokens to the ODProxy.
   * @param tokenId ID of the NFT representing the position.
   * @param amount0Min Minimum amount of token0 expected to prevent slippage.
   * @param amount1Min Minimum amount of token1 expected to prevent slippage.
   * @return True on success.
   */

  function withdrawFromPositionV2(
    uint256 tokenId,
    uint256 amount0Min,
    uint256 amount1Min
  ) public onlyOwner returns (bool) {
    if (router == address(0)) {
      revert NTF_HANDLER_ROUTER_NOT_SET();
    }
    uint256 positionAmount = _getPositionAmountV2(tokenId);
    if (positionAmount == 0) {
      revert NFT_HANDLER_POSITION_AMOUNT_ZERO();
    }

    ILiquidityPool liquidityPool = ILiquidityPool(_getLiquidityPool());
    NFTPool(nftPool).withdrawFromPosition(tokenId, positionAmount);

    uint256 shares = IERC20(address(liquidityPool)).balanceOf(address(this));

    if (shares == 0) {
      revert NFT_HANDLER_POSITION_AMOUNT_ZERO();
    }

    // TODO: Transfer OD Token to user

    // IERC20(address(liquidityPool)).transfer(address(odProxy), shares);
    // deposit to OD Contract give shares to user

    // approve router
    //IERC20(address(liquidityPool)).approve(router, shares);

    // CamelotRouterV2(router).removeLiquidity(
    //   liquidityPool.token0(), liquidityPool.token1(), shares, amount0Min, amount1Min, address(odProxy), block.timestamp
    //);

    return true;
  }

  /**
   * @notice Transfers the tokens to the ODProxy.
   * @param token Address of the token to transfer.
   * @param to Address of the recipient.
   * @param amount Amount of tokens to transfer.
   * @return True on success.
   */
  function ERC20TransferTo(address token, address to, uint256 amount) public onlyOwner returns (bool) {
    IERC20(token).transferFrom(address(this), to, amount);
    return true;
  }

  /**
   * @notice Transfers the NFT to the ODProxy.
   * @param token Address of the NFT to transfer.
   * @param to Address of the recipient.
   * @param tokenId ID of the NFT to transfer.
   * @return True on success.
   */
  function ERC721TransferTo(address token, address to, uint256 tokenId) public onlyOwner returns (bool) {
    IERC721(token).transferFrom(address(this), to, tokenId);
    return true;
  }

  // CamelotDex interface
  function onNFTAddToPosition(address operator, uint256 tokenId, uint256 lpAmount) external override returns (bool) {
    return true;
  }
  // CamelotDex interface

  function onNFTHarvest(
    address operator,
    address to,
    uint256 tokenId,
    uint256 grailAmount,
    uint256 xGrailAmount
  ) external override returns (bool) {
    return true;
  }

  // CamelotDex interface
  function onNFTWithdraw(address operator, uint256 tokenId, uint256 lpAmount) external override returns (bool) {
    return true;
  }

  // ERC721Receiver interface
  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  /**
   * @notice get the amount of the position
   * @param tokenId ID of the NFT representing the position.
   * @return amount of the position
   */
  function _getPositionAmountV2(uint256 tokenId) internal view returns (uint256 amount) {
    (amount,,,,,,,) = NFTPool(nftPool).getStakingPosition(tokenId);
  }

  /**
   * @notice get the liquidity of the position
   * @param tokenId ID of the NFT representing the position.
   * @return liquidity of the position
   */
  function _getPositionLiquidityV3(uint256 tokenId) internal view returns (uint128 liquidity) {
    (,,,,,, liquidity,,,,) = INonfungiblePositionManager(nftPool).positions(tokenId);
  }

  function _getLiquidityPool() internal view returns (address lpToken) {
    (lpToken,,,,,,,) = NFTPool(nftPool).getPoolInfo();
  }
}

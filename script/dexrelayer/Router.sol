// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAlgebraPool} from '@cryptoalgebra-core/interfaces/IAlgebraPool.sol';
import {IAlgebraMintCallback} from '@cryptoalgebra-core/interfaces/callback/IAlgebraMintCallback.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';

contract Router is IAlgebraMintCallback {
  IAlgebraPool public pool;
  IERC20 public tokenA;
  IERC20 public tokenB;
  address public owner;

  constructor(IAlgebraPool _pool, address _owner) {
    pool = _pool;
    owner = _owner;
    tokenA = IERC20(_pool.token0());
    tokenB = IERC20(_pool.token1());
  }

  function addLiquidity(
    int24 _bottomTick,
    int24 _topTick,
    uint128 _amount
  ) external returns (uint256 amount0, uint256 amount1, uint128 liquidityActual) {
    (amount0, amount1, liquidityActual) = pool.mint(owner, address(pool), _bottomTick, _topTick, _amount, '');
  }

  function algebraMintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external {
    require(address(pool) == msg.sender, 'Pool not authorized');
    tokenA.transferFrom(owner, address(pool), amount0Owed);
    tokenB.transferFrom(owner, address(pool), amount1Owed);
  }
}

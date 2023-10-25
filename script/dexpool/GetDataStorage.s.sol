// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {LiquidityBase} from '@script/dexpool/base/LiquidityBase.s.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IAlgebraPool} from '@cryptoalgebra-core/interfaces/IAlgebraPool.sol';
import {IAlgebraPoolState} from '@cryptoalgebra-core/interfaces/pool/IAlgebraPoolState.sol';
import {IDataStorageOperator} from '@cryptoalgebra-core/interfaces/IDataStorageOperator.sol';
import 'forge-std/console2.sol';

// BROADCAST
// source .env && forge script GetDataStorage --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script GetDataStorage --with-gas-price 2000000000 -vvvvv --rpc-url $GOERLI_RPC

contract GetDataStorage is LiquidityBase {
  uint256 private constant WAD = 1e18;
  address public pool;

  function run() public {
    vm.startBroadcast(vm.envUint('GOERLI_PK'));
    pool = algebraFactory.poolByPair(tokenA, tokenB);

    IERC20Metadata token0 = IERC20Metadata(IAlgebraPool(pool).token0());
    IERC20Metadata token1 = IERC20Metadata(IAlgebraPool(pool).token1());

    string memory token0Sym = token0.symbol();
    string memory token1Sym = token1.symbol();
    require(keccak256(abi.encodePacked('OD')) == keccak256(abi.encodePacked(token0Sym)), '!OD');
    require(keccak256(abi.encodePacked('wstETH')) == keccak256(abi.encodePacked(token1Sym)), '!wstETH');

    IDataStorageOperator operator = IDataStorageOperator(IAlgebraPool(pool).dataStorageOperator());

    (
      uint160 price,
      int24 tick,
      int24 prevInitializedTick,
      uint16 fee,
      uint16 timepointIndex,
      uint8 communityFee,
      bool unlocked
    ) = IAlgebraPool(pool).globalState();

    console2.logUint((uint256(price)));
    vm.stopBroadcast();
  }
}

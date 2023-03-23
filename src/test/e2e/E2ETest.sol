pragma solidity 0.8.19;

import {DSTest} from 'ds-test/test.sol';
import {Deploy, SAFEEngine, Coin, CoinJoin, ETHJoin} from '../../../script/Deploy.s.sol';

contract E2ETest is DSTest {
  Deploy public deployment;
  SAFEEngine public safeEngine;
  ETHJoin public collateralJoin;
  CoinJoin public coinJoin;
  Coin public coin;

  function setUp() public {
    deployment = new Deploy();
    deployment.run();

    safeEngine = deployment.safeEngine();
    collateralJoin = deployment.collateralJoin();
    coinJoin = deployment.coinJoin();
    coin = deployment.coin();
  }

  function testOpenSafe() public {
    collateralJoin.join{value: 1e18}(address(this));
    safeEngine.approveSAFEModification(address(collateralJoin));
    safeEngine.approveSAFEModification(address(coinJoin));

    safeEngine.modifySAFECollateralization({
      collateralType: deployment.COLLATERAL_TYPE(),
      safe: address(this),
      collateralSource: address(this),
      debtDestination: address(this),
      deltaCollateral: 1e18,
      deltaDebt: 0
    });

    safeEngine.modifySAFECollateralization({
      collateralType: deployment.COLLATERAL_TYPE(),
      safe: address(this),
      collateralSource: address(this),
      debtDestination: address(this),
      deltaCollateral: -0.1e18,
      deltaDebt: 1
    });

    coinJoin.exit(address(this), 1);

    assertEq(coin.balanceOf(address(this)), 1);
  }
}

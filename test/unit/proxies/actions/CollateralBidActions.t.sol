// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';
import {CollateralBidActions} from '@contracts/proxies/actions/CollateralBidActions.sol';
import {CoinJoinMock, SafeEngineMock} from './SurplusBidActions.t.sol';
import {CollateralJoinMock} from './GlobalSettlementActions.t.sol';

contract CollateralAuctionHouseMock {
  bool public wasBuyCollateralCalled;

  function reset() external {
    wasBuyCollateralCalled = false;
  }

  function buyCollateral(uint256 _auctionId, uint256 _bidAmount) external returns (uint256, uint256) {
    wasBuyCollateralCalled = true;
    return (1, 1);
  }
}

contract CollateralBidActionsTest is ActionBaseTest {
  CollateralBidActions collateralBidActions = new CollateralBidActions();
  CoinJoinMock coinJoin = new CoinJoinMock();
  CollateralAuctionHouseMock collateralAuctionHouse = new CollateralAuctionHouseMock();
  CollateralJoinMock collateralJoin = new CollateralJoinMock();

  function setUp() public {
    proxy = new ODProxy(alice);
  }

  function test_buyCollateral() public {
    coinJoin.reset();
    vm.startPrank(alice);
    coinJoin.systemCoin().approve(address(proxy), 10 ether);
    collateralJoin._mock_setSafeEngine(coinJoin.safeEngine());

    proxy.execute(
      address(collateralBidActions),
      abi.encodeWithSignature(
        'buyCollateral(address,address,address,uint256,uint256,uint256)',
        address(coinJoin),
        address(collateralJoin),
        address(collateralAuctionHouse),
        1,
        1,
        1
      )
    );

    assertTrue(collateralJoin.wasExitCalled());
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';
import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';
import {CoinJoinMock, SafeEngineMock} from './SurplusBidActions.t.sol';

contract CommonActionsPlaceholder is CommonActions {}

contract CommonActionsTest is ActionBaseTest {
  CommonActionsPlaceholder commonActions = new CommonActionsPlaceholder();
  CoinJoinMock coinJoin = new CoinJoinMock();

  function setUp() public {
    proxy = new ODProxy(alice);
  }

  function test_joinSystemCoins() public {
    coinJoin.reset();
    vm.startPrank(alice);

    coinJoin.systemCoin().approve(address(proxy), 10 ether);
    proxy.execute(
      address(commonActions),
      abi.encodeWithSignature('joinSystemCoins(address,address,uint256)', address(coinJoin), address(0x2), 10_000)
    );

    assertTrue(coinJoin.wasJoinCalled());
  }

  function test_exitSystemCoins() public {
    coinJoin.reset();
    vm.startPrank(alice);

    coinJoin.systemCoin().approve(address(proxy), 10 ether);
    proxy.execute(
      address(commonActions), abi.encodeWithSignature('exitSystemCoins(address,uint256)', address(coinJoin), 10_000)
    );

    assertTrue(coinJoin.wasExitCalled());
  }

  function test_exitAllSystemCoins() public {
    coinJoin.reset();
    vm.startPrank(alice);

    SafeEngineMock(coinJoin.safeEngine()).mock_setCoinBalance(10_000 ether);
    proxy.execute(address(commonActions), abi.encodeWithSignature('exitAllSystemCoins(address)', address(coinJoin)));

    assertTrue(coinJoin.wasExitCalled());
  }

  function test_exitCollateral() public {
    coinJoin.reset();
    vm.startPrank(alice);

    SafeEngineMock(coinJoin.safeEngine()).mock_setCoinBalance(10_000 ether);
    proxy.execute(
      address(commonActions), abi.encodeWithSignature('exitCollateral(address,uint256)', address(coinJoin), 10_000)
    );

    assertTrue(coinJoin.wasExitCalled());
  }
}

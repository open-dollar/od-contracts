// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';
import {GlobalSettlementActions} from '@contracts/proxies/actions/GlobalSettlementActions.sol';
import {
  SafeEngineMock, GlobalSettlementMock, ODSafeManagerMock, CollateralJoinMock
} from '@test/mocks/ActionsMocks.sol';

contract GlobalSettlementActionTest is ActionBaseTest {
  GlobalSettlementActions globalSettlementAction = new GlobalSettlementActions();
  GlobalSettlementMock globalSettlementMock = new GlobalSettlementMock();
  ODSafeManagerMock odSafeManagerMock = new ODSafeManagerMock();
  CollateralJoinMock collateralJoinMock = new CollateralJoinMock();

  function setUp() public {
    proxy = new ODProxy(alice);
    globalSettlementMock.reset();
    odSafeManagerMock.reset();
    collateralJoinMock.reset();
  }

  function test_freeCollateral() public {
    vm.startPrank(alice);
    odSafeManagerMock._mock_setSafeData(0, alice, alice, bytes32(0));
    odSafeManagerMock._mock_setCollateralBalance(100);

    proxy.execute(
      address(globalSettlementAction),
      abi.encodeWithSelector(
        globalSettlementAction.freeCollateral.selector,
        address(odSafeManagerMock),
        address(globalSettlementMock),
        address(0),
        0
      )
    );
    assertTrue(odSafeManagerMock.wasQuitSystemCalled());
  }

  function test_prepareCoinsForRedeeming() public {
    vm.startPrank(alice);
    odSafeManagerMock._mock_setSafeData(0, alice, alice, bytes32(0));
    odSafeManagerMock._mock_setCollateralBalance(100);

    SafeEngineMock safeEngineMock = SafeEngineMock(odSafeManagerMock.safeEngine());
    safeEngineMock.mock_setCoinBalance(100);
    globalSettlementMock._mock_setSafeEngine(address(safeEngineMock));

    proxy.execute(
      address(globalSettlementAction),
      abi.encodeWithSelector(
        globalSettlementAction.prepareCoinsForRedeeming.selector, address(globalSettlementMock), address(0), 0
      )
    );

    assertTrue(globalSettlementMock.wasPrepareCoinsForRedeemingCalled());
  }

  function test_redeemCollateral() public {
    vm.startPrank(alice);
    odSafeManagerMock._mock_setSafeData(0, alice, alice, bytes32(0));

    SafeEngineMock safeEngineMock = SafeEngineMock(odSafeManagerMock.safeEngine());

    safeEngineMock._mock_setCollateralBalance(100);
    safeEngineMock.mock_setCoinBalance(10_000);

    globalSettlementMock._mock_setSafeEngine(address(safeEngineMock));
    globalSettlementMock._mock_setCoinBag(100_000);
    globalSettlementMock._mock_setCoinsUsedToRedeem(5555);

    collateralJoinMock._mock_setSafeEngine(address(safeEngineMock));

    proxy.execute(
      address(globalSettlementAction),
      abi.encodeWithSelector(
        globalSettlementAction.redeemCollateral.selector, address(globalSettlementMock), address(collateralJoinMock), 0
      )
    );

    assertTrue(collateralJoinMock.wasExitCalled());
  }
}

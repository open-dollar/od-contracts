// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'forge-std/Test.sol';
import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';
import {BasicActions} from '@contracts/proxies/actions/BasicActions.sol';

import {ODSafeManagerMock, CoinJoinMock, SafeEngineMock, CollateralJoinMock} from '@test/mocks/ActionsMocks.sol';

contract BasicActionsTest is ActionBaseTest {
  BasicActions basicActions = new BasicActions();
  ODSafeManagerMock safeManager = new ODSafeManagerMock();
  CoinJoinMock coinJoin = new CoinJoinMock();
  CollateralJoinMock collateralJoin = new CollateralJoinMock();

  function setUp() public {
    proxy = new ODProxy(alice);
    safeManager.reset();
    coinJoin.reset();
    collateralJoin.reset();
  }

  function test_openSAFE() public {
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature('openSAFE(address,bytes32,address)', address(safeManager), bytes32(0), address(0))
    );

    assertTrue(safeManager.wasOpenSAFECalled());
  }

  function test_generateDebt() public {
    vm.startPrank(alice);
    SafeEngineMock(safeManager.safeEngine())._mock_setCollateralData(0, 0, 1, 0, 0);
    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'generateDebt(address,address,uint256,uint256)', address(safeManager), address(coinJoin), 1, 10
      )
    );

    assertTrue(coinJoin.wasExitCalled());
  }

  function test_allowSAFE() public {
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature('allowSAFE(address,uint256,address,bool)', address(safeManager), 1, address(0x01), true)
    );

    assertTrue(safeManager.wasAllowSAFECalled());
  }

  function test_modifySAFECollateralization() public {
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'modifySAFECollateralization(address,uint256,int256,int256)', address(safeManager), 1, 1, 1
      )
    );

    assertTrue(safeManager.wasModifySAFECollateralizationCalled());
  }

  function test_transferInternalCoins() public {
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'transferCollateral(address,uint256,address,uint256)', address(safeManager), 1, address(0x01), 1
      )
    );

    assertTrue(safeManager.wasTransferCollateralCalled());
  }

  function test_transferCollateral() public {
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'transferInternalCoins(address,uint256,address,uint256)', address(safeManager), 1, address(0x01), 1
      )
    );

    assertTrue(safeManager.wasTransferInteralCoinsCalled());
  }

  function test_quitSystem() public {
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions), abi.encodeWithSignature('quitSystem(address,uint256)', address(safeManager), 1)
    );

    assertTrue(safeManager.wasQuitSystemCalled());
  }

  function test_moveSafe() public {
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions), abi.encodeWithSignature('moveSAFE(address,uint256,uint256)', address(safeManager), 1, 1)
    );

    assertTrue(safeManager.wasMoveSAFECalled());
  }

  function test_addSAFE() public {
    vm.startPrank(alice);

    proxy.execute(address(basicActions), abi.encodeWithSignature('addSAFE(address,uint256)', address(safeManager), 1));

    assertTrue(safeManager.wasAddSAFECalled());
  }

  function test_removeSAFE() public {
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions), abi.encodeWithSignature('removeSAFE(address,uint256)', address(safeManager), 1)
    );

    assertTrue(safeManager.wasRemoveSAFECalled());
  }

  function test_protectSAFE() public {
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature('protectSAFE(address,uint256,address)', address(safeManager), 1, address(0x1))
    );

    assertTrue(safeManager.wasProtectSAFECalled());
  }

  function test_repayDebt() public {
    vm.startPrank(alice);
    coinJoin.systemCoin().approve(address(proxy), 10 ether);
    SafeEngineMock(safeManager.safeEngine())._mock_setCollateralData(0, 0, 1, 0, 0);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'repayDebt(address,address,uint256,uint256)', address(safeManager), address(coinJoin), 1, 1
      )
    );

    assertTrue(safeManager.wasModifySAFECollateralizationCalled());
  }

  function test_lockTokenCollateral() public {
    vm.startPrank(alice);
    coinJoin.systemCoin().approve(address(proxy), 10 ether);
    collateralJoin._mock_setCollateralToken(address(coinJoin.systemCoin()));

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'lockTokenCollateral(address,address,uint256,uint256)', address(safeManager), address(collateralJoin), 1, 1
      )
    );

    assertTrue(safeManager.wasModifySAFECollateralizationCalled());
  }

  function test_repayAllDebt() public {
    vm.startPrank(alice);
    coinJoin.systemCoin().approve(address(proxy), 10 ether);
    SafeEngineMock(safeManager.safeEngine())._mock_setCollateralData(0, 0, 1, 0, 0);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature('repayAllDebt(address,address,uint256)', address(safeManager), address(coinJoin), 1)
    );

    assertTrue(safeManager.wasModifySAFECollateralizationCalled());
  }

  function test_lockTokenCollateralAndGenerateDebt() public {
    vm.startPrank(alice);
    coinJoin.systemCoin().approve(address(proxy), 10 ether);
    collateralJoin._mock_setCollateralToken(address(coinJoin.systemCoin()));
    SafeEngineMock(safeManager.safeEngine())._mock_setCollateralData(0, 0, 1, 0, 0);
    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'lockTokenCollateralAndGenerateDebt(address,address,address,uint256,uint256,uint256)',
        address(safeManager),
        address(collateralJoin),
        address(coinJoin),
        1,
        1,
        1
      )
    );

    assertTrue(safeManager.wasModifySAFECollateralizationCalled());
  }

  function test_openLockTokenCollateralAndGenerateDebt() public {
    vm.startPrank(alice);
    coinJoin.systemCoin().approve(address(proxy), 10 ether);
    collateralJoin._mock_setCollateralToken(address(coinJoin.systemCoin()));
    SafeEngineMock(safeManager.safeEngine())._mock_setCollateralData(0, 0, 1, 0, 0);
    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'openLockTokenCollateralAndGenerateDebt(address,address,address,bytes32,uint256,uint256)',
        address(safeManager),
        address(collateralJoin),
        address(coinJoin),
        0,
        1,
        1
      )
    );

    assertTrue(safeManager.wasModifySAFECollateralizationCalled());
  }

  function test_repayDebtAndFreeTokenCollateral() public {
    vm.startPrank(alice);
    coinJoin.systemCoin().approve(address(proxy), 10 ether);
    collateralJoin._mock_setCollateralToken(address(coinJoin.systemCoin()));
    SafeEngineMock(safeManager.safeEngine())._mock_setCollateralData(0, 0, 1, 0, 0);
    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'repayDebtAndFreeTokenCollateral(address,address,address,uint256,uint256,uint256)',
        address(safeManager),
        address(coinJoin),
        address(collateralJoin),
        1,
        1,
        1
      )
    );

    assertTrue(safeManager.wasModifySAFECollateralizationCalled());
  }

  function test_repayAllDebtAndFreeTokenCollateral() public {
    vm.startPrank(alice);
    coinJoin.systemCoin().approve(address(proxy), 10 ether);
    collateralJoin._mock_setCollateralToken(address(coinJoin.systemCoin()));
    SafeEngineMock(safeManager.safeEngine())._mock_setCollateralData(0, 0, 1, 0, 0);
    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'repayAllDebtAndFreeTokenCollateral(address,address,address,uint256,uint256)',
        address(safeManager),
        address(coinJoin),
        address(collateralJoin),
        1,
        1
      )
    );

    assertTrue(safeManager.wasModifySAFECollateralizationCalled());
  }

  function test_collectTokenCollateral() public {
    vm.startPrank(alice);
    coinJoin.systemCoin().approve(address(proxy), 10 ether);
    collateralJoin._mock_setCollateralToken(address(coinJoin.systemCoin()));
    collateralJoin._mock_setSafeEngine(safeManager.safeEngine());
    SafeEngineMock(safeManager.safeEngine())._mock_setCollateralData(0, 0, 1, 0, 0);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'collectTokenCollateral(address,address,uint256,uint256)', address(safeManager), address(collateralJoin), 1, 1
      )
    );
    assertTrue(collateralJoin.wasExitCalled());
  }
}

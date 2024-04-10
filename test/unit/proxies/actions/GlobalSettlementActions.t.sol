// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';

// Mock for testing ODProxy -> GlobalSettlementAction
contract GlobalSettlementActionMock {
  address public manager;
  address public globalSettlement;
  address public collateralJoin;
  uint256 public safeId;
  address public coinJoin;
  uint256 public coinAmount;

  function freeCollateral(
    address _manager,
    address _globalSettlement,
    address _collateralJoin,
    uint256 _safeId
  ) external returns (uint256 _collateralAmount) {
    manager = _manager;
    globalSettlement = _globalSettlement;
    collateralJoin = _collateralJoin;
    safeId = _safeId;

    return 2024;
  }

  function prepareCoinsForRedeeming(address _globalSettlement, address _coinJoin, uint256 _coinAmount) external {
    globalSettlement = _globalSettlement;
    coinJoin = _coinJoin;
    coinAmount = _coinAmount;
  }

  function redeemCollateral(
    address _globalSettlement,
    address _collateralJoin
  ) external returns (uint256 _collateralAmount) {
    globalSettlement = _globalSettlement;
    collateralJoin = _collateralJoin;

    return 2024;
  }
}

// Testing the calls from ODProxy to GlobalSettlementAction.
// In this test we don't care about the actual implementation of SurplusBidAction, only that the calls are made correctly
contract GlobalSettlementActionTest is ActionBaseTest {
  GlobalSettlementActionMock globalSettlementAction;

  function setUp() public {
    proxy = new ODProxy(alice);
    globalSettlementAction = new GlobalSettlementActionMock();
  }

  function test_freeCollateral() public {
    vm.startPrank(alice);
    address target = address(globalSettlementAction);
    address manager = address(0x123);
    address globalSettlement = address(0x456);
    address collateralJoin = address(0x789);
    uint256 safeId = 123;

    proxy.execute(
      target,
      abi.encodeWithSignature(
        'freeCollateral(address,address,address,uint256)', manager, globalSettlement, collateralJoin, safeId
      )
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    address savedDataGlobalSettlement =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('globalSettlement()')));
    address savedDataCollateralJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('collateralJoin()')));
    uint256 savedDataSafeId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeId()')));

    assertEq(savedDataManager, manager);
    assertEq(savedDataGlobalSettlement, globalSettlement);
    assertEq(savedDataCollateralJoin, collateralJoin);
    assertEq(savedDataSafeId, safeId);
  }

  function test_prepareCoinsForRedeeming() public {
    vm.startPrank(alice);
    address target = address(globalSettlementAction);
    address globalSettlement = address(0x123);
    address coinJoin = address(0x456);
    uint256 coinAmount = 123;

    proxy.execute(
      target,
      abi.encodeWithSignature(
        'prepareCoinsForRedeeming(address,address,uint256)', globalSettlement, coinJoin, coinAmount
      )
    );

    address savedDataGlobalSettlement =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('globalSettlement()')));
    address savedDataCoinJoin = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
    uint256 savedDataCoinAmount = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('coinAmount()')));

    assertEq(savedDataGlobalSettlement, globalSettlement);
    assertEq(savedDataCoinJoin, coinJoin);
    assertEq(savedDataCoinAmount, coinAmount);
  }

  function test_redeemCollateral() public {
    vm.startPrank(alice);
    address target = address(globalSettlementAction);
    address globalSettlement = address(0x123);
    address collateralJoin = address(0x456);

    proxy.execute(
      target, abi.encodeWithSignature('redeemCollateral(address,address)', globalSettlement, collateralJoin)
    );

    address savedDataGlobalSettlement =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('globalSettlement()')));
    address savedDataCollateralJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('collateralJoin()')));

    assertEq(savedDataGlobalSettlement, globalSettlement);
    assertEq(savedDataCollateralJoin, collateralJoin);
  }
}

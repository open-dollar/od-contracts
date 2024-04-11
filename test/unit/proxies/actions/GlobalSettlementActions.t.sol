// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';
import {IODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {GlobalSettlementActions} from '@contracts/proxies/actions/GlobalSettlementActions.sol';
import {SafeEngineMock} from './SurplusBidActions.t.sol';


contract ODSafeManagerMock {

  IODSafeManager.SAFEData public safeDataPoint;
  address public safeEngine;

  bool public wasQuitSystemCalled;
  uint256 public collateralBalance;

  constructor() {
    safeEngine = address(new SafeEngineMock());
  }

  function reset() external {
    safeDataPoint = IODSafeManager.SAFEData(0, address(0), address(0), bytes32(0));
    wasQuitSystemCalled = false;

  }

  function _mock_setSafeData(
    uint96 _nonce,
    address _owner,
    address _safeHandler,
    bytes32 _collateralType
  ) external {
    safeDataPoint = IODSafeManager.SAFEData(_nonce, _owner, _safeHandler, _collateralType);
  }

  function _mock_setCollateralBalance(uint256 _collateralBalance) external {
    collateralBalance = _collateralBalance;
  }

  function safeData(uint256 _safe) external view returns (IODSafeManager.SAFEData memory _sData) {
    return safeDataPoint;
  }

  function quitSystem(uint256 _safe, address _dst) external {
    wasQuitSystemCalled = true;
  }

  function tokenCollateral(bytes32 _cType, address _account) external view returns (uint256 _collateralBalance) {
    return collateralBalance;
  }
}

contract GlobalSettlementMock {

  bool public wasProcessSAFECalled;
  bool public wasFreeCollateralCalled;
  bool public wasPrepareCoinsForRedeemingCalled;
  address public safeEngine;

  function reset() external {
    wasProcessSAFECalled = false;
    wasFreeCollateralCalled = false;
    wasPrepareCoinsForRedeemingCalled = false;
  }

  function _mock_setSafeEngine(address _safeEngine) external {
    safeEngine = _safeEngine;
  }

  function processSAFE(bytes32 _cType, address _safe) external {
    wasProcessSAFECalled = true;
  }

  function freeCollateral(bytes32 _cType) external {
    wasFreeCollateralCalled = true;
  }

  function prepareCoinsForRedeeming(uint256 _coinAmount) external {
    wasPrepareCoinsForRedeemingCalled = true;
  }
}

// Testing the calls from ODProxy to GlobalSettlementAction.
// In this test we don't care about the actual implementation of SurplusBidAction, only that the calls are made correctly
contract GlobalSettlementActionTest is ActionBaseTest {

  GlobalSettlementActions globalSettlementAction = new GlobalSettlementActions();
  GlobalSettlementMock globalSettlementMock = new GlobalSettlementMock();
  ODSafeManagerMock odSafeManagerMock = new ODSafeManagerMock();

  function setUp() public {
    proxy = new ODProxy(alice);
  }

  function test_freeCollateral() public {
    globalSettlementMock.reset();
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
    globalSettlementMock.reset();
    vm.startPrank(alice);
    odSafeManagerMock._mock_setSafeData(0, alice, alice, bytes32(0));
    odSafeManagerMock._mock_setCollateralBalance(100);

    SafeEngineMock safeEngineMock = SafeEngineMock(odSafeManagerMock.safeEngine());
    safeEngineMock.mock_setCoinBalance(100);
    globalSettlementMock._mock_setSafeEngine(address(safeEngineMock));

    proxy.execute(
      address(globalSettlementAction),
      abi.encodeWithSelector(
        globalSettlementAction.prepareCoinsForRedeeming.selector,
        address(globalSettlementMock),
        address(0),
        0
      )
    );
    
    assertTrue(globalSettlementMock.wasPrepareCoinsForRedeemingCalled());
  }
}

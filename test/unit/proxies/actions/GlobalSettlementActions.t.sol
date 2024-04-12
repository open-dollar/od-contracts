// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';
import {IODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {GlobalSettlementActions} from '@contracts/proxies/actions/GlobalSettlementActions.sol';
import {SafeEngineMock} from './SurplusBidActions.t.sol';

contract CollateralJoinMock {
  bool public wasJoinCalled;
  bool public wasExitCalled;
  bytes32 public collateralType;

  address public safeEngine;

  function reset() external {
    wasJoinCalled = false;
    wasExitCalled = false;
    collateralType = bytes32(0);
  }

  function _mock_setCollateralType(bytes32 _collateralType) external {
    collateralType = _collateralType;
  }

  function _mock_setSafeEngine(address _safeEngine) external {
    safeEngine = _safeEngine;
  }

  function join(address _account, uint256 _wei) external {
    wasJoinCalled = true;
  }

  function exit(address _account, uint256 _wei) external {
    wasExitCalled = true;
  }

  function decimals() external view returns (uint256) {
    return 18;
  }
}

contract ODSafeManagerMock {
  IODSafeManager.SAFEData public safeDataPoint;
  ISAFEEngine.SAFEEngineCollateralData public collateralDataPoint;
  address public safeEngine;

  bool public wasQuitSystemCalled;
  bool public wasOpenSAFECalled;
  bool public wasEnterSystemCalled;
  bool public wasAllowSAFECalled;
  bool public wasMoveSAFECalled;
  bool public wasAddSAFECalled;
  bool public wasRemoveSAFECalled;
  bool public wasProtectSAFECalled;
  bool public wasModifySAFECollateralizationCalled;
  bool public wasTransferCollateralCalled;
  bool public wasTaxCollectorTaxSingleCalled;
  bool public wasTransferInteralCoinsCalled;
  uint256 public collateralBalance;
  uint256 public safeId;

  constructor() {
    safeEngine = address(new SafeEngineMock());
  }

  function reset() external {
    safeDataPoint = IODSafeManager.SAFEData(0, address(0), address(0), bytes32(0));
    safeId = 0;
    wasQuitSystemCalled = false;
    wasOpenSAFECalled = false;
    wasAllowSAFECalled = false;
    wasEnterSystemCalled = false;
    wasMoveSAFECalled = false;
    wasAddSAFECalled = false;
    wasRemoveSAFECalled = false;
    wasProtectSAFECalled = false;
    wasModifySAFECollateralizationCalled = false;
    wasTransferCollateralCalled = false;
    wasTransferInteralCoinsCalled = false;
    wasTaxCollectorTaxSingleCalled = false;
    collateralBalance = 0;
  }

  function _mock_setSafeData(uint96 _nonce, address _owner, address _safeHandler, bytes32 _collateralType) external {
    safeDataPoint = IODSafeManager.SAFEData(_nonce, _owner, _safeHandler, _collateralType);
  }

  function _mock_setCollateralBalance(uint256 _collateralBalance) external {
    collateralBalance = _collateralBalance;
  }

  function _mock_setSafeId(uint256 _safeId) external {
    safeId = _safeId;
  }

  function safeData(uint256 _safe) external view returns (IODSafeManager.SAFEData memory _sData) {
    return safeDataPoint;
  }

  function quitSystem(uint256 _safe, address _dst) external {
    wasQuitSystemCalled = true;
  }

  function enterSystem(address _src, uint256 _safe) external {
    wasEnterSystemCalled = true;
  }

  function tokenCollateral(bytes32 _cType, address _account) external view returns (uint256 _collateralBalance) {
    return collateralBalance;
  }

  function openSAFE(bytes32 _cType, address _usr) external returns (uint256 _id) {
    wasOpenSAFECalled = true;
    return safeId;
  }

  function allowSAFE(uint256 _safe, address _usr, bool _ok) external {
    wasAllowSAFECalled = true;
  }

  function moveSAFE(uint256 _safeSrc, uint256 _safeDst) external {
    wasMoveSAFECalled = true;
  }

  function addSAFE(uint256 _safe) external {
    wasAddSAFECalled = true;
  }

  function removeSAFE(uint256 _safe) external {
    wasRemoveSAFECalled = true;
  }

  function protectSAFE(uint256 _safe, address _handler) external {
    wasProtectSAFECalled = true;
  }

  function modifySAFECollateralization(
    uint256 _safe,
    int256 _deltaCollateral,
    int256 _deltaDebt,
    bool _nonSafeHandlerAddress
  ) external {
    wasModifySAFECollateralizationCalled = true;
  }

  function transferCollateral(uint256 _safe, address _dst, uint256 _wad) external {
    wasTransferCollateralCalled = true;
  }

  function transferInternalCoins(uint256 _safe, address _dst, uint256 _rad) external {
    wasTransferInteralCoinsCalled = true;
  }

  function taxCollector() external view returns (address) {
    return address(this);
  }

  function taxSingle(bytes32 _cType) external returns (uint256 _latestAccumulatedRate) {
    wasTaxCollectorTaxSingleCalled = true;
    return 0;
  }
}

contract GlobalSettlementMock {
  bool public wasProcessSAFECalled;
  bool public wasFreeCollateralCalled;
  bool public wasPrepareCoinsForRedeemingCalled;
  bool public wasRedeemCollateralCalled;

  uint256 public coinBagPoint;
  uint256 public coinsUsedToRedeemPoint;

  address public safeEngine;

  function reset() external {
    wasProcessSAFECalled = false;
    wasFreeCollateralCalled = false;
    wasPrepareCoinsForRedeemingCalled = false;
    wasRedeemCollateralCalled = false;
    coinBagPoint = 0;
    coinsUsedToRedeemPoint = 0;
  }

  function _mock_setSafeEngine(address _safeEngine) external {
    safeEngine = _safeEngine;
  }

  function _mock_setCoinBag(uint256 _coinBag) external {
    coinBagPoint = _coinBag;
  }

  function _mock_setCoinsUsedToRedeem(uint256 _coinsUsedToRedeem) external {
    coinsUsedToRedeemPoint = _coinsUsedToRedeem;
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

  function coinBag(address _coinHolder) external view returns (uint256 _coinBag) {
    return coinBagPoint;
  }

  function coinsUsedToRedeem(bytes32 _cType, address _coinHolder) external view returns (uint256 _coinsUsedToRedeem) {
    return coinsUsedToRedeemPoint;
  }

  function redeemCollateral(bytes32 _cType, uint256 _coinsAmount) external {
    wasRedeemCollateralCalled = true;
  }
}

// Testing the calls from ODProxy to GlobalSettlementAction.
// In this test we don't care about the actual implementation of SurplusBidAction, only that the calls are made correctly
contract GlobalSettlementActionTest is ActionBaseTest {
  GlobalSettlementActions globalSettlementAction = new GlobalSettlementActions();
  GlobalSettlementMock globalSettlementMock = new GlobalSettlementMock();
  ODSafeManagerMock odSafeManagerMock = new ODSafeManagerMock();
  CollateralJoinMock collateralJoinMock = new CollateralJoinMock();

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
        globalSettlementAction.prepareCoinsForRedeeming.selector, address(globalSettlementMock), address(0), 0
      )
    );

    assertTrue(globalSettlementMock.wasPrepareCoinsForRedeemingCalled());
  }

  function test_redeemCollateral() public {
    globalSettlementMock.reset();
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

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {ActionBaseTest, ODProxy} from './ActionBaseTest.sol';

contract BasicActionsMock {
  address public manager;
  address public coinJoin;
  address public collateralJoin;
  bytes32 public cType;
  address public usr;
  uint256 public safeId;
  uint256 public deltaWad;
  bool public ok;
  int256 public deltaCollateral;
  int256 public deltaDebt;
  address public saviour;
  uint256 public collateralAmount;
  uint256 public debtWad;
  uint256 public collateralWad;
  address public dst;
  uint256 public rad;
  address public src;
  uint256 public safe;
  uint256 public safeSrc;
  uint256 public safeDst;

  function openSAFE(address _manager, bytes32 _cType, address _usr) external returns (uint256 _safeId) {
    manager = _manager;
    cType = _cType;
    usr = _usr;
    return 2024;
  }

  function generateDebt(address _manager, address _coinJoin, uint256 _safeId, uint256 _deltaWad) external {
    manager = _manager;
    coinJoin = _coinJoin;
    safeId = _safeId;
    deltaWad = _deltaWad;
  }

  function allowSAFE(address _manager, uint256 _safeId, address _usr, bool _ok) external {
    manager = _manager;
    safeId = _safeId;
    usr = _usr;
    ok = _ok;
  }

  function modifySAFECollateralization(
    address _manager,
    uint256 _safeId,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) external {
    manager = _manager;
    safeId = _safeId;
    deltaCollateral = _deltaCollateral;
    deltaDebt = _deltaDebt;
  }

  function transferCollateral(address _manager, uint256 _safeId, address _dst, uint256 _deltaWad) external {
    manager = _manager;
    safeId = _safeId;
    dst = _dst;
    deltaWad = _deltaWad;
  }

  function transferInternalCoins(address _manager, uint256 _safeId, address _dst, uint256 _rad) external {
    manager = _manager;
    safeId = _safeId;
    dst = _dst;
    rad = _rad;
  }

  function quitSystem(address _manager, uint256 _safeId, address _dst) external {
    manager = _manager;
    safeId = _safeId;
    dst = _dst;
  }

  function enterSystem(address _manager, address _src, uint256 _safeId) external {
    manager = _manager;
    src = _src;
    safeId = _safeId;
  }

  function moveSAFE(address _manager, uint256 _safeSrc, uint256 _safeDst) external {
    manager = _manager;
    safeSrc = _safeSrc;
    safeDst = _safeDst;
  }

  function addSAFE(address _manager, uint256 _safe) external {
    manager = _manager;
    safe = _safe;
  }

  function removeSAFE(address _manager, uint256 _safe) external {
    manager = _manager;
    safe = _safe;
  }

  function protectSAFE(address _manager, uint256 _safe, address _saviour) external {
    manager = _manager;
    safe = _safe;
    saviour = _saviour;
  }

  function repayDebt(address _manager, address _coinJoin, uint256 _safeId, uint256 _deltaWad) external {
    manager = _manager;
    coinJoin = _coinJoin;
    safeId = _safeId;
    deltaWad = _deltaWad;
  }

  function lockTokenCollateral(address _manager, address _collateralJoin, uint256 _safeId, uint256 _deltaWad) external {
    manager = _manager;
    collateralJoin = _collateralJoin;
    safeId = _safeId;
    deltaWad = _deltaWad;
  }

  function freeTokenCollateral(address _manager, address _collateralJoin, uint256 _safeId, uint256 _deltaWad) external {
    manager = _manager;
    collateralJoin = _collateralJoin;
    safeId = _safeId;
    deltaWad = _deltaWad;
  }

  function repayAllDebt(address _manager, address _coinJoin, uint256 _safeId) external {
    manager = _manager;
    coinJoin = _coinJoin;
    safeId = _safeId;
  }

  function lockTokenCollateralAndGenerateDebt(
    address _manager,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safe,
    uint256 _collateralAmount,
    uint256 _deltaWad
  ) external {
    manager = _manager;
    collateralJoin = _collateralJoin;
    coinJoin = _coinJoin;
    safe = _safe;
    collateralAmount = _collateralAmount;
    deltaWad = _deltaWad;
  }

  function openLockTokenCollateralAndGenerateDebt(
    address _manager,
    address _collateralJoin,
    address _coinJoin,
    bytes32 _cType,
    uint256 _collateralAmount,
    uint256 _deltaWad
  ) external returns (uint256 _safe) {
    manager = _manager;
    collateralJoin = _collateralJoin;
    coinJoin = _coinJoin;
    cType = _cType;
    collateralAmount = _collateralAmount;
    deltaWad = _deltaWad;
    return 2024;
  }

  function repayDebtAndFreeTokenCollateral(
    address _manager,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safeId,
    uint256 _collateralWad,
    uint256 _debtWad
  ) external {
    manager = _manager;
    collateralJoin = _collateralJoin;
    coinJoin = _coinJoin;
    safeId = _safeId;
    collateralWad = _collateralWad;
    debtWad = _debtWad;
  }

  function repayAllDebtAndFreeTokenCollateral(
    address _manager,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safeId,
    uint256 _collateralWad
  ) external {
    manager = _manager;
    collateralJoin = _collateralJoin;
    coinJoin = _coinJoin;
    safeId = _safeId;
    collateralWad = _collateralWad;
  }

  function collectTokenCollateral(
    address _manager,
    address _collateralJoin,
    uint256 _safeId,
    uint256 _deltaWad
  ) external {
    manager = _manager;
    collateralJoin = _collateralJoin;
    safeId = _safeId;
    deltaWad = _deltaWad;
  }
}

contract BasicActionsTest is ActionBaseTest {
  BasicActionsMock basicActions;

  function setUp() public {
    proxy = new ODProxy(alice);
    basicActions = new BasicActionsMock();
  }

  function test_openSAFE() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    bytes32 _cType = bytes32(uint256(1));
    address _usr = address(0x789);
    vm.startPrank(alice);

    uint256 safeId = decodeAsUint256(
      proxy.execute(target, abi.encodeWithSignature('openSAFE(address,bytes32,address)', _manager, _cType, _usr))
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    bytes32 savedDataCType = decodeAsBytes32(proxy.execute(target, abi.encodeWithSignature('cType()')));
    address savedDataUsr = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('usr()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataCType, _cType);
    assertEq(savedDataUsr, _usr);
    assertEq(safeId, 2024);
  }

  function test_generateDebt() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    address _coinJoin = address(0x456);
    uint256 _safeId = 123;
    uint256 _deltaWad = 1000;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature('generateDebt(address,address,uint256,uint256)', _manager, _coinJoin, _safeId, _deltaWad)
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    address savedDataCoinJoin = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
    uint256 savedDataSafeId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeId()')));
    uint256 savedDataDeltaWad = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('deltaWad()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataCoinJoin, _coinJoin);
    assertEq(savedDataSafeId, _safeId);
    assertEq(savedDataDeltaWad, _deltaWad);
  }

  function test_allowSAFE() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    uint256 _safeId = 123;
    address _usr = address(0x456);
    bool _ok = true;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature('allowSAFE(address,uint256,address,bool)', _manager, _safeId, _usr, _ok)
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    uint256 savedDataSafeId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeId()')));
    address savedDataUsr = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('usr()')));
    bool savedDataOk = decodeAsBool(proxy.execute(target, abi.encodeWithSignature('ok()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataSafeId, _safeId);
    assertEq(savedDataUsr, _usr);
    assertEq(savedDataOk, _ok);
  }

  function test_modifySAFECollateralization() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    uint256 _safeId = 123;
    int256 _deltaCollateral = 1000;
    int256 _deltaDebt = 2000;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'modifySAFECollateralization(address,uint256,int256,int256)', _manager, _safeId, _deltaCollateral, _deltaDebt
      )
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    uint256 savedDataSafeId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeId()')));
    int256 savedDataDeltaCollateral =
      decodeAsInt256(proxy.execute(target, abi.encodeWithSignature('deltaCollateral()')));
    int256 savedDataDeltaDebt = decodeAsInt256(proxy.execute(target, abi.encodeWithSignature('deltaDebt()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataSafeId, _safeId);
    assertEq(savedDataDeltaCollateral, _deltaCollateral);
    assertEq(savedDataDeltaDebt, _deltaDebt);
  }

  function test_transferCollateral() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    uint256 _safeId = 123;
    address _dst = address(0x456);
    uint256 _deltaWad = 1000;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature('transferCollateral(address,uint256,address,uint256)', _manager, _safeId, _dst, _deltaWad)
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    uint256 savedDataSafeId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeId()')));
    address savedDataDst = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('dst()')));
    uint256 savedDataDeltaWad = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('deltaWad()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataSafeId, _safeId);
    assertEq(savedDataDst, _dst);
    assertEq(savedDataDeltaWad, _deltaWad);
  }

  function test_transferInternalCoins() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    uint256 _safeId = 123;
    address _dst = address(0x456);
    uint256 _rad = 1000;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature('transferInternalCoins(address,uint256,address,uint256)', _manager, _safeId, _dst, _rad)
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    uint256 savedDataSafeId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeId()')));
    address savedDataDst = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('dst()')));
    uint256 savedDataRad = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('rad()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataSafeId, _safeId);
    assertEq(savedDataDst, _dst);
    assertEq(savedDataRad, _rad);
  }

  function test_quitSystem() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    uint256 _safeId = 123;
    address _dst = address(0x456);
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions), abi.encodeWithSignature('quitSystem(address,uint256,address)', _manager, _safeId, _dst)
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    uint256 savedDataSafeId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeId()')));
    address savedDataDst = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('dst()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataSafeId, _safeId);
    assertEq(savedDataDst, _dst);
  }

  function test_enterSystem() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    address _src = address(0x456);
    uint256 _safeId = 123;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions), abi.encodeWithSignature('enterSystem(address,address,uint256)', _manager, _src, _safeId)
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    address savedDataSrc = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('src()')));
    uint256 savedDataSafeId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeId()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataSrc, _src);
    assertEq(savedDataSafeId, _safeId);
  }

  function test_moveSAFE() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    uint256 _safeSrc = 123;
    uint256 _safeDst = 456;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions), abi.encodeWithSignature('moveSAFE(address,uint256,uint256)', _manager, _safeSrc, _safeDst)
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    uint256 savedDataSrc = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeSrc()')));
    uint256 savedDataDst = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeDst()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataSrc, _safeSrc);
    assertEq(savedDataDst, _safeDst);
  }

  function test_addSAFE() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    uint256 _safe = 123;
    vm.startPrank(alice);

    proxy.execute(address(basicActions), abi.encodeWithSignature('addSAFE(address,uint256)', _manager, _safe));

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    uint256 savedDataSafe = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safe()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataSafe, _safe);
  }

  function test_removeSAFE() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    uint256 _safe = 123;
    vm.startPrank(alice);

    proxy.execute(address(basicActions), abi.encodeWithSignature('removeSAFE(address,uint256)', _manager, _safe));

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    uint256 savedDataSafe = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safe()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataSafe, _safe);
  }

  function test_protectSAFE() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    uint256 _safe = 123;
    address _saviour = address(0x456);
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions), abi.encodeWithSignature('protectSAFE(address,uint256,address)', _manager, _safe, _saviour)
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    uint256 savedDataSafe = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safe()')));
    address savedDataSaviour = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('saviour()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataSafe, _safe);
    assertEq(savedDataSaviour, _saviour);
  }

  function test_repayDebt() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    address _coinJoin = address(0x456);
    uint256 _safeId = 123;
    uint256 _deltaWad = 1000;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature('repayDebt(address,address,uint256,uint256)', _manager, _coinJoin, _safeId, _deltaWad)
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    address savedDataCoinJoin = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
    uint256 savedDataSafeId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeId()')));
    uint256 savedDataDeltaWad = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('deltaWad()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataCoinJoin, _coinJoin);
    assertEq(savedDataSafeId, _safeId);
    assertEq(savedDataDeltaWad, _deltaWad);
  }

  function test_lockTokenCollateral() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    address _collateralJoin = address(0x456);
    uint256 _safeId = 123;
    uint256 _deltaWad = 1000;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'lockTokenCollateral(address,address,uint256,uint256)', _manager, _collateralJoin, _safeId, _deltaWad
      )
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    address savedDataCollateralJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('collateralJoin()')));
    uint256 savedDataSafeId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeId()')));
    uint256 savedDataDeltaWad = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('deltaWad()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataCollateralJoin, _collateralJoin);
    assertEq(savedDataSafeId, _safeId);
    assertEq(savedDataDeltaWad, _deltaWad);
  }

  function test_freeTokenCollateral() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    address _collateralJoin = address(0x456);
    uint256 _safeId = 123;
    uint256 _deltaWad = 1000;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'freeTokenCollateral(address,address,uint256,uint256)', _manager, _collateralJoin, _safeId, _deltaWad
      )
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    address savedDataCollateralJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('collateralJoin()')));
    uint256 savedDataSafeId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeId()')));
    uint256 savedDataDeltaWad = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('deltaWad()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataCollateralJoin, _collateralJoin);
    assertEq(savedDataSafeId, _safeId);
    assertEq(savedDataDeltaWad, _deltaWad);
  }

  function test_repayAllDebt() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    address _coinJoin = address(0x456);
    uint256 _safeId = 123;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature('repayAllDebt(address,address,uint256)', _manager, _coinJoin, _safeId)
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    address savedDataCoinJoin = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
    uint256 savedDataSafeId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeId()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataCoinJoin, _coinJoin);
    assertEq(savedDataSafeId, _safeId);
  }

  function test_lockTokenCollateralAndGenerateDebt() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    address _collateralJoin = address(0x456);
    address _coinJoin = address(0x789);
    uint256 _safe = 123;
    uint256 _collateralAmount = 1000;
    uint256 _deltaWad = 2000;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'lockTokenCollateralAndGenerateDebt(address,address,address,uint256,uint256,uint256)',
        _manager,
        _collateralJoin,
        _coinJoin,
        _safe,
        _collateralAmount,
        _deltaWad
      )
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    address savedDataCollateralJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('collateralJoin()')));
    address savedDataCoinJoin = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
    uint256 savedDataSafe = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safe()')));
    uint256 savedDataCollateralAmount =
      decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('collateralAmount()')));
    uint256 savedDataDeltaWad = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('deltaWad()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataCollateralJoin, _collateralJoin);
    assertEq(savedDataCoinJoin, _coinJoin);
    assertEq(savedDataSafe, _safe);
    assertEq(savedDataCollateralAmount, _collateralAmount);
    assertEq(savedDataDeltaWad, _deltaWad);
  }

  function test_openLockTokenCollateralAndGenerateDebt() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    address _collateralJoin = address(0x456);
    address _coinJoin = address(0x789);
    bytes32 _cType = bytes32(uint256(1));
    uint256 _collateralAmount = 1000;
    uint256 _deltaWad = 2000;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'openLockTokenCollateralAndGenerateDebt(address,address,address,bytes32,uint256,uint256)',
        _manager,
        _collateralJoin,
        _coinJoin,
        _cType,
        _collateralAmount,
        _deltaWad
      )
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    address savedDataCollateralJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('collateralJoin()')));
    address savedDataCoinJoin = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
    bytes32 savedDataCType = decodeAsBytes32(proxy.execute(target, abi.encodeWithSignature('cType()')));
    uint256 savedDataCollateralAmount =
      decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('collateralAmount()')));
    uint256 savedDataDeltaWad = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('deltaWad()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataCollateralJoin, _collateralJoin);
    assertEq(savedDataCoinJoin, _coinJoin);
    assertEq(savedDataCType, _cType);
    assertEq(savedDataCollateralAmount, _collateralAmount);
    assertEq(savedDataDeltaWad, _deltaWad);
  }

  function test_repayDebtAndFreeTokenCollateral() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    address _collateralJoin = address(0x456);
    address _coinJoin = address(0x789);
    uint256 _safeId = 123;
    uint256 _collateralWad = 1000;
    uint256 _debtWad = 2000;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'repayDebtAndFreeTokenCollateral(address,address,address,uint256,uint256,uint256)',
        _manager,
        _collateralJoin,
        _coinJoin,
        _safeId,
        _collateralWad,
        _debtWad
      )
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    address savedDataCollateralJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('collateralJoin()')));
    address savedDataCoinJoin = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
    uint256 savedDataSafeId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeId()')));
    uint256 savedDataCollateralWad = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('collateralWad()')));
    uint256 savedDataDebtWad = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('debtWad()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataCollateralJoin, _collateralJoin);
    assertEq(savedDataCoinJoin, _coinJoin);
    assertEq(savedDataSafeId, _safeId);
    assertEq(savedDataCollateralWad, _collateralWad);
    assertEq(savedDataDebtWad, _debtWad);
  }

  function test_repayAllDebtAndFreeTokenCollateral() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    address _collateralJoin = address(0x456);
    address _coinJoin = address(0x789);
    uint256 _safeId = 123;
    uint256 _collateralWad = 1000;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'repayAllDebtAndFreeTokenCollateral(address,address,address,uint256,uint256)',
        _manager,
        _collateralJoin,
        _coinJoin,
        _safeId,
        _collateralWad
      )
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    address savedDataCollateralJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('collateralJoin()')));
    address savedDataCoinJoin = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('coinJoin()')));
    uint256 savedDataSafeId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeId()')));
    uint256 savedDataCollateralWad = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('collateralWad()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataCollateralJoin, _collateralJoin);
    assertEq(savedDataCoinJoin, _coinJoin);
    assertEq(savedDataSafeId, _safeId);
    assertEq(savedDataCollateralWad, _collateralWad);
  }

  function test_collectTokenCollateral() public {
    address target = address(basicActions);
    address _manager = address(0x123);
    address _collateralJoin = address(0x456);
    uint256 _safeId = 123;
    uint256 _deltaWad = 1000;
    vm.startPrank(alice);

    proxy.execute(
      address(basicActions),
      abi.encodeWithSignature(
        'collectTokenCollateral(address,address,uint256,uint256)', _manager, _collateralJoin, _safeId, _deltaWad
      )
    );

    address savedDataManager = decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('manager()')));
    address savedDataCollateralJoin =
      decodeAsAddress(proxy.execute(target, abi.encodeWithSignature('collateralJoin()')));
    uint256 savedDataSafeId = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('safeId()')));
    uint256 savedDataDeltaWad = decodeAsUint256(proxy.execute(target, abi.encodeWithSignature('deltaWad()')));

    assertEq(savedDataManager, _manager);
    assertEq(savedDataCollateralJoin, _collateralJoin);
    assertEq(savedDataSafeId, _safeId);
    assertEq(savedDataDeltaWad, _deltaWad);
  }
}

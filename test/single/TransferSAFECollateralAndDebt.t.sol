// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'ds-test/test.sol';

import {ISAFEEngine, SAFEEngine} from '@contracts/SAFEEngine.sol';
import {IODSafeManager, ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {ITaxCollector, TaxCollector} from '@contracts/TaxCollector.sol';
import {IERC721Receiver} from '@openzeppelin/token/ERC721/IERC721Receiver.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';

import {RAY, WAD} from '@libraries/Math.sol';

abstract contract Hevm {
  function warp(uint256) public virtual;
  function store(address, bytes32, bytes32) external virtual;
  function prank(address) external virtual;
  function mockCall(address, bytes memory, bytes memory) external virtual;
}

contract Guy is IERC721Receiver {
  SAFEEngine public safeEngine;
  ODSafeManager public safeManager;
  Hevm public hevm;
  address public userProxy;
  uint256 public safeId;

  constructor(SAFEEngine safeEngine_, ODSafeManager _safeManager) {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    safeEngine = safeEngine_;
    safeManager = _safeManager;
  }

  function try_call(address addr, bytes calldata data) external returns (bool ok) {
    bytes memory _data = data;
    assembly {
      ok := call(gas(), addr, 0, add(_data, 0x20), mload(_data), 0, 0)
      let free := mload(0x40)
      mstore(free, ok)
      mstore(0x40, add(free, 32))
      revert(free, 32)
    }
  }

  function try_callAsProxy(address addr, bytes calldata data) external returns (bool ok) {
    bytes memory _data = data;
    hevm.prank(userProxy);
    assembly {
      ok := call(gas(), addr, 0, add(_data, 0x20), mload(_data), 0, 0)
      let free := mload(0x40)
      mstore(free, ok)
      mstore(0x40, add(free, 32))
      revert(free, 32)
    }
  }

  function can_modifySAFECollateralization(
    bytes32 collateralType,
    address safe,
    address collateralSource,
    address debtDestination,
    int256 deltaCollateral,
    int256 deltaDebt
  ) public returns (bool ok) {
    string memory sig = 'modifySAFECollateralization(bytes32,address,address,address,int256,int256)';
    bytes memory data = abi.encodeWithSignature(
      sig, address(this), collateralType, safe, collateralSource, debtDestination, deltaCollateral, deltaDebt
    );

    bytes memory success;
    bytes memory can_call = abi.encodeWithSignature('try_call(address,bytes)', safeEngine, data);
    (ok, success) = address(this).call(can_call);

    ok = abi.decode(success, (bool));
  }

  function can_modifySAFECollateralizationAsProxy(
    int256 deltaCollateral,
    int256 deltaDebt,
    bool _nonSafeHandlerAddress
  ) public returns (bool ok) {
    string memory _sig = 'modifySAFECollateralization(uint256,int256,int256,bool)';
    bytes memory _data = abi.encodeWithSignature(_sig, safeId, deltaCollateral, deltaDebt, _nonSafeHandlerAddress);
    bytes memory _success;

    bytes memory _can_call = abi.encodeWithSignature('try_callAsProxy(address,bytes)', safeManager, _data);
    (ok, _success) = address(this).call(_can_call);

    ok = abi.decode(_success, (bool));
  }

  function can_transferSAFECollateralAndDebt(
    bytes32 collateralType,
    address src,
    address dst,
    int256 deltaCollateral,
    int256 deltaDebt
  ) public returns (bool ok) {
    string memory sig = 'transferSAFECollateralAndDebt(bytes32,address,address,int256,int256)';
    bytes memory data = abi.encodeWithSignature(sig, collateralType, src, dst, deltaCollateral, deltaDebt);

    bytes memory can_call = abi.encodeWithSignature('try_call(address,bytes)', safeEngine, data);
    bytes memory success;
    (ok, success) = address(this).call(can_call);

    ok = abi.decode(success, (bool));
  }

  function modifySAFECollateralization(
    bytes32 collateralType,
    address safe,
    address collateralSource,
    address debtDestination,
    int256 deltaCollateral,
    int256 deltaDebt
  ) public {
    safeEngine.modifySAFECollateralization(
      collateralType, safe, collateralSource, debtDestination, deltaCollateral, deltaDebt
    );
  }

  function modifySAFECollateralizationAsProxy(
    uint256 _safe,
    int256 _deltaCollateral,
    int256 _deltaDebt,
    bool _nonSafeHandlerAddress
  ) public {
    hevm.prank(userProxy);
    safeManager.modifySAFECollateralization(_safe, _deltaCollateral, _deltaDebt, _nonSafeHandlerAddress);
  }

  function transferSAFECollateralAndDebt(
    bytes32 collateralType,
    address src,
    address dst,
    int256 deltaCollateral,
    int256 deltaDebt
  ) public {
    safeEngine.transferSAFECollateralAndDebt(collateralType, src, dst, deltaCollateral, deltaDebt);
  }

  function approveSAFEModification(address usr) public {
    safeEngine.approveSAFEModification(usr);
  }

  function openSafe(Vault721 vault721) public returns (address) {
    userProxy = vault721.build(address(this));
    safeId = safeManager.openSAFE('collateralTokens', userProxy);
    address safeHandler = safeManager.safeData(safeId).safeHandler;
    return safeHandler;
  }

  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external pure returns (bytes4) {
    return IERC721Receiver.onERC721Received.selector;
  }

  function pass() public {}
}

contract SingleTransferSAFECollateralAndDebtTest is DSTest {
  SAFEEngine safeEngine;
  ODSafeManager safeManager;
  Vault721 vault721;
  TaxCollector taxCollector;
  Hevm hevm;
  Guy ali;
  Guy bob;
  address a;
  address b;

  function ray(uint256 wad) internal pure returns (uint256) {
    return wad * 10 ** 9;
  }

  function rad(uint256 wad) internal pure returns (uint256) {
    return wad * 10 ** 27;
  }

  function setUp() public {
    hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: rad(1000 ether)});
    safeEngine = new SAFEEngine(_safeEngineParams);

    ITaxCollector.TaxCollectorParams memory _taxCollectorParams = ITaxCollector.TaxCollectorParams({
      primaryTaxReceiver: address(0x744),
      globalStabilityFee: RAY,
      maxStabilityFeeRange: RAY - 1,
      maxSecondaryReceivers: 0
    });

    taxCollector = new TaxCollector(address(safeEngine), _taxCollectorParams);

    vault721 = new Vault721();
    safeManager = new ODSafeManager(address(safeEngine), address(vault721), address(taxCollector));

    ali = new Guy(safeEngine, safeManager);
    bob = new Guy(safeEngine, safeManager);
    a = ali.openSafe(vault721);
    b = bob.openSafe(vault721);

    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: rad(1000 ether), debtFloor: 0});

    safeEngine.initializeCollateralType('collateralTokens', abi.encode(_safeEngineCollateralParams));
    ITaxCollector.TaxCollectorCollateralParams memory _taxCollectorCParams =
      ITaxCollector.TaxCollectorCollateralParams({stabilityFee: RAY + 1.54713e18});
    taxCollector.initializeCollateralType('collateralTokens', abi.encode(_taxCollectorCParams));

    safeEngine.updateCollateralPrice('collateralTokens', ray(0.5 ether), ray(0.5 ether));
    new NFTRenderer(address(vault721), address(1), address(taxCollector), address(2));
    safeEngine.addAuthorization(a);
    safeEngine.addAuthorization(b);
    safeEngine.addAuthorization(address(safeManager));
    safeEngine.addAuthorization(address(taxCollector));

    safeEngine.modifyCollateralBalance('collateralTokens', a, 80 ether);
  }

  function test_transferCollateralAndDebt_to_self() public {
    hevm.prank(a);
    safeEngine.approveSAFEModification(address(ali));
    ali.modifySAFECollateralizationAsProxy(ali.safeId(), 8 ether, 4 ether, false);
    safeEngine.approveSAFEModification(a);
    assertTrue(ali.can_transferSAFECollateralAndDebt('collateralTokens', a, a, 8 ether, 4 ether));
    assertTrue(ali.can_transferSAFECollateralAndDebt('collateralTokens', a, a, 4 ether, 2 ether));
    assertTrue(!ali.can_transferSAFECollateralAndDebt('collateralTokens', a, a, 9 ether, 4 ether));
  }

  function test_transferCollateralAndDebt_to_other() public {
    hevm.prank(a);
    safeEngine.approveSAFEModification(address(ali));
    ali.modifySAFECollateralizationAsProxy(ali.safeId(), 8 ether, 4 ether, false);
    assertTrue(!ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 8 ether, 4 ether));
    hevm.prank(b);
    safeEngine.approveSAFEModification(address(ali));
    assertTrue(ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 8 ether, 4 ether));
  }

  function test_give_to_other() public {
    hevm.prank(a);
    safeEngine.approveSAFEModification(address(ali));
    ali.modifySAFECollateralization('collateralTokens', a, a, a, 8 ether, 4 ether);

    bob.approveSAFEModification(address(ali));
    hevm.prank(b);
    safeEngine.approveSAFEModification(address(ali));
    assertTrue(ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 4 ether, 2 ether));
    assertTrue(!ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 16 ether, 9 ether));
    assertTrue(!ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 16 ether, 9 ether));
  }

  function test_transferCollateralAndDebt_dust() public {
    hevm.prank(a);
    safeEngine.approveSAFEModification(address(ali));
    hevm.prank(b);
    safeEngine.approveSAFEModification(address(ali));
    ali.modifySAFECollateralization('collateralTokens', a, a, a, 8 ether, 4 ether);
    bob.approveSAFEModification(address(ali));
    assertTrue(ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 4 ether, 2 ether));
    safeEngine.modifyParameters('collateralTokens', 'debtFloor', abi.encode(rad(1 ether)));
    assertTrue(ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 2 ether, 1 ether));
    assertTrue(!ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 1 ether, 0.5 ether));
  }
}

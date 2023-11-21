// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import 'ds-test/test.sol';

import {ISAFEEngine, SAFEEngine} from '@contracts/SAFEEngine.sol';

contract Guy {
  SAFEEngine public safeEngine;

  constructor(SAFEEngine safeEngine_) {
    safeEngine = safeEngine_;
  }

  function try_call(address addr, bytes calldata data) external returns (bool) {
    bytes memory _data = data;
    assembly {
      let ok := call(gas(), addr, 0, add(_data, 0x20), mload(_data), 0, 0)
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
  ) public returns (bool) {
    string memory sig = 'modifySAFECollateralization(bytes32,address,address,address,int256,int256)';
    bytes memory data = abi.encodeWithSignature(
      sig, address(this), collateralType, safe, collateralSource, debtDestination, deltaCollateral, deltaDebt
    );

    bytes memory can_call = abi.encodeWithSignature('try_call(address,bytes)', safeEngine, data);
    (bool ok, bytes memory success) = address(this).call(can_call);

    ok = abi.decode(success, (bool));
    if (ok) return true;
  }

  function can_transferSAFECollateralAndDebt(
    bytes32 collateralType,
    address src,
    address dst,
    int256 deltaCollateral,
    int256 deltaDebt
  ) public returns (bool) {
    string memory sig = 'transferSAFECollateralAndDebt(bytes32,address,address,int256,int256)';
    bytes memory data = abi.encodeWithSignature(sig, collateralType, src, dst, deltaCollateral, deltaDebt);

    bytes memory can_call = abi.encodeWithSignature('try_call(address,bytes)', safeEngine, data);
    (bool ok, bytes memory success) = address(this).call(can_call);

    ok = abi.decode(success, (bool));
    if (ok) return true;
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

  function pass() public {}
}

contract SingleTransferSAFECollateralAndDebtTest is DSTest {
  SAFEEngine safeEngine;
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
    ISAFEEngine.SAFEEngineParams memory _safeEngineParams =
      ISAFEEngine.SAFEEngineParams({safeDebtCeiling: type(uint256).max, globalDebtCeiling: rad(1000 ether)});
    safeEngine = new SAFEEngine(_safeEngineParams);
    ali = new Guy(safeEngine);
    bob = new Guy(safeEngine);
    a = address(ali);
    b = address(bob);

    ISAFEEngine.SAFEEngineCollateralParams memory _safeEngineCollateralParams =
      ISAFEEngine.SAFEEngineCollateralParams({debtCeiling: rad(1000 ether), debtFloor: 0});
    safeEngine.initializeCollateralType('collateralTokens', abi.encode(_safeEngineCollateralParams));
    safeEngine.updateCollateralPrice('collateralTokens', ray(0.5 ether), ray(0.5 ether));

    safeEngine.addAuthorization(a);
    safeEngine.addAuthorization(b);

    safeEngine.modifyCollateralBalance('collateralTokens', a, 80 ether);
  }

  function test_transferCollateralAndDebt_to_self() public {
    ali.modifySAFECollateralization('collateralTokens', a, a, a, 8 ether, 4 ether);
    assertTrue(ali.can_transferSAFECollateralAndDebt('collateralTokens', a, a, 8 ether, 4 ether));
    assertTrue(ali.can_transferSAFECollateralAndDebt('collateralTokens', a, a, 4 ether, 2 ether));
    assertTrue(!ali.can_transferSAFECollateralAndDebt('collateralTokens', a, a, 9 ether, 4 ether));
  }

  function test_transferCollateralAndDebt_to_other() public {
    ali.modifySAFECollateralization('collateralTokens', a, a, a, 8 ether, 4 ether);
    assertTrue(!ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 8 ether, 4 ether));
    bob.approveSAFEModification(address(ali));
    assertTrue(ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 8 ether, 4 ether));
  }

  function test_give_to_other() public {
    ali.modifySAFECollateralization('collateralTokens', a, a, a, 8 ether, 4 ether);
    bob.approveSAFEModification(address(ali));
    assertTrue(ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 4 ether, 2 ether));
    assertTrue(!ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 4 ether, 3 ether));
    assertTrue(!ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 4 ether, 1 ether));
  }

  function test_transferCollateralAndDebt_dust() public {
    ali.modifySAFECollateralization('collateralTokens', a, a, a, 8 ether, 4 ether);
    bob.approveSAFEModification(address(ali));
    assertTrue(ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 4 ether, 2 ether));
    safeEngine.modifyParameters('collateralTokens', 'debtFloor', abi.encode(rad(1 ether)));
    assertTrue(ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 2 ether, 1 ether));
    assertTrue(!ali.can_transferSAFECollateralAndDebt('collateralTokens', a, b, 1 ether, 0.5 ether));
  }
}

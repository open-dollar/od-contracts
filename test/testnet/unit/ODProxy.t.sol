// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest, stdStorage, StdStorage} from '@testnet/utils/HaiTest.t.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {SAFEEngineForTest, ISAFEEngine} from '@testnet/mocks/SAFEEngineForTest.sol';
import {ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {TaxCollector} from '@contracts/TaxCollector.sol';
import {ITaxCollector} from '@interfaces/ITaxCollector.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
import {Math, RAY} from '@libraries/Math.sol';

contract Base is HaiTest {
  ODProxy odProxy;
  ODSafeManager odSafeManager;
  ITaxCollector taxCollector;
  IVault721 vault721;
  ISAFEEngine safeEngine;
  address owner = address(0xdeadce11);

  function setUp() public {
    odProxy = new ODProxy(owner);
    safeEngine = ISAFEEngine(address(mockContract('safeEngine')));
    vault721 = IVault721(address(mockContract('vault721')));
    taxCollector = ITaxCollector(address(mockContract('taxCollector')));
    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.initializeManager.selector), abi.encode());
    odSafeManager = new ODSafeManager(address(safeEngine), address(vault721), address(taxCollector));
  }
}

contract Unit_ODProxy_Execute is Base {
  function test_Execute(bytes32 cType) public {
    bytes memory encodedCall = abi.encodeWithSignature('openSAFE(bytes32,address)', cType, owner);
    vm.mockCall(address(vault721), abi.encodeWithSelector(IVault721.mint.selector), abi.encode());
    vm.prank(owner);
    odProxy.execute(address(odSafeManager), encodedCall);
  }
}

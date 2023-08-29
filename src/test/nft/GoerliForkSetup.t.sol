// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {GoerliParams, WETH, FTRG, WBTC, STONES, TOTEM} from '@script/GoerliParams.s.sol';
import {GoerliDeployment} from '@script/GoerliDeployment.s.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';

contract GoerliForkSetup is Test, GoerliDeployment {
  // TODO replace with Arbitrum addrs
  address public ARB_WBTC = address(0);
  address public ARB_STONES = address(0);
  address public ARB_TOTEM = address(0);

  address public alice = 0x37c5B029f9c3691B3d47cb024f84E5E257aEb0BB;
  address public bob = 0x23aD35FAab005a5E69615d275176e5C22b2ceb9E;
  address public cobra = 0xD5d1bb95259Fe2c5a84da04D1Aa682C71A1B8C0E;
  address aliceProxy;

  function setUp() public {
    vm.label(alice, 'Alice');
    vm.label(bob, 'Bob');
    vm.label(cobra, 'Cobra');
    aliceProxy = deployOrFind(alice);
    vm.label(aliceProxy, 'A-Proxy');
  }

  // --- helper functions ---

  function deployOrFind(address owner) public returns (address) {
    address proxy = vault721.getProxy(owner);
    if (proxy == address(0)) {
      return address(vault721.build(owner));
    } else {
      return proxy;
    }
  }

  function openSafe(bytes32 _cType, address _proxy) public returns (uint256 _safeId) {
    bytes memory payload = abi.encodeWithSelector(basicActions.openSAFE.selector, address(safeManager), _cType, _proxy);
    bytes memory safeData = ODProxy(_proxy).execute(address(basicActions), payload);
    _safeId = abi.decode(safeData, (uint256));
  }

  function depositCollatAndGenDebt(
    bytes32 _cType,
    uint256 _safeId,
    uint256 _collatAmount,
    uint256 _deltaWad,
    address _proxy
  ) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(taxCollector),
      address(collateralJoin[_cType]),
      address(coinJoin),
      _safeId,
      _collatAmount,
      _deltaWad
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }
}

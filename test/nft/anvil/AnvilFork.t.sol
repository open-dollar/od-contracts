// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {AnvilDeployment} from '@test/nft/anvil/deployment/AnvilDeployment.t.sol';
import {WSTETH, ARB, CBETH, RETH, MAGIC} from '@script/GoerliParams.s.sol';

// --- Proxy Contracts ---
import {BasicActions, CommonActions} from '@contracts/proxies/actions/BasicActions.sol';
import {DebtBidActions} from '@contracts/proxies/actions/DebtBidActions.sol';
import {SurplusBidActions} from '@contracts/proxies/actions/SurplusBidActions.sol';
import {CollateralBidActions} from '@contracts/proxies/actions/CollateralBidActions.sol';
import {PostSettlementSurplusBidActions} from '@contracts/proxies/actions/PostSettlementSurplusBidActions.sol';
import {GlobalSettlementActions} from '@contracts/proxies/actions/GlobalSettlementActions.sol';
import {RewardedActions} from '@contracts/proxies/actions/RewardedActions.sol';
import {GlobalSettlementActions} from '@contracts/proxies/actions/GlobalSettlementActions.sol';
import {PostSettlementSurplusBidActions} from '@contracts/proxies/actions/PostSettlementSurplusBidActions.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';

// --- Governance Contracts ---
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';

/**
 * @dev to run local tests on Anvil network:
 *
 * URL=http://127.0.0.1:8545
 * anvil
 * yarn deploy:anvil
 * node tasks/parseAnvilDeployments.js
 * forge t --fork-url $URL --match-contract ContractToTest -vvvvv
 */

contract AnvilFork is AnvilDeployment, Test {
  // Anvil wallets w/ 10_000 ether
  address public constant ALICE = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // deployer
  address public constant BOB = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
  address public constant CASSY = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;

  uint256 public constant MINT_AMOUNT = 1_000_000_000 * 1 ether;

  address public aProxy;
  address public bProxy;
  address public cProxy;

  function setUp() public virtual {
    deployProxies();
    labelVars();
    mintCollateral();
    createSafes();
  }

  // setup functions
  function deployProxies() public {
    aProxy = deployOrFind(ALICE);
    bProxy = deployOrFind(BOB);
    cProxy = deployOrFind(CASSY);
  }

  function labelVars() public {
    vm.label(ALICE, 'Alice');
    vm.label(BOB, 'Bob');
    vm.label(CASSY, 'Cassy');
    vm.label(aProxy, 'A-proxy');
    vm.label(bProxy, 'B-proxy');
    vm.label(cProxy, 'C-proxy');
  }

  function createSafes() public {
    vm.startPrank(ALICE);
    uint256 aSafe = openSafe(WSTETH, aProxy);
    vm.stopPrank();
    vm.startPrank(BOB);
    uint256 bSafe = openSafe(WSTETH, bProxy);
    vm.stopPrank();
    vm.startPrank(CASSY);
    uint256 cSafe = openSafe(WSTETH, cProxy);
    vm.stopPrank();

    assertEq(aSafe, 1);
    assertEq(bSafe, 2);
    assertEq(cSafe, 3);
  }

  function mintCollateral() public {
    address[] memory users = new address[](3);
    users[0] = ALICE;
    users[1] = BOB;
    users[2] = CASSY;

    for (uint256 i = 0; i < users.length; i++) {
      address proxy = vault721.getProxy(users[i]);
      erc20[ARB].mint(users[i], MINT_AMOUNT);
      erc20[WSTETH].mint(users[i], MINT_AMOUNT);
      erc20[CBETH].mint(users[i], MINT_AMOUNT);
      erc20[RETH].mint(users[i], MINT_AMOUNT);
      erc20[MAGIC].mint(users[i], MINT_AMOUNT);

      vm.startPrank(users[i]);
      erc20[ARB].approve(proxy, MINT_AMOUNT);
      erc20[WSTETH].approve(proxy, MINT_AMOUNT);
      erc20[CBETH].approve(proxy, MINT_AMOUNT);
      erc20[RETH].approve(proxy, MINT_AMOUNT);
      erc20[MAGIC].approve(proxy, MINT_AMOUNT);
      vm.stopPrank();
    }
  }

  // helper functions
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

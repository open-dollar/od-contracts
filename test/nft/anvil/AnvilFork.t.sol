// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {AnvilDeployment} from '@test/nft/anvil/deployment/AnvilDeployment.t.sol';

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

  address public aProxy;
  address public bProxy;
  address public cProxy;

  mapping(address publicKey => uint256 privateKey) public keyPairs;

  function setUp() public virtual {
    labelConst();
    deployProxies();
    labelProxies();
  }

  function labelConst() public {
    vm.label(ALICE, 'Alice');
    vm.label(BOB, 'Bob');
    vm.label(CASSY, 'Cassy');
  }

  function deployProxies() public {
    aProxy = deployOrFind(ALICE);
    bProxy = deployOrFind(BOB);
    cProxy = deployOrFind(CASSY);
  }

  function labelProxies() public {
    vm.label(aProxy, 'A-proxy');
    vm.label(bProxy, 'B-proxy');
    vm.label(cProxy, 'C-proxy');
  }

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
}

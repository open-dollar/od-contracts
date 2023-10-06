// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {AnvilDeployment} from '@test/nft/anvil/deployment/AnvilDeployment.t.sol';
import {WSTETH, ARB, CBETH, RETH, MAGIC} from '@script/GoerliParams.s.sol';

// --- Core Contracts ---
import {SAFEEngine} from '@contracts/SAFEEngine.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

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
  uint256 public constant MINT_AMOUNT = 1_000_000 * 1 ether;

  // Anvil wallets w/ 10_000 ether
  address public constant ALICE = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // deployer
  address public constant BOB = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
  address public constant CASSY = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
  address public constant DAN = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
  address public constant ERICA = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;

  uint256 public totalVaults;
  uint256 public debtCeiling;

  mapping(address proxy => mapping(bytes32 cType => uint256 id)) public vaultIds;

  address[3] public users;
  address[2] public newUsers;
  address[3] public proxies;
  bytes32[5] public cTypes;

  function setUp() public virtual {
    users[0] = ALICE;
    users[1] = BOB;
    users[2] = CASSY;

    newUsers[0] = DAN;
    newUsers[1] = ERICA;

    cTypes[0] = ARB;
    cTypes[1] = WSTETH;
    cTypes[2] = CBETH;
    cTypes[3] = RETH;
    cTypes[4] = MAGIC;

    deployProxies();
    labelVars();
    mintCollateralAndOpenSafes();

    debtCeiling = setDebtCeiling();
  }

  /**
   * @dev setup functions
   */
  function deployProxies() public {
    proxies[0] = deployOrFind(ALICE);
    proxies[1] = deployOrFind(BOB);
    proxies[2] = deployOrFind(CASSY);
  }

  function labelVars() public {
    vm.label(ALICE, 'Alice');
    vm.label(BOB, 'Bob');
    vm.label(CASSY, 'Cassy');
    vm.label(proxies[0], 'A-proxy');
    vm.label(proxies[1], 'B-proxy');
    vm.label(proxies[2], 'C-proxy');
  }

  function mintCollateralAndOpenSafes() public {
    for (uint256 i = 0; i < users.length; i++) {
      address user = users[i];
      address proxy = vault721.getProxy(user);

      for (uint256 j = 0; j < cTypes.length; j++) {
        bytes32 cType = cTypes[j];
        totalVaults++;

        vm.startPrank(user);
        erc20[cType].mint(MINT_AMOUNT);
        erc20[cType].approve(proxy, MINT_AMOUNT);
        vaultIds[proxy][cType] = openSafe(cType, proxy);
        vm.stopPrank();
      }
    }
  }

  function setDebtCeiling() public view returns (uint256 _debtCeiling) {
    ISAFEEngine.SAFEEngineParams memory params = safeEngine.params();
    _debtCeiling = params.safeDebtCeiling;
  }

  /**
   * @dev public helper functions
   */
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

  function genDebt(uint256 _safeId, uint256 _deltaWad, address _proxy) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.generateDebt.selector,
      address(safeManager),
      address(taxCollector),
      address(coinJoin),
      _safeId,
      _deltaWad
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  /**
   * @dev internal helper functions
   */
  function checkProxyAddress() public {
    for (uint256 i = 0; i < users.length; i++) {
      assertEq(proxies[i], vault721.getProxy(users[i]));
    }
  }

  function checkVaultIds() public {
    uint256 vaultId = 1;

    for (uint256 i = 0; i < users.length; i++) {
      address user = users[i];
      address proxy = vault721.getProxy(user);
      assertEq(totalVaults / 3, vault721.balanceOf(user));

      for (uint256 j = 0; j < cTypes.length; j++) {
        assertEq(vaultId, vaultIds[proxy][cTypes[j]]);
        assertEq(user, vault721.ownerOf(vaultId));
        vaultId++;
      }
    }
  }
}

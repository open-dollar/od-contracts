// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {AnvilDeployment} from '@testlocal/nft/anvil/deployment/AnvilDeployment.t.sol';
import {WSTETH, ARB, CBETH, RETH, MAGIC} from '@script/SepoliaParams.s.sol';

// --- Collateral ERC20 ---
import {MintableVoteERC20} from '@contracts/for-test/MintableVoteERC20.sol';

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
 * anvil
 * yarn deploy:anvil
 * move deployment json to the deployments/anvil folder
 * - from: broadcast/Deploy.s.sol/31337/run-latest.json
 * - to: deployments/anvil/
 * - replace: existing `run-latest.json`
 * node tasks/parseAnvilDeployments.js
 * forge t --fork-url http://127.0.0.1:8545  --match-contract ContractToTest -vvvvv
 */

contract AnvilFork is AnvilDeployment, Test {
  uint256 public constant MINT_AMOUNT = 1_000_000 * 1 ether;

  bytes32 constant newCType = bytes32('NC');
  address public newCAddress;

  // Anvil wallets w/ 10_000 ether
  address public constant ALICE = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // deployer
  address public constant BOB = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
  address public constant CHARLOTTE = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
  address public constant DAN = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
  address public constant ERICA = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;

  uint256 public totalVaults;
  uint256 public debtCeiling;

  mapping(address proxy => mapping(bytes32 cType => uint256 id)) public vaultIds;

  address[3] public users;
  address[2] public newUsers;
  address[3] public proxies;
  bytes32[4] public cTypes;

  function setUp() public virtual {
    users[0] = ALICE;
    users[1] = BOB;
    users[2] = CHARLOTTE;

    newUsers[0] = DAN;
    newUsers[1] = ERICA;

    cTypes[0] = ARB;
    cTypes[1] = WSTETH;
    cTypes[2] = CBETH;
    cTypes[3] = RETH;

    deployProxies();
    labelVars();
    mintCollateralAndOpenSafes();

    debtCeiling = setDebtCeiling();

    newCAddress = address(new MintableVoteERC20('NewCoin', 'NC', 18));
  }

  /**
   * @dev setup functions
   */
  function deployProxies() public {
    proxies[0] = deployOrFind(ALICE);
    proxies[1] = deployOrFind(BOB);
    proxies[2] = deployOrFind(CHARLOTTE);
  }

  function labelVars() public {
    vm.label(ALICE, 'Alice');
    vm.label(BOB, 'Bob');
    vm.label(CHARLOTTE, 'Cassy');
    vm.label(proxies[0], 'A-proxy');
    vm.label(proxies[1], 'B-proxy');
    vm.label(proxies[2], 'C-proxy');
    for (uint256 i; i < cTypes.length; i++) {
      string memory cTypeName = erc20[cTypes[i]].name();
      vm.label(address(erc20[cTypes[i]]), cTypeName);
    }
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

  function allowSafe(address _proxy, uint256 _safeId, address _user, bool _ok) public {
    bytes memory payload =
      abi.encodeWithSelector(basicActions.allowSAFE.selector, address(safeManager), _safeId, _user, _ok);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function allowHandler(address _proxy, address _user, bool _ok) public {
    bytes memory payload = abi.encodeWithSelector(basicActions.allowHandler.selector, address(safeManager), _user, _ok);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function modifySAFECollateralization(
    address _proxy,
    uint256 _safeId,
    int256 _collateralDelta,
    int256 _debtDelta
  ) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.modifySAFECollateralization.selector, address(safeManager), _safeId, _collateralDelta, _debtDelta
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function transferCollateral(address _proxy, uint256 _safeId, address _dst, uint256 _deltaWad) public {
    bytes memory payload =
      abi.encodeWithSelector(basicActions.transferCollateral.selector, address(safeManager), _safeId, _dst, _deltaWad);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function transferInternalCoins(address _proxy, uint256 _safeId, address _dst, uint256 _rad) public {
    bytes memory payload =
      abi.encodeWithSelector(basicActions.transferInternalCoins.selector, address(safeManager), _safeId, _dst, _rad);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function quitSystem(address _proxy, uint256 _safeId, address _dst) public {
    bytes memory payload = abi.encodeWithSelector(basicActions.quitSystem.selector, address(safeManager), _safeId, _dst);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function enterSystem(address _proxy, address _src, uint256 _safeId) public {
    bytes memory payload =
      abi.encodeWithSelector(basicActions.enterSystem.selector, address(safeManager), _src, _safeId);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function moveSAFE(address _proxy, uint256 _src, uint256 _dst) public {
    bytes memory payload = abi.encodeWithSelector(basicActions.moveSAFE.selector, address(safeManager), _src, _dst);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function addSAFE(address _proxy, uint256 _safe) public {
    bytes memory payload = abi.encodeWithSelector(basicActions.addSAFE.selector, address(safeManager), _safe);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function removeSAFE(address _proxy, uint256 _safe) public {
    bytes memory payload = abi.encodeWithSelector(basicActions.removeSAFE.selector, address(safeManager), _safe);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function protectSAFE(address _proxy, uint256 _safe, address _liquidationEngine, address _saviour) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.protectSAFE.selector, address(safeManager), _safe, _liquidationEngine, _saviour
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
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

  function repayDebt(uint256 _safeId, uint256 _deltaWad, address proxy) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.repayDebt.selector,
      address(safeManager),
      address(taxCollector),
      address(coinJoin),
      _safeId,
      _deltaWad
    );
    ODProxy(proxy).execute(address(basicActions), payload);
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

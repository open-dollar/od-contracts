// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Registry.s.sol';

import {HaiTest} from '@testnet/utils/HaiTest.t.sol';
import {Deploy, DeployMainnet, DeploySepolia} from '@script/Deploy.s.sol';

import {ParamChecker, WSTETH, ARB} from '@script/Params.s.sol';
import {ERC20Votes} from '@openzeppelin/token/ERC20/extensions/ERC20Votes.sol';

import {Contracts} from '@script/Contracts.s.sol';
import {SepoliaDeployment} from '@script/SepoliaDeployment.s.sol';

import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IODCreate2Factory} from '@interfaces/factories/IODCreate2Factory.sol';
import {IProtocolToken} from '@contracts/tokens/ProtocolToken.sol';

abstract contract CommonDeploymentTest is HaiTest, Deploy {
  // SAFEEngine
  function test_SAFEEngine_Auth() public {
    assertEq(safeEngine.authorizedAccounts(address(oracleRelayer)), true);
    assertEq(safeEngine.authorizedAccounts(address(taxCollector)), true);
    assertEq(safeEngine.authorizedAccounts(address(debtAuctionHouse)), true);
    assertEq(safeEngine.authorizedAccounts(address(liquidationEngine)), true);

    assertTrue(safeEngine.canModifySAFE(address(accountingEngine), address(surplusAuctionHouse)));
  }

  function test_SAFEEngine_Params() public view {
    ParamChecker._checkParams(address(safeEngine), abi.encode(_safeEngineParams));
  }

  // OracleRelayer
  function test_OracleRelayer_Auth() public {
    assertEq(oracleRelayer.authorizedAccounts(address(pidRateSetter)), true);
  }

  // AccountingEngine
  function test_AccountingEngine_Auth() public {
    assertEq(accountingEngine.authorizedAccounts(address(liquidationEngine)), true);
  }

  function test_AccountingEntine_Params() public view {
    ParamChecker._checkParams(address(accountingEngine), abi.encode(_accountingEngineParams));
  }

  // SystemCoin
  function test_SystemCoin_Auth() public {
    assertEq(systemCoin.authorizedAccounts(address(coinJoin)), true);
  }

  // ProtocolToken
  function test_ProtocolToken_Auth() public {
    assertEq(protocolToken.authorizedAccounts(address(debtAuctionHouse)), true);
  }

  // SurplusAuctionHouse
  function test_SurplusAuctionHouse_Auth() public {
    assertEq(surplusAuctionHouse.authorizedAccounts(address(accountingEngine)), true);
  }

  function test_SurplusAuctionHouse_Params() public view {
    ParamChecker._checkParams(address(surplusAuctionHouse), abi.encode(_surplusAuctionHouseParams));
  }

  // DebtAuctionHouse
  function test_DebtAuctionHouse_Auth() public {
    assertEq(debtAuctionHouse.authorizedAccounts(address(accountingEngine)), true);
  }

  function test_DebtAuctionHouse_Params() public view {
    ParamChecker._checkParams(address(debtAuctionHouse), abi.encode(_debtAuctionHouseParams));
  }

  // CollateralAuctionHouse
  function test_CollateralAuctionHouse_Auth() public {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      assertEq(collateralAuctionHouse[_cType].authorizedAccounts(address(liquidationEngine)), true);
    }
  }

  function test_CollateralAuctionHouse_Params() public view {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      ParamChecker._checkCParams(
        address(collateralAuctionHouseFactory), _cType, abi.encode(_collateralAuctionHouseParams[_cType])
      );
    }
  }

  function test_Grant_Auth() public {
    _test_Authorizations(governor, true);
    if (delegate != address(0)) _test_Authorizations(delegate, true);
    _test_Authorizations(deployer, false);
  }

  function _test_Authorizations(address _target, bool _permission) internal {
    // base contracts
    assertEq(safeEngine.authorizedAccounts(_target), _permission);

    /**
     * @dev oracleRelayer deployment and auth moved to post-deploy setup
     * assertEq(oracleRelayer.authorizedAccounts(_target), _permission);
     */
    assertEq(taxCollector.authorizedAccounts(_target), _permission);
    assertEq(stabilityFeeTreasury.authorizedAccounts(_target), _permission);
    assertEq(liquidationEngine.authorizedAccounts(_target), _permission);
    assertEq(accountingEngine.authorizedAccounts(_target), _permission);
    assertEq(surplusAuctionHouse.authorizedAccounts(_target), _permission);
    assertEq(debtAuctionHouse.authorizedAccounts(_target), _permission);

    // settlement
    assertEq(globalSettlement.authorizedAccounts(_target), _permission);
    assertEq(postSettlementSurplusAuctionHouse.authorizedAccounts(_target), _permission);
    assertEq(settlementSurplusAuctioneer.authorizedAccounts(_target), _permission);

    // factories
    assertEq(chainlinkRelayerFactory.authorizedAccounts(_target), _permission);
    assertEq(denominatedOracleFactory.authorizedAccounts(_target), _permission);
    assertEq(delayedOracleFactory.authorizedAccounts(_target), _permission);

    assertEq(collateralJoinFactory.authorizedAccounts(_target), _permission);
    assertEq(collateralAuctionHouseFactory.authorizedAccounts(_target), _permission);

    // tokens
    assertEq(systemCoin.authorizedAccounts(_target), _permission);
    assertEq(protocolToken.authorizedAccounts(_target), _permission);

    // token adapters
    assertEq(coinJoin.authorizedAccounts(_target), _permission);

    // jobs
    assertEq(accountingJob.authorizedAccounts(_target), _permission);
    assertEq(liquidationJob.authorizedAccounts(_target), _permission);
    assertEq(oracleJob.authorizedAccounts(_target), _permission);
  }
}

/**
 * @dev not possible to test mainnet deployment due to predeployment of protcolToken
 *  that is exclusively authorized to single wallet
 *
 * contract E2EDeploymentMainnetTest is DeployMainnet, CommonDeploymentTest {
 *   function setUp() public override {
 *     uint256 forkId = vm.createFork(vm.rpcUrl('mainnet'));
 *     vm.selectFork(forkId);
 *
 *     create2 = IODCreate2Factory(MAINNET_CREATE2FACTORY);
 *     protocolToken = IProtocolToken(MAINNET_PROTOCOL_TOKEN);
 *     governor = MAINNET_TIMELOCK_CONTROLLER;
 *     timelockController = TimelockController(payable(MAINNET_TIMELOCK_CONTROLLER));
 *     odGovernor = ODGovernor(payable(MAINNET_OD_GOVERNOR));
 *
 *     _deployerPk = uint256(vm.envBytes32('ARB_MAINNET_TEST_DEPLOYER_PK'));
 *     chainId = 42_161;
 *
 *     _systemCoinSalt = getSemiRandSalt();
 *     _vault721Salt = getSemiRandSalt();
 *
 *     run();
 *   }
 *
 *   function setupEnvironment() public override(DeployMainnet, Deploy) {
 *     super.setupEnvironment();
 *   }
 *
 *   function setupPostEnvironment() public override(DeployMainnet, Deploy) {
 *     super.setupPostEnvironment();
 *   }
 * }
 */

contract E2EDeploymentSepoliaTest is DeploySepolia, CommonDeploymentTest {
  function setUp() public override {
    uint256 forkId = vm.createFork(vm.rpcUrl('sepolia'));
    vm.selectFork(forkId);

    create2 = IODCreate2Factory(TEST_CREATE2FACTORY);
    protocolToken = IProtocolToken(SEPOLIA_PROTOCOL_TOKEN);
    governor = SEPOLIA_TIMELOCK_CONTROLLER;
    timelockController = TimelockController(payable(SEPOLIA_TIMELOCK_CONTROLLER));
    odGovernor = ODGovernor(payable(SEPOLIA_OD_GOVERNOR));

    _deployerPk = uint256(vm.envBytes32('ARB_SEPOLIA_DEPLOYER_PK'));
    chainId = 421_614;

    _systemCoinSalt = getSemiRandSalt();
    _vault721Salt = getSemiRandSalt();
    run();
  }

  function setupEnvironment() public override(DeploySepolia, Deploy) {
    super.setupEnvironment();
  }

  function setupPostEnvironment() public override(DeploySepolia, Deploy) {
    super.setupPostEnvironment();
  }
}

contract SepoliaDeploymentTest is SepoliaDeployment, CommonDeploymentTest {
  function setUp() public {
    uint256 forkId = vm.createFork(vm.rpcUrl('sepolia'));
    vm.selectFork(forkId);
    _deployerPk = uint256(vm.envBytes32('ARB_SEPOLIA_DEPLOYER_PK'));

    create2 = IODCreate2Factory(TEST_CREATE2FACTORY);
    protocolToken = IProtocolToken(SEPOLIA_PROTOCOL_TOKEN);
    governor = SEPOLIA_TIMELOCK_CONTROLLER;
    timelockController = TimelockController(payable(SEPOLIA_TIMELOCK_CONTROLLER));
    odGovernor = ODGovernor(payable(SEPOLIA_OD_GOVERNOR));

    _getEnvironmentParams();

    run();
  }

  // TODO: fix
  function test_Delegated_OP() public {
    // assertEq(ERC20Votes(GOERLI_GOV_TOKEN).delegates(address(collateralJoin[ARB])), governor);
  }
}

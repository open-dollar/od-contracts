// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {Deploy, DeployMainnet, DeployGoerli} from '@script/Deploy.s.sol';

import {ParamChecker, WETH, WSTETH, FTRG} from '@script/Params.s.sol';
import {ARB_GOERLI_GOV_TOKEN} from '@script/Registry.s.sol';
import {ERC20Votes} from '@openzeppelin/token/ERC20/extensions/ERC20Votes.sol';

import {Contracts} from '@script/Contracts.s.sol';
import {GoerliDeployment} from '@script/GoerliDeployment.s.sol';

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

  // Coin (system)
  function test_Coin_Auth() public {
    assertEq(systemCoin.authorizedAccounts(address(coinJoin)), true);
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

  function test_CollateralAuctionHouse_Auth() public {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      assertEq(collateralAuctionHouse[_cType].authorizedAccounts(address(liquidationEngine)), true);
    }
  }

  function test_CollateralAuctionHouse_Params() public view {
    ParamChecker._checkParams(
      address(collateralAuctionHouseFactory), abi.encode(_collateralAuctionHouseSystemCoinParams)
    );
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      ParamChecker._checkCParams(
        address(collateralAuctionHouseFactory), _cType, abi.encode(_collateralAuctionHouseCParams[_cType])
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
    assertEq(oracleRelayer.authorizedAccounts(_target), _permission);
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
    assertEq(uniV3RelayerFactory.authorizedAccounts(_target), _permission);
    assertEq(camelotRelayerFactory.authorizedAccounts(_target), _permission);
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

contract E2EDeploymentMainnetTest is DeployMainnet, CommonDeploymentTest {
  uint256 FORK_BLOCK = 99_000_000;

  function setUp() public override {
    // vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);
    uint256 forkId = vm.createFork(vm.rpcUrl('mainnet'));
    vm.selectFork(forkId);

    // governor = address(69);
    governor = address(0x37c5B029f9c3691B3d47cb024f84E5E257aEb0BB);

    super.setUp();
    run();
  }

  function setupEnvironment() public override(DeployMainnet, Deploy) {
    super.setupEnvironment();
  }
}

contract E2EDeploymentGoerliTest is DeployGoerli, CommonDeploymentTest {
  uint256 FORK_BLOCK = 10_000_000;

  function setUp() public override {
    // vm.createSelectFork(vm.rpcUrl('goerli'), FORK_BLOCK);
    uint256 forkId = vm.createFork(vm.rpcUrl('goerli'));
    vm.selectFork(forkId);

    // governor = address(69);
    governor = address(0x37c5B029f9c3691B3d47cb024f84E5E257aEb0BB);

    super.setUp();
    run();
  }

  function setupEnvironment() public override(DeployGoerli, Deploy) {
    super.setupEnvironment();
  }
}

contract GoerliDeploymentTest is GoerliDeployment, CommonDeploymentTest {
  function setUp() public {
    // vm.createSelectFork(vm.rpcUrl('goerli'), GOERLI_DEPLOYMENT_BLOCK);
    uint256 forkId = vm.createFork(vm.rpcUrl('goerli'));
    vm.selectFork(forkId);

    _getEnvironmentParams();
  }

  function test_Delegated_OP() public {
    assertEq(ERC20Votes(ARB_GOERLI_GOV_TOKEN).delegates(address(collateralJoin[FTRG])), governor);
  }
}

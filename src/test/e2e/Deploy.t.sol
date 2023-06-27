// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {Deploy, DeployMainnet, DeployGoerli} from '@script/Deploy.s.sol';

import {ParamChecker, WETH, WSTETH} from '@script/Params.s.sol';

import {Contracts} from '@script/Contracts.s.sol';
import {GoerliDeployment} from '@script/GoerliDeployment.s.sol';

abstract contract CommonDeploymentTest is HaiTest, Deploy {
  // SAFEEngine
  function test_SAFEEngine_Auth() public {
    assertEq(safeEngine.authorizedAccounts(address(oracleRelayer)), 1);
    assertEq(safeEngine.authorizedAccounts(address(taxCollector)), 1);
    assertEq(safeEngine.authorizedAccounts(address(debtAuctionHouse)), 1);
    assertEq(safeEngine.authorizedAccounts(address(liquidationEngine)), 1);

    assert(safeEngine.canModifySAFE(address(accountingEngine), address(surplusAuctionHouse)));
  }

  function test_SAFEEngine_Params() public view {
    ParamChecker._checkParams(address(safeEngine), abi.encode(_safeEngineParams));
  }

  // AccountingEngine
  function test_AccountingEntine_Auth() public {
    assertEq(accountingEngine.authorizedAccounts(address(liquidationEngine)), 1);
  }

  function test_AccountingEntine_Params() public view {
    ParamChecker._checkParams(address(accountingEngine), abi.encode(_accountingEngineParams));
  }

  // Coin (system)
  function test_Coin_Auth() public {
    assertEq(systemCoin.authorizedAccounts(address(coinJoin)), 1);
  }

  // SurplusAuctionHouse
  function test_SurplusAuctionHouse_Auth() public {
    assertEq(surplusAuctionHouse.authorizedAccounts(address(accountingEngine)), 1);
  }

  function test_SurplusAuctionHouse_Params() public view {
    ParamChecker._checkParams(address(surplusAuctionHouse), abi.encode(_surplusAuctionHouseParams));
  }

  // DebtAuctionHouse
  function test_DebtAuctionHouse_Auth() public {
    assertEq(debtAuctionHouse.authorizedAccounts(address(accountingEngine)), 1);
  }

  function test_DebtAuctionHouse_Params() public view {
    ParamChecker._checkParams(address(debtAuctionHouse), abi.encode(_debtAuctionHouseParams));
  }

  function test_CollateralAuctionHouse_Auth() public {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      assertEq(collateralAuctionHouse[_cType].authorizedAccounts(address(liquidationEngine)), 1);
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
  }

  function _test_Authorizations(address _target, bool _shouldHavePermissions) internal {
    uint256 _permission = _shouldHavePermissions ? 1 : 0;

    // base contracts
    assertEq(safeEngine.authorizedAccounts(_target), _permission);
    assertEq(oracleRelayer.authorizedAccounts(_target), _permission);
    assertEq(taxCollector.authorizedAccounts(_target), _permission);
    assertEq(stabilityFeeTreasury.authorizedAccounts(_target), _permission);
    assertEq(liquidationEngine.authorizedAccounts(_target), _permission);
    assertEq(accountingEngine.authorizedAccounts(_target), _permission);
    assertEq(surplusAuctionHouse.authorizedAccounts(_target), _permission);
    assertEq(debtAuctionHouse.authorizedAccounts(_target), _permission);

    assertEq(collateralJoinFactory.authorizedAccounts(_target), _permission);
    assertEq(collateralAuctionHouseFactory.authorizedAccounts(_target), _permission);

    // tokens
    assertEq(systemCoin.authorizedAccounts(_target), _permission);
    assertEq(protocolToken.authorizedAccounts(_target), _permission);

    // token adapters
    assertEq(coinJoin.authorizedAccounts(_target), _permission);

    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      assertEq(collateralAuctionHouse[_cType].authorizedAccounts(_target), _permission);
    }
  }
}

contract E2EDeploymentMainnetTest is DeployMainnet, CommonDeploymentTest {
  uint256 FORK_BLOCK = 99_000_000;

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);
    governor = address(69);
    super.setUp();
    run();
  }

  function _setupEnvironment() internal override(DeployMainnet, Deploy) {
    super._setupEnvironment();
  }
}

contract E2EDeploymentGoerliTest is DeployGoerli, CommonDeploymentTest {
  uint256 FORK_BLOCK = 10_000_000;

  function setUp() public override {
    vm.createSelectFork(vm.rpcUrl('goerli'), FORK_BLOCK);
    governor = address(69);
    super.setUp();
    run();
  }

  function _setupEnvironment() internal override(DeployGoerli, Deploy) {
    super._setupEnvironment();
  }
}

contract GoerliDeploymentTest is GoerliDeployment, CommonDeploymentTest {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('goerli'), GOERLI_DEPLOYMENT_BLOCK);
    _getEnvironmentParams();
  }

  function test_Oracles_Auth() public {
    assertEq(haiOracleForTest.authorizedAccounts(deployer), 0);
    assertEq(haiOracleForTest.authorizedAccounts(governor), 1);

    assertEq(opEthOracleForTest.authorizedAccounts(deployer), 0);
    assertEq(opEthOracleForTest.authorizedAccounts(governor), 1);
  }
}

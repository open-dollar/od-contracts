// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {
  ISAFEEngine,
  ITaxCollector,
  IAccountingEngine,
  ILiquidationEngine,
  IStabilityFeeTreasury,
  ISurplusAuctionHouse,
  IDebtAuctionHouse,
  ICollateralAuctionHouse,
  IOracleRelayer,
  ICoinJoin,
  IETHJoin,
  ICollateralJoin,
  IERC20,
  CoinForTest,
  IModifiable,
  IAuthorizable
} from '@script/Contracts.s.sol';
import {IAccountingEngine} from '@interfaces/IAccountingEngine.sol';
import {Deploy, DeployMainnet, DeployGoerli} from '@script/Deploy.s.sol';

import {WETH, WSTETH} from '@script/Params.s.sol';

import {Contracts} from '@script/Contracts.s.sol';

abstract contract CommonDeploymentTest is HaiTest, Deploy {
  // SAFEEngine
  function test_SAFEEngine_Auth() public {
    assertEq(safeEngine.authorizedAccounts(address(oracleRelayer)), 1);
    assertEq(safeEngine.authorizedAccounts(address(taxCollector)), 1);
    assertEq(safeEngine.authorizedAccounts(address(debtAuctionHouse)), 1);
    assertEq(safeEngine.authorizedAccounts(address(liquidationEngine)), 1);

    assert(safeEngine.canModifySAFE(address(accountingEngine), address(surplusAuctionHouse)));
  }

  // AccountingEngine
  function test_AccountingEntine_Auth() public {
    assertEq(accountingEngine.authorizedAccounts(address(liquidationEngine)), 1);
  }

  // Coin (system)
  function test_Coin_Auth() public {
    assertEq(coin.authorizedAccounts(address(coinJoin)), 1);
  }

  // SurplusAuctionHouse
  function test_SurplusAuctionHouse_Auth() public {
    assertEq(surplusAuctionHouse.authorizedAccounts(address(accountingEngine)), 1);
  }

  // DebtAuctionHouse
  function test_DebtAuctionHouse_Auth() public {
    assertEq(debtAuctionHouse.authorizedAccounts(address(accountingEngine)), 1);
  }

  function test_CollateralAuctionHouse_Auth() public {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      assertEq(collateralAuctionHouse[_cType].authorizedAccounts(address(liquidationEngine)), 1);
    }
  }

  function test_ETHCollateralAuctionHouse_Auth() public {
    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      assertEq(collateralAuctionHouse[_cType].authorizedAccounts(address(liquidationEngine)), 1);
    }
  }

  function test_Revoke_Auth() public {
    // base contracts
    assertEq(safeEngine.authorizedAccounts(deployer), 0);
    assertEq(oracleRelayer.authorizedAccounts(deployer), 0);
    assertEq(taxCollector.authorizedAccounts(deployer), 0);
    assertEq(stabilityFeeTreasury.authorizedAccounts(deployer), 0);
    assertEq(liquidationEngine.authorizedAccounts(deployer), 0);
    assertEq(accountingEngine.authorizedAccounts(deployer), 0);
    assertEq(surplusAuctionHouse.authorizedAccounts(deployer), 0);
    assertEq(debtAuctionHouse.authorizedAccounts(deployer), 0);

    // tokens
    assertEq(coin.authorizedAccounts(deployer), 0);
    assertEq(protocolToken.authorizedAccounts(deployer), 0);

    // token adapters and collateral auction houses
    assertEq(coinJoin.authorizedAccounts(deployer), 0);

    for (uint256 _i; _i < collateralTypes.length; _i++) {
      bytes32 _cType = collateralTypes[_i];
      assertEq(collateralJoin[_cType].authorizedAccounts(deployer), 0);
      assertEq(collateralAuctionHouse[_cType].authorizedAccounts(deployer), 0);
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

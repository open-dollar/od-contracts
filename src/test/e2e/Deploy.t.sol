// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {PRBTest} from 'prb-test/PRBTest.sol';
import {
  SAFEEngine,
  TaxCollector,
  AccountingEngine,
  LiquidationEngine,
  StabilityFeeTreasury,
  SurplusAuctionHouse,
  DebtAuctionHouse,
  CollateralAuctionHouse,
  OracleRelayer,
  Coin,
  CoinJoin,
  ETHJoin,
  CollateralJoin
} from '@script/Contracts.s.sol';
import '@script/Params.s.sol';
import {Deploy} from '@script/Deploy.s.sol';

contract E2EDeploymentTest is PRBTest {
  Deploy public deployment;

  function setUp() public {
    deployment = new Deploy();
    deployment.run();
  }

  // SAFEEngine
  function test_SAFEEngine_Auth() public {
    SAFEEngine _safeEngine = deployment.safeEngine();

    assertEq(_safeEngine.authorizedAccounts(address(deployment.oracleRelayer())), 1);
    assertEq(_safeEngine.authorizedAccounts(address(deployment.taxCollector())), 1);
    assertEq(_safeEngine.authorizedAccounts(address(deployment.debtAuctionHouse())), 1);
    assertEq(_safeEngine.authorizedAccounts(address(deployment.liquidationEngine())), 1);

    assert(_safeEngine.canModifySAFE(address(deployment.accountingEngine()), address(deployment.surplusAuctionHouse())));
  }

  function test_SAFEEngine_Params() public {
    SAFEEngine _safeEngine = deployment.safeEngine();

    (uint256 _safeDebtCeiling,) = _safeEngine.params();

    assertEq(_safeDebtCeiling, type(uint256).max);
  }

  // TaxCollector
  function test_TaxCollector_Params() public {
    TaxCollector _taxCollector = deployment.taxCollector();

    assertEq(address(_taxCollector.safeEngine()), address(deployment.safeEngine()));
  }

  // AccountingEngine
  function test_AccountingEntine_Auth() public {
    AccountingEngine _accountingEngine = deployment.accountingEngine();

    assertEq(_accountingEngine.authorizedAccounts(address(deployment.liquidationEngine())), 1);
  }

  function test_AccountingEngine_Params() public {
    AccountingEngine _accountingEngine = deployment.accountingEngine();

    assertEq(address(_accountingEngine.safeEngine()), address(deployment.safeEngine()));
    assertEq(address(_accountingEngine.surplusAuctionHouse()), address(deployment.surplusAuctionHouse()));
    assertEq(address(_accountingEngine.debtAuctionHouse()), address(deployment.debtAuctionHouse()));
  }

  // LiquidationEngine
  function test_LiquidationEngine_Params() public {
    LiquidationEngine _liquidationEngine = deployment.liquidationEngine();

    assertEq(address(_liquidationEngine.safeEngine()), address(deployment.safeEngine()));
    // on script
    assertEq(address(_liquidationEngine.accountingEngine()), address(deployment.accountingEngine()));
  }

  // StabilityFeeTreasury
  function test_StabilityFeeTreasury_Params() public {
    StabilityFeeTreasury _sfTreasury = deployment.stabilityFeeTreasury();

    assertEq(address(_sfTreasury.safeEngine()), address(deployment.safeEngine()));
    assertEq(address(_sfTreasury.extraSurplusReceiver()), address(deployment.accountingEngine()));
    assertEq(address(_sfTreasury.coinJoin()), address(deployment.coinJoin()));
    assertEq(address(_sfTreasury.systemCoin()), address(deployment.coin()));

    assertEq(deployment.coin().allowance(address(_sfTreasury), address(deployment.coinJoin())), type(uint256).max);
  }

  // Coin (system)
  function test_Coin_Auth() public {
    Coin _coin = deployment.coin();

    assertEq(_coin.authorizedAccounts(address(deployment.coinJoin())), 1);
  }

  // CoinJoin
  function test_CoinJoin_Params() public {
    CoinJoin _coinJoin = deployment.coinJoin();

    assertEq(address(_coinJoin.safeEngine()), address(deployment.safeEngine()));
  }

  // ETHJoin
  function test_ETHJoin_Params() public {
    ETHJoin _ethJoin = deployment.ethJoin();

    assertEq(address(_ethJoin.safeEngine()), address(deployment.safeEngine()));
  }

  // CollateralJoin
  function test_CollateralJoin_Params() public {
    CollateralJoin _collateralJoin = deployment.collateralJoin(TKN);

    assertEq(address(_collateralJoin.safeEngine()), address(deployment.safeEngine()));
  }

  // SurplusAuctionHouse
  function test_SurplusAuctionHouse_Auth() public {
    SurplusAuctionHouse _surplusAuctionHouse = deployment.surplusAuctionHouse();

    assertEq(_surplusAuctionHouse.authorizedAccounts(address(deployment.accountingEngine())), 1);
  }

  function test_SurplusAuctionHouse_Params() public {
    SurplusAuctionHouse _surplusAuctionHouse = deployment.surplusAuctionHouse();

    assertEq(address(_surplusAuctionHouse.safeEngine()), address(deployment.safeEngine()));
    assertEq(address(_surplusAuctionHouse.protocolToken()), address(deployment.protocolToken()));
    assertEq(_surplusAuctionHouse.recyclingPercentage(), 50);
  }

  // DebtAuctionHouse
  function test_DebtAuctionHouse_Auth() public {
    DebtAuctionHouse _debtAuctionHouse = deployment.debtAuctionHouse();

    assertEq(_debtAuctionHouse.authorizedAccounts(address(deployment.accountingEngine())), 1);
  }

  function test_DebtAuctionHouse_Params() public {
    DebtAuctionHouse _debtAuctionHouse = deployment.debtAuctionHouse();

    assertEq(address(_debtAuctionHouse.safeEngine()), address(deployment.safeEngine()));
    assertEq(address(_debtAuctionHouse.protocolToken()), address(deployment.protocolToken()));
  }

  function test_CollateralAuctionHouse_Auth() public {
    CollateralAuctionHouse _collateralAuctionHouse = deployment.collateralAuctionHouse(TKN);

    assertEq(_collateralAuctionHouse.authorizedAccounts(address(deployment.liquidationEngine())), 1);
  }

  function test_CollateralAuctionHouse_Params() public {
    CollateralAuctionHouse _collateralAuctionHouse = deployment.collateralAuctionHouse(TKN);

    assertEq(address(_collateralAuctionHouse.safeEngine()), address(deployment.safeEngine()));
    assertEq(address(_collateralAuctionHouse.liquidationEngine()), address(deployment.liquidationEngine()));
    assertEq(_collateralAuctionHouse.collateralType(), bytes32('TKN'));
  }

  function test_ETHCollateralAuctionHouse_Auth() public {
    CollateralAuctionHouse _collateralAuctionHouse = deployment.collateralAuctionHouse(ETH_A);

    assertEq(_collateralAuctionHouse.authorizedAccounts(address(deployment.liquidationEngine())), 1);
  }

  function test_ETHCollateralAuctionHouse_Params() public {
    CollateralAuctionHouse _collateralAuctionHouse = deployment.collateralAuctionHouse(ETH_A);

    assertEq(address(_collateralAuctionHouse.safeEngine()), address(deployment.safeEngine()));
    assertEq(address(_collateralAuctionHouse.liquidationEngine()), address(deployment.liquidationEngine()));
    assertEq(_collateralAuctionHouse.collateralType(), bytes32('ETH-A'));
  }

  // OracleRelayer
  function test_OracleRelayer_Params() public {
    OracleRelayer _oracleRelayer = deployment.oracleRelayer();

    assertEq(address(_oracleRelayer.safeEngine()), address(deployment.safeEngine()));

    // TODO: replace for actual oracle
    assertEq(address(_oracleRelayer.orcl(bytes32('ETH-A'))), address(deployment.oracle(ETH_A)));
    assertEq(address(_oracleRelayer.orcl(bytes32('TKN'))), address(deployment.oracle(TKN)));
  }

  function test_Revoke_Auth() public {
    address _deployer = address(deployment.deployer());
    deployment.revoke();

    // base contracts
    assertEq(deployment.safeEngine().authorizedAccounts(_deployer), 0);
    assertEq(deployment.oracleRelayer().authorizedAccounts(_deployer), 0);
    assertEq(deployment.taxCollector().authorizedAccounts(_deployer), 0);
    assertEq(deployment.stabilityFeeTreasury().authorizedAccounts(_deployer), 0);
    assertEq(deployment.liquidationEngine().authorizedAccounts(_deployer), 0);
    assertEq(deployment.accountingEngine().authorizedAccounts(_deployer), 0);
    assertEq(deployment.surplusAuctionHouse().authorizedAccounts(_deployer), 0);
    assertEq(deployment.debtAuctionHouse().authorizedAccounts(_deployer), 0);

    // tokens
    assertEq(deployment.coin().authorizedAccounts(_deployer), 0);
    assertEq(deployment.protocolToken().authorizedAccounts(_deployer), 0);

    // token adapters
    assertEq(deployment.coinJoin().authorizedAccounts(_deployer), 0);
    assertEq(deployment.ethJoin().authorizedAccounts(_deployer), 0);
    assertEq(deployment.collateralJoin(TKN).authorizedAccounts(_deployer), 0);

    // collateral auction houses
    assertEq(deployment.collateralAuctionHouse(ETH_A).authorizedAccounts(_deployer), 0);
    assertEq(deployment.collateralAuctionHouse(ETH_A).authorizedAccounts(_deployer), 0);
  }
}

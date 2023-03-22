pragma solidity 0.6.7;

import {DSTest} from 'ds-test/test.sol';
import {
  Deploy,
  SAFEEngine,
  TaxCollector,
  AccountingEngine,
  LiquidationEngine,
  StabilityFeeTreasury,
  CoinSavingsAccount,
  MixedStratSurplusAuctionHouse as SurplusAuctionHouse,
  DebtAuctionHouse,
  IncreasingDiscountCollateralAuctionHouse as CollateralAuctionHouse,
  OracleRelayer,
  Coin,
  CoinJoin
} from '../../../script/Deploy.s.sol';

contract DeploymentTest is DSTest {
  Deploy public deployment;

  function setUp() public {
    deployment = new Deploy();
    deployment.run();
  }

  // SAFEEngine
  function test_deployment_auth_safe_engine() public {
    SAFEEngine _safeEngine = deployment.safeEngine();

    assertEq(_safeEngine.authorizedAccounts(address(deployment.oracleRelayer())), 1);
    assertEq(_safeEngine.authorizedAccounts(address(deployment.taxCollector())), 1);
    assertEq(_safeEngine.authorizedAccounts(address(deployment.coinSavingsAccount())), 1);
    assertEq(_safeEngine.authorizedAccounts(address(deployment.debtAuctionHouse())), 1);
    assertEq(_safeEngine.authorizedAccounts(address(deployment.liquidationEngine())), 1);

    assert(_safeEngine.canModifySAFE(address(deployment.accountingEngine()), address(deployment.surplusAuctionHouse())));
  }

  function test_deployment_params_safe_engine() public {
    SAFEEngine _safeEngine = deployment.safeEngine();

    assertEq(_safeEngine.safeDebtCeiling(), uint256(-1));
  }

  // TaxCollector
  function test_deployment_params_tax_collector() public {
    TaxCollector _taxCollector = deployment.taxCollector();

    assertEq(address(_taxCollector.safeEngine()), address(deployment.safeEngine()));
  }

  // AccountingEngine
  function test_deployment_auth_accounting_engine() public {
    AccountingEngine _accountingEngine = deployment.accountingEngine();

    assertEq(_accountingEngine.authorizedAccounts(address(deployment.liquidationEngine())), 1);
  }

  function test_deployment_params_accounting_engine() public {
    AccountingEngine _accountingEngine = deployment.accountingEngine();

    assertEq(address(_accountingEngine.safeEngine()), address(deployment.safeEngine()));
    assertEq(address(_accountingEngine.surplusAuctionHouse()), address(deployment.surplusAuctionHouse()));
    assertEq(address(_accountingEngine.debtAuctionHouse()), address(deployment.debtAuctionHouse()));
  }

  // LiquidationEngine
  function test_deployment_params_liquidation_engine() public {
    LiquidationEngine _liquidationEngine = deployment.liquidationEngine();

    assertEq(address(_liquidationEngine.safeEngine()), address(deployment.safeEngine()));
    // on script
    assertEq(address(_liquidationEngine.accountingEngine()), address(deployment.accountingEngine()));
  }

  // StabilityFeeTreasury
  function test_deployment_params_sf_treasury() public {
    StabilityFeeTreasury _sfTreasury = deployment.stabilityFeeTreasury();

    assertEq(address(_sfTreasury.safeEngine()), address(deployment.safeEngine()));
    assertEq(address(_sfTreasury.extraSurplusReceiver()), address(deployment.accountingEngine()));
    assertEq(address(_sfTreasury.coinJoin()), address(deployment.coinJoin()));
    assertEq(address(_sfTreasury.systemCoin()), address(deployment.coin()));

    assertEq(deployment.coin().allowance(address(_sfTreasury), address(deployment.coinJoin())), uint256(-1));
  }

  // CoinSavingsAccount
  function test_deployment_params_coin_savings_account() public {
    CoinSavingsAccount _coinSavingsAcc = deployment.coinSavingsAccount();

    assertEq(address(_coinSavingsAcc.safeEngine()), address(deployment.safeEngine()));
  }

  // Coin (system)
  function test_deployment_auth_coin() public {
    Coin _coin = deployment.coin();

    assertEq(_coin.authorizedAccounts(address(deployment.coinJoin())), 1);
  }

  // CoinJoin
  function test_deployment_params_coin_join() public {
    CoinJoin _coinJoin = deployment.coinJoin();

    assertEq(address(_coinJoin.safeEngine()), address(deployment.safeEngine()));
  }

  // TODO: CollateralJoin

  // SurplusAuctionHouse
  function test_deployment_auth_surplus_auction_house() public {
    SurplusAuctionHouse _surplusAuctionHouse = deployment.surplusAuctionHouse();

    assertEq(_surplusAuctionHouse.authorizedAccounts(address(deployment.accountingEngine())), 1);
  }

  function test_deployment_params_surplus_auction_house() public {
    SurplusAuctionHouse _surplusAuctionHouse = deployment.surplusAuctionHouse();

    assertEq(address(_surplusAuctionHouse.safeEngine()), address(deployment.safeEngine()));
    assertEq(address(_surplusAuctionHouse.protocolToken()), address(deployment.protocolToken()));
  }

  // DebtAuctionHouse
  function test_deployment_auth_debt_auction_house() public {
    DebtAuctionHouse _debtAuctionHouse = deployment.debtAuctionHouse();

    assertEq(_debtAuctionHouse.authorizedAccounts(address(deployment.accountingEngine())), 1);
  }

  function test_deployment_params_debt_auction_house() public {
    DebtAuctionHouse _debtAuctionHouse = deployment.debtAuctionHouse();

    assertEq(address(_debtAuctionHouse.safeEngine()), address(deployment.safeEngine()));
    assertEq(address(_debtAuctionHouse.protocolToken()), address(deployment.protocolToken()));
  }

  // TODO: CollateralAuctionHouse
  function test_deployment_auth_collateral_auction_house() public {
    CollateralAuctionHouse _collateralAuctionHouse = deployment.collateralAuctionHouse();

    assertEq(_collateralAuctionHouse.authorizedAccounts(address(deployment.liquidationEngine())), 1);
  }

  function test_deployment_params_collateral_auction_house() public {
    CollateralAuctionHouse _collateralAuctionHouse = deployment.collateralAuctionHouse();

    assertEq(address(_collateralAuctionHouse.safeEngine()), address(deployment.safeEngine()));
    assertEq(address(_collateralAuctionHouse.liquidationEngine()), address(deployment.liquidationEngine()));
    assertEq(_collateralAuctionHouse.collateralType(), deployment.COLLATERAL_TYPE());
  }

  // OracleRelayer
  function test_deployment_params_debt_oracle_relayer() public {
    OracleRelayer _oracleRelayer = deployment.oracleRelayer();

    assertEq(address(_oracleRelayer.safeEngine()), address(deployment.safeEngine()));

    // TODO: replace for actual oracle
    assertEq(address(_oracleRelayer.orcl(deployment.COLLATERAL_TYPE())), address(deployment.oracleForTest()));
  }

  function test_deployment_revoke_auth() public {
    // TODO: fix test
    // address _deployer = address(deployment.deployer());
    // deployment.revoke();

    // assertEq(deployment.safeEngine().authorizedAccounts(_deployer), 0);
    // ...
  }
}

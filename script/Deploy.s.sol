pragma solidity 0.8.19;

import 'forge-std/Script.sol';

import {SAFEEngine} from '../src/contracts/SAFEEngine.sol';
import {TaxCollector} from '../src/contracts/TaxCollector.sol';
import {AccountingEngine} from '../src/contracts/AccountingEngine.sol';
import {LiquidationEngine} from '../src/contracts/LiquidationEngine.sol';
import {CoinJoin} from '../src/contracts/utils/CoinJoin.sol';
import {ETHJoin} from '../src/contracts/utils/ETHJoin.sol';
import {MixedStratSurplusAuctionHouse} from '../src/contracts/SurplusAuctionHouse.sol';
import {DebtAuctionHouse} from '../src/contracts/DebtAuctionHouse.sol';
import {IncreasingDiscountCollateralAuctionHouse} from '../src/contracts/CollateralAuctionHouse.sol';
import {Coin} from '../src/contracts/utils/Coin.sol';
import {GlobalSettlement} from '../src/contracts/GlobalSettlement.sol';
// TODO: import ESM to repo
// import {ESM} from "../src/contracts/ESM.sol";
import {StabilityFeeTreasury} from '../src/contracts/StabilityFeeTreasury.sol';
import {OracleRelayer} from '../src/contracts/OracleRelayer.sol';

import {OracleForTest} from '../src/contracts/for-test/OracleForTest.sol';

contract Deploy is Script {
  bytes32 public constant COLLATERAL_TYPE = bytes32('COLLATERAL');

  SAFEEngine public safeEngine;
  TaxCollector public taxCollector;
  AccountingEngine public accountingEngine;
  LiquidationEngine public liquidationEngine;
  StabilityFeeTreasury public stabilityFeeTreasury;

  Coin public coin;
  Coin public protocolToken;
  CoinJoin public coinJoin;
  ETHJoin public collateralJoin;

  MixedStratSurplusAuctionHouse public surplusAuctionHouse;
  DebtAuctionHouse public debtAuctionHouse;
  IncreasingDiscountCollateralAuctionHouse public collateralAuctionHouse;

  OracleRelayer public oracleRelayer;
  OracleForTest public oracleForTest;

  GlobalSettlement public globalSettlement;
  // ESM public esm;

  uint256 public chainId;
  address public deployer;
  uint256 internal _deployerPk = 69; // for tests

  function run() public {
    vm.startBroadcast(_deployerPk);

    // deploy SAFEEngine and OracleRelayer
    safeEngine = new SAFEEngine();
    oracleRelayer = new OracleRelayer(address(safeEngine));
    safeEngine.addAuthorization(address(oracleRelayer));

    // deploy Coin and CoinJoin
    coin = new Coin('HAI Index Token', 'HAI', chainId);
    coinJoin = new CoinJoin(address(safeEngine), address(coin));
    coin.addAuthorization(address(coinJoin));
    safeEngine.addAuthorization(address(coinJoin));

    // deploy ETHJoin
    collateralJoin = new ETHJoin(address(safeEngine), COLLATERAL_TYPE);
    safeEngine.addAuthorization(address(collateralJoin));

    // deploy TaxCollector
    taxCollector = new TaxCollector(address(safeEngine));
    safeEngine.addAuthorization(address(taxCollector));

    // deploy AuctionHouses
    protocolToken = new Coin('Protocol Token', 'TKN', chainId);

    surplusAuctionHouse = new MixedStratSurplusAuctionHouse(address(safeEngine), address(protocolToken));
    debtAuctionHouse = new DebtAuctionHouse(address(safeEngine), address(protocolToken));
    safeEngine.addAuthorization(address(debtAuctionHouse));

    // deploy AccountingEngine
    accountingEngine =
      new AccountingEngine(address(safeEngine), address(surplusAuctionHouse), address(debtAuctionHouse));

    debtAuctionHouse.modifyParameters('accountingEngine', address(accountingEngine));
    taxCollector.modifyParameters('primaryTaxReceiver', address(accountingEngine));

    surplusAuctionHouse.addAuthorization(address(accountingEngine));
    debtAuctionHouse.addAuthorization(address(accountingEngine));

    // deploy StabilityFeeTreasury
    stabilityFeeTreasury = new StabilityFeeTreasury(
          address(safeEngine),
          address(accountingEngine),
          address(coinJoin)
        );

    // deploy LiquidationEngine
    liquidationEngine = new LiquidationEngine(address(safeEngine));
    liquidationEngine.modifyParameters('accountingEngine', address(accountingEngine));

    safeEngine.addAuthorization(address(liquidationEngine));
    accountingEngine.addAuthorization(address(liquidationEngine));

    // TODO: deploy ESM, GlobalSettlement, SettlementSurplusAuctioneer

    // deploy CollateralAuctionHouse
    collateralAuctionHouse =
      new IncreasingDiscountCollateralAuctionHouse(address(safeEngine), address(liquidationEngine), COLLATERAL_TYPE);
    collateralAuctionHouse.addAuthorization(address(liquidationEngine));
    // collateralAuctionHouse.addAuthorization(address(globalSettlement));

    liquidationEngine.modifyParameters(COLLATERAL_TYPE, 'collateralAuctionHouse', address(collateralAuctionHouse));
    liquidationEngine.addAuthorization(address(collateralAuctionHouse));

    // TODO: replace for actual oracle
    oracleForTest = new OracleForTest();
    oracleRelayer.modifyParameters(COLLATERAL_TYPE, 'orcl', address(oracleForTest));

    safeEngine.initializeCollateralType(COLLATERAL_TYPE);
    taxCollector.initializeCollateralType(COLLATERAL_TYPE);

    // setup
    safeEngine.modifyParameters('globalDebtCeiling', UINT256_MAX);
    safeEngine.modifyParameters(COLLATERAL_TYPE, 'debtCeiling', UINT256_MAX);
    safeEngine.modifyParameters(COLLATERAL_TYPE, 'safetyPrice', 1e18);

    vm.stopBroadcast();
  }

  function revoke() public {
    safeEngine.removeAuthorization(deployer);
    oracleRelayer.removeAuthorization(deployer);
    coin.removeAuthorization(deployer);
    coinJoin.removeAuthorization(deployer);
    taxCollector.removeAuthorization(deployer);
    protocolToken.removeAuthorization(deployer);
    surplusAuctionHouse.removeAuthorization(deployer);
    debtAuctionHouse.removeAuthorization(deployer);
    collateralAuctionHouse.removeAuthorization(deployer);
    stabilityFeeTreasury.removeAuthorization(deployer);
    liquidationEngine.removeAuthorization(deployer);
    accountingEngine.removeAuthorization(deployer);
  }
}

contract DeployMainnet is Deploy {
  constructor() {
    _deployerPk = uint256(vm.envBytes32('OP_MAINNET_DEPLOYER_PK'));
    deployer = vm.addr(_deployerPk);
    chainId = 10;
  }
}

contract DeployGoerli is Deploy {
  constructor() {
    _deployerPk = uint256(vm.envBytes32('OP_GOERLI_DEPLOYER_PK'));
    deployer = vm.addr(_deployerPk);
    chainId = 420;
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Contracts.s.sol';
import {GoerliParams, WETH, OP, WBTC, STONES, TOTEM} from '@script/GoerliParams.s.sol';

abstract contract GoerliDeployment is Contracts, GoerliParams {
  uint256 constant GOERLI_DEPLOYMENT_BLOCK = 10_432_866;

  // --- ERC20s ---
  ERC20ForTestnet constant ERC20_WBTC = ERC20ForTestnet(0xf1FDB809f41c187cE6F2A4C8cC6562Ba7479B4EF);
  ERC20ForTestnet constant ERC20_STONES = ERC20ForTestnet(0x4FC4CB45A812AE5d85bE39b6D7fc9D169405a31F);
  ERC20ForTestnet constant ERC20_TOTEM = ERC20ForTestnet(0xE3Efbd4fafD521dAEa38aDC6D1A1bD66583D5da4);

  // --- Factory utils ---
  bool hasCollateralJoinFactory = false;
  bool hasCollateralAuctionHouseFactory = false;

  /**
   * @notice All the addresses that were deployed in the Goerli deployment, in order of creation
   * @dev    This is used to import the deployed contracts to the test scripts
   */
  constructor() {
    // Address to delegate permissions to
    delegate = 0x58F84023DC3E0941Faa5904E974BAc5bfF3E047f;

    haiOracleForTest = OracleForTestnet(0x0256791C87b519e45DEFbf2c94D8DE8ed7C7111a);
    opEthOracleForTest = OracleForTestnet(0x792910b35954c9Ac2F1C4A5DD888f4d46e3472Ba);
    delayedOracle[WETH] = DelayedOracle(0x74558a1470c714BB5E24a6ba998905Ee5F3F0A25);
    delayedOracle[OP] = DelayedOracle(0x6171f9dB883E3bcC1804Ef17Eb1199133E27058D);
    systemCoin = SystemCoin(0xEaE90F3b07fBE00921173298FF04f416398f7101);
    protocolToken = ProtocolToken(0x64ff820bbD2947B2f2D4355D4852F17eb0156D9A);
    safeEngine = SAFEEngine(0xDfd2D62b3eC9BF6F52547c570B5AC2136D9756E4);
    oracleRelayer = OracleRelayer(0xca53F197A4A3C72F9954e34906DFC59148Ce653f);
    liquidationEngine = LiquidationEngine(0x389b9Eb0cDEAedf96d0dF8e4caA72b5cA5672870);
    coinJoin = CoinJoin(0x3217B0aBcaAC50898F4826f0C502dEd9AB8eae53);
    surplusAuctionHouse = SurplusAuctionHouse(0xa65394B23d7c6C2B3aBe9B9ed69a527E2026f855);
    debtAuctionHouse = DebtAuctionHouse(0x8F7cFe960F12710B1Fe1F3ef4352D3530209598A);
    accountingEngine = AccountingEngine(0xc922644df8E6336c6DFc997e29602EF4aba51c8c);
    taxCollector = TaxCollector(0x1A88AB748C17E62CD99a2b7162EA0dD8AB7A059A);
    stabilityFeeTreasury = StabilityFeeTreasury(0xFAD4f858867D7aB4Bd7b80c611287abF4B139986);
    globalSettlement = GlobalSettlement(0xFd4fB8e5f11A3FD403761a832bC35F31d5579B83);
    dsProxyFactory = HaiProxyFactory(0xC832Ea7C08c381b1F4726894684F7Bf1538E1dEa);
    proxyRegistry = HaiProxyRegistry(0x558Cd657b65b7DFb6B4c65d55F17247810b9C12a);
    safeManager = HaiSafeManager(0x5325A56148f67b26FaBDc7EbB30686120a98736c);
    proxyActions = BasicActions(0xf046D565170C41E87C29FB40b907fdCf26AC9ac6);
    collateralJoin[WETH] = CollateralJoin(0x69DE387041C3056ec96aEFb432A546EAe4394da6);
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0x80D7ED55d9f7623a21580adb6e4442C982Cb51aF);
    collateralJoin[OP] = CollateralJoin(0xA59A8a069284e52B8c761d7e0AC2129733ACCBF6);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(0x8C2Be56f48802c2E4B98a5a02ffD1BAC0925e213);
    pidController = PIDController(0xb1cFf62Dcf1761f49fc0056d85F8Bd25afdC1e14);
    pidRateSetter = PIDRateSetter(0x4049Cc595c2F522BBAA9C3c3C34E0629258B9d47);
  }
}

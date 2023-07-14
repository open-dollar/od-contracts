// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Contracts.s.sol';
import {GoerliParams, WETH, OP, WBTC, STONES, TOTEM} from '@script/GoerliParams.s.sol';
// import {OP_WETH, OP_OPTIMISM} from '@script/Registry.s.sol';
import {ARB_WETH, ARB_GOV} from '@script/Registry.s.sol';

abstract contract GoerliDeployment is Contracts, GoerliParams {
  uint256 constant GOERLI_DEPLOYMENT_BLOCK = 11_653_534;

  // --- Mintable ERC20s ---
  ERC20ForTestnet constant ERC20_WBTC = ERC20ForTestnet(0xf1FDB809f41c187cE6F2A4C8cC6562Ba7479B4EF);
  ERC20ForTestnet constant ERC20_STONES = ERC20ForTestnet(0x4FC4CB45A812AE5d85bE39b6D7fc9D169405a31F);
  ERC20ForTestnet constant ERC20_TOTEM = ERC20ForTestnet(0xE3Efbd4fafD521dAEa38aDC6D1A1bD66583D5da4);

  /**
   * @notice All the addresses that were deployed in the Goerli deployment, in order of creation
   * @dev    This is used to import the deployed contracts to the test scripts
   */
  constructor() {
    // --- collateral types ---
    collateralTypes.push(WETH);
    collateralTypes.push(OP);
    collateralTypes.push(WBTC);
    collateralTypes.push(STONES);
    collateralTypes.push(TOTEM);

    // --- utils ---
    delegatee[OP] = governor;

    // --- ERC20s ---
    collateral[WETH] = IERC20Metadata(ARB_WETH);
    collateral[OP] = IERC20Metadata(ARB_GOV);
    collateral[WBTC] = IERC20Metadata(ERC20_WBTC);
    collateral[STONES] = IERC20Metadata(ERC20_STONES);
    collateral[TOTEM] = IERC20Metadata(ERC20_TOTEM);

    systemCoin = SystemCoin(0xEaE90F3b07fBE00921173298FF04f416398f7101);
    protocolToken = ProtocolToken(0x64ff820bbD2947B2f2D4355D4852F17eb0156D9A);

    // --- base contracts ---
    safeEngine = SAFEEngine(0xDfd2D62b3eC9BF6F52547c570B5AC2136D9756E4);
    oracleRelayer = OracleRelayer(0xca53F197A4A3C72F9954e34906DFC59148Ce653f);
    liquidationEngine = LiquidationEngine(0x389b9Eb0cDEAedf96d0dF8e4caA72b5cA5672870);
    coinJoin = CoinJoin(0x3217B0aBcaAC50898F4826f0C502dEd9AB8eae53);
    surplusAuctionHouse = SurplusAuctionHouse(0xa65394B23d7c6C2B3aBe9B9ed69a527E2026f855);
    debtAuctionHouse = DebtAuctionHouse(0x8F7cFe960F12710B1Fe1F3ef4352D3530209598A);
    accountingEngine = AccountingEngine(0xc922644df8E6336c6DFc997e29602EF4aba51c8c);
    taxCollector = TaxCollector(0x1A88AB748C17E62CD99a2b7162EA0dD8AB7A059A);
    stabilityFeeTreasury = StabilityFeeTreasury(0xFAD4f858867D7aB4Bd7b80c611287abF4B139986);
    pidController = PIDController(0xb1cFf62Dcf1761f49fc0056d85F8Bd25afdC1e14);
    pidRateSetter = PIDRateSetter(0x4049Cc595c2F522BBAA9C3c3C34E0629258B9d47);
    globalSettlement = GlobalSettlement(0xFd4fB8e5f11A3FD403761a832bC35F31d5579B83);

    // --- factories ---
    collateralJoinFactory = CollateralJoinFactory(0x484A885Da8D582753C47993B874eFc7EcB2A1a5a);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0x442Cf1CEc8759c55d40bD4A7084Fb460d6E88bF9);

    // --- token adapters ---
    collateralJoin[WETH] = CollateralJoin(0x0caF67d5d2eC5847A375c30dC8e00ecebBE42D31);
    collateralJoin[OP] = CollateralJoin(0x8d33be9374DCAA9A3E2593c80E3ab40615B11Cac);
    collateralJoin[WBTC] = CollateralJoin(0xF5b19dEDf523f6cF8ABE2bED172d15C1784AD797);
    collateralJoin[STONES] = CollateralJoin(0xD282383A65EfA60517dA7Ca2673dF54e70AD7b6a);
    collateralJoin[TOTEM] = CollateralJoin(0x1867F40224c053e0893581Faf527AC5238cEfcBA);

    // --- collateral auction houses ---
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0x46f7a52A5543cC5068dc7aF31aE49eBF0778eF8A);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(0x47C2c459c37FEF0c21dC8e945008E8A05346942d);
    collateralAuctionHouse[WBTC] = CollateralAuctionHouse(0x36677aD304c296F9cb24943830E4540C702a63FF);
    collateralAuctionHouse[STONES] = CollateralAuctionHouse(0xF2DFB982FaeDe09c2E1a0Fa5de026FaD25f75dC0);
    collateralAuctionHouse[TOTEM] = CollateralAuctionHouse(0x76aBf3D8Ab0e405f68aE991904A3b8F8E19647Bc);

    // --- proxies ---
    dsProxyFactory = HaiProxyFactory(0xC832Ea7C08c381b1F4726894684F7Bf1538E1dEa);
    proxyRegistry = HaiProxyRegistry(0x558Cd657b65b7DFb6B4c65d55F17247810b9C12a);
    safeManager = HaiSafeManager(0x5325A56148f67b26FaBDc7EbB30686120a98736c);
    proxyActions = BasicActions(0xf046D565170C41E87C29FB40b907fdCf26AC9ac6);

    // --- oracles ---
    delayedOracle[WETH] = IDelayedOracle(0x74558a1470c714BB5E24a6ba998905Ee5F3F0A25);
    delayedOracle[OP] = IDelayedOracle(0x6171f9dB883E3bcC1804Ef17Eb1199133E27058D);
    delayedOracle[WBTC] = IDelayedOracle(0xF6BADAAaC06D7714130aC95Ce8976905284955F9);
    delayedOracle[STONES] = IDelayedOracle(0x4137C0B02EC0A2E9754f28eEbb57c20e9A6ebFae);
    delayedOracle[TOTEM] = IDelayedOracle(0x8Ab563A34bc907f169f19B31018e438934FC3c29);

    haiOracleForTest = OracleForTestnet(0x0256791C87b519e45DEFbf2c94D8DE8ed7C7111a);
    opEthOracleForTest = OracleForTestnet(0x792910b35954c9Ac2F1C4A5DD888f4d46e3472Ba);
  }
}

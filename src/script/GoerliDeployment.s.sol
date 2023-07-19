// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Contracts.s.sol';
import {GoerliParams, WETH, AGOR, WBTC, STONES, TOTEM} from '@script/GoerliParams.s.sol';
import {ARB_GOERLI_WETH, ARB_GOERLI_GOV} from '@script/Registry.s.sol';

abstract contract GoerliDeployment is Contracts, GoerliParams {
  uint256 constant GOERLI_DEPLOYMENT_BLOCK = 11_653_534;

  // --- Mintable ERC20s ---
  ERC20ForTestnet constant ERC20_WBTC = ERC20ForTestnet(0x71544c0d4A343AA6136775cCB093e277E75A700f);
  ERC20ForTestnet constant ERC20_STONES = ERC20ForTestnet(0xe24d097F7f148a4ea54dD98378Ce470d6181B16F);
  ERC20ForTestnet constant ERC20_TOTEM = ERC20ForTestnet(0x8c245E959e89ebDcF73283376f8893EB0b3E78C0);

  /**
   * @notice All the addresses that were deployed in the Goerli deployment, in order of creation
   * @dev    This is used to import the deployed contracts to the test scripts
   */
  constructor() {
    // --- collateral types ---
    collateralTypes.push(WETH);
    collateralTypes.push(AGOR);
    collateralTypes.push(WBTC);
    collateralTypes.push(STONES);
    collateralTypes.push(TOTEM);

    // --- utils ---
    delegatee[AGOR] = governor;

    // --- ERC20s ---
    collateral[WETH] = IERC20Metadata(ARB_GOERLI_WETH);
    collateral[AGOR] = IERC20Metadata(ARB_GOERLI_GOV);
    collateral[WBTC] = IERC20Metadata(ERC20_WBTC);
    collateral[STONES] = IERC20Metadata(ERC20_STONES);
    collateral[TOTEM] = IERC20Metadata(ERC20_TOTEM);

    // change these
    systemCoin = SystemCoin(0x0Ed89D4655b2fE9f99EaDC3116b223527165452D);
    protocolToken = ProtocolToken(0x0Ed89D4655b2fE9f99EaDC3116b223527165452D);

    // --- base contracts ---
    safeEngine = SAFEEngine(0x78EF63cb208954B1E25023c546bd260dF6640B9C);
    oracleRelayer = OracleRelayer(0x621da9683c75b19a76F44A9d19744B8D1deC5aD7);
    liquidationEngine = LiquidationEngine(0xf9c7608CA99BE28d5D7Af58b9745b61f67b7a71D);
    coinJoin = CoinJoin(0x0d3C9e9CcDcC9513c8c999ABd337CefC38955d41);
    surplusAuctionHouse = SurplusAuctionHouse(0x81062ac9B64FE2b7c2a1797303ad7038A16453c8);
    debtAuctionHouse = DebtAuctionHouse(0xC42726c6df8558AdB7209cdef9F0569e567B5065);
    accountingEngine = AccountingEngine(0x04Bf0FbB89e6222Ce49D565AfEAf3cC9FB33702e);
    taxCollector = TaxCollector(0x818DBDf596e5B5d35710DcdBd6027BaaeB01251C);
    stabilityFeeTreasury = StabilityFeeTreasury(0x7aC1ce38c0C1Fe9e2D30e96eEde64f6C14525CB3);
    pidController = PIDController(0xD2A1aE0338253b42f98c6f608dFee5A7526cD739);
    pidRateSetter = PIDRateSetter(0x349594143153D6181A04D00b65786b3E5A89289F);
    globalSettlement = GlobalSettlement(0xDaB49937533833a35216E28DBe7E28A30EbF0f63);

    // --- factories ---
    collateralJoinFactory = CollateralJoinFactory(0x362624a0d558adABF8Da0dd169a3AcDDF64b9064);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(0x2aE625b6865C90e8194b32411a1Da3B683e7FaF6);

    // --- token adapters ---
    collateralJoin[WETH] = CollateralJoin(0x0caF67d5d2eC5847A375c30dC8e00ecebBE42D31);
    collateralJoin[AGOR] = CollateralJoin(0x8d33be9374DCAA9A3E2593c80E3ab40615B11Cac);
    collateralJoin[WBTC] = CollateralJoin(0xF5b19dEDf523f6cF8ABE2bED172d15C1784AD797);
    collateralJoin[STONES] = CollateralJoin(0xD282383A65EfA60517dA7Ca2673dF54e70AD7b6a);
    collateralJoin[TOTEM] = CollateralJoin(0x1867F40224c053e0893581Faf527AC5238cEfcBA);

    // --- collateral auction houses ---
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(0x46f7a52A5543cC5068dc7aF31aE49eBF0778eF8A);
    collateralAuctionHouse[AGOR] = CollateralAuctionHouse(0x47C2c459c37FEF0c21dC8e945008E8A05346942d);
    collateralAuctionHouse[WBTC] = CollateralAuctionHouse(0x36677aD304c296F9cb24943830E4540C702a63FF);
    collateralAuctionHouse[STONES] = CollateralAuctionHouse(0xF2DFB982FaeDe09c2E1a0Fa5de026FaD25f75dC0);
    collateralAuctionHouse[TOTEM] = CollateralAuctionHouse(0x76aBf3D8Ab0e405f68aE991904A3b8F8E19647Bc);

    // --- proxies ---
    dsProxyFactory = HaiProxyFactory(0x3ffcbAd81834BD791Aa64a23b4eA361Ed0576f96);
    proxyRegistry = HaiProxyRegistry(0xa7cd8329A47CdF50bd39C8dD68E851Bc9C3C7754);
    safeManager = HaiSafeManager(0x0D72C175d621EcED29d82Fe987C5DF5643348a86);
    proxyActions = BasicActions(0xa0fA52A075E7a4AbfB7336F9677f287EAB5aDE37);

    // --- oracles ---
    delayedOracle[WETH] = IDelayedOracle(0x74558a1470c714BB5E24a6ba998905Ee5F3F0A25);
    delayedOracle[AGOR] = IDelayedOracle(0x6171f9dB883E3bcC1804Ef17Eb1199133E27058D);
    delayedOracle[WBTC] = IDelayedOracle(0xF6BADAAaC06D7714130aC95Ce8976905284955F9);
    delayedOracle[STONES] = IDelayedOracle(0x4137C0B02EC0A2E9754f28eEbb57c20e9A6ebFae);
    delayedOracle[TOTEM] = IDelayedOracle(0x8Ab563A34bc907f169f19B31018e438934FC3c29);

    haiOracleForTest = OracleForTestnet(0x0F12d95BA60dE2e723F27EDfa0f234A2E4D64005);
    opEthOracleForTest = OracleForTestnet(0x79f48088420028BCeeBC9D465eC52798221024db);
  }
}

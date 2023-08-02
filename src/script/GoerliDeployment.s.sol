// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Contracts.s.sol';
import '@script/GoerliOpContracts.s.sol';
import {GoerliParams, WETH, OP, WBTC, STONES, TOTEM} from '@script/GoerliParams.s.sol';
import {OP_WETH, OP_OPTIMISM} from '@script/Registry.s.sol';

abstract contract GoerliDeployment is Contracts, GoerliParams, GoerliOpContracts {
  uint256 constant GOERLI_DEPLOYMENT_BLOCK = 12_509_149;

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
    collateral[WETH] = IERC20Metadata(OP_WETH);
    collateral[OP] = IERC20Metadata(OP_OPTIMISM);
    collateral[WBTC] = IERC20Metadata(ERC20_WBTC);
    collateral[STONES] = IERC20Metadata(ERC20_STONES);
    collateral[TOTEM] = IERC20Metadata(ERC20_TOTEM);

    systemCoin = SystemCoin(opSystemCoin);
    protocolToken = ProtocolToken(opProtocolToken);

    // --- base contracts ---
    safeEngine = SAFEEngine(opSAFEEngine);
    oracleRelayer = OracleRelayer(opOracleRelayer);
    liquidationEngine = LiquidationEngine(opLiquidationEngine);
    coinJoin = CoinJoin(opCoinJoin);
    surplusAuctionHouse = SurplusAuctionHouse(opSurplusAuctionHouse);
    debtAuctionHouse = DebtAuctionHouse(opDebtAuctionHouse);
    accountingEngine = AccountingEngine(opAccountingEngine);
    taxCollector = TaxCollector(opTaxCollector);
    stabilityFeeTreasury = StabilityFeeTreasury(opStabilityFeeTreasury);
    pidController = PIDController(opPIDController);
    pidRateSetter = PIDRateSetter(opPIDRateSetter);
    globalSettlement = GlobalSettlement(opGlobalSettlement);

    // --- factories ---
    collateralJoinFactory = CollateralJoinFactory(opCollateralJoinFactory);
    collateralAuctionHouseFactory = CollateralAuctionHouseFactory(opCollateralAuctionHouseFactory);

    // --- token adapters ---
    collateralJoin[WETH] = CollateralJoin(opCollateralJoinChild_WETH);
    collateralJoin[OP] = CollateralJoin(opCollateralJoinDelegatableChild_OP);
    // collateralJoin[WBTC] = CollateralJoin(0xF5b19dEDf523f6cF8ABE2bED172d15C1784AD797);
    // collateralJoin[STONES] = CollateralJoin(0xD282383A65EfA60517dA7Ca2673dF54e70AD7b6a);
    // collateralJoin[TOTEM] = CollateralJoin(0x1867F40224c053e0893581Faf527AC5238cEfcBA);

    // --- collateral auction houses ---
    collateralAuctionHouse[WETH] = CollateralAuctionHouse(opCollateralAuctionHouseChild_WETH);
    collateralAuctionHouse[OP] = CollateralAuctionHouse(opCollateralAuctionHouseChild_OP);
    // collateralAuctionHouse[WBTC] = CollateralAuctionHouse(0x724A7b53c0B81DDB0654e012c94667730CBa1837);
    // collateralAuctionHouse[STONES] = CollateralAuctionHouse(0x22a804F6685f96dE8CD81aba0C85fe49884274f8);
    // collateralAuctionHouse[TOTEM] = CollateralAuctionHouse(0x24CF3ddF28d7a2e046Ea9bD1B6908D8B33AAB873);

    // --- jobs ---
    accountingJob = AccountingJob(0x9c6fc600d9673b322C6Bb0835008a0f8229d11b2);
    liquidationJob = LiquidationJob(0xAF729A93526026c63Ada37015d2A0aa3B149913e);
    oracleJob = OracleJob(0xCC81b8E22Bc48133125BDa642C452EC6A52853C8);

    // --- proxies ---
    dsProxyFactory = HaiProxyFactory(opHaiProxyFactory);
    proxyRegistry = HaiProxyRegistry(opHaiProxyRegistry);
    safeManager = HaiSafeManager(opHaiSafeManager);
    proxyActions = BasicActions(opBasicActions);

    // --- oracles ---
    systemCoinOracle = IBaseOracle(0xDffE4278A75aC7E3449edc049025882b61e96238); // DeviatedOracle
    delayedOracle[WETH] = IDelayedOracle(opDelayedOracle_ETH_USD_1);
    delayedOracle[OP] = IDelayedOracle(opDelayedOracle_ETH_USD_2);
    // delayedOracle[WBTC] = IDelayedOracle(0xF6BADAAaC06D7714130aC95Ce8976905284955F9);
    // delayedOracle[STONES] = IDelayedOracle(0x4137C0B02EC0A2E9754f28eEbb57c20e9A6ebFae);
    // delayedOracle[TOTEM] = IDelayedOracle(0x8Ab563A34bc907f169f19B31018e438934FC3c29);
  }
}

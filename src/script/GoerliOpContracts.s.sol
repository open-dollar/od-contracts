// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract GoerliOpContracts {
  // fee management
  address public constant opTaxCollector = 0x979175221543b23ef11577898dA53C87779A54cE;
  address public constant opStabilityFeeTreasury = 0x37ee83E054D2f64efda73B48e360b30f8070858D;
  address public constant opGlobalSettlement = 0x1de67dA2aa6C3C0BEa350546f9BA4a8281b4CEAe;

  // proxy
  address public constant opHaiProxyFactory = 0x74044fDd9C267050f5b11987e1009b76b5ef806b;
  address public constant opHaiProxyRegistry = 0x8505e8D84654467d032DB394637D0FaFf477568a;
  address public constant opHaiSafeManager = 0xE5559B4C5605a2cd4F6F3DD84D9eeF2Df7aC3EB1;

  // proxy actions
  address public constant opBasicActions = 0x48fC4859e06c1096b3A02d391F96376AdA9259a8;
  address public constant opDebtBidActions = 0x5fc994EBfAe4ABeFca0f2DeeFDC2C8A46AD2bEb0;
  address public constant opSurplusBidActions = 0xB0C1470255f08a06A5123e03554Fb7CeBF41Ed6a;
  address public constant opCollateralBidActions = 0xE4f9DbD083419944e401Bd709eA74fb52a8dcdCa;

  // collateral factories
  address public constant opCollateralJoinFactory = 0x53Ce42D1f68B08c7D90ACC5Cfc69aF34006E5714;
  address public constant opCollateralAuctionHouseFactory = 0x8280359b7E693b0BE1B9a8F4e3E121b090a764d2;

  // collateral options
  address public constant opCollateralJoinChild_WETH = 0xa460cE97C6CD53dccBA7d1adc0dCaa51206eae8b;
  address public constant opCollateralAuctionHouseChild_WETH = 0x2d53E42F16877cD17fC4D43E131c9903e24C4312;
  address public constant opCollateralJoinDelegatableChild_OP = 0x6C43E13E3A9f7CC7797C25D3dDe1e19D8eaBC36C;
  address public constant opCollateralAuctionHouseChild_OP = 0xb3bC3A32b9D330609465b53D09E215273a8C3C15;

  // control
  address public constant opPIDController = 0x1160eD5424EA2EF0cE0cf7C88Ebba1fD03dd45f4;
  address public constant opPIDRateSetter = 0x40EB340fC899b0FCE71ACAEADA10ADf8037a05E1;

  // oracles
  address public constant opDenominatedOracle = 0x71544c0d4A343AA6136775cCB093e277E75A700f;
  address public constant opOracleForTestnet_1 = 0x93de8CBD2C4D4A3101EE602f43232A1f5acb8CaC;
  address public constant opOracleForTestnet_2 = 0x7Ebdc9852dCe44879dA09d3B57161843688de3fe;
  address public constant opDelayedOracle_ETH_USD_1 = 0xe24d097F7f148a4ea54dD98378Ce470d6181B16F;
  address public constant opDelayedOracle_ETH_USD_2 = 0x8c245E959e89ebDcF73283376f8893EB0b3E78C0;

  // relayers
  address public constant opChainlinkRelayer = 0x8884f9CEB0cFf1475E1481ACe8D209283BDFBED3;
  address public constant opOracleRelayer = 0x1ad1c8C9F6eaaC6a735345CE812829Ee8FA97D9e;

  // tokens
  address public constant opCoinJoin = 0x1ceABCDB63dFF8734bB9D969C398936C0d6B4ad5; // joins SystemToken
  address public constant opSystemCoin = 0xD0fbafe59e8af03C81b48ADbd3c3679E5D7Fa613;
  address public constant opProtocolToken = 0xe305D09d46bD6c9C0178799Bc1424282b798876C;

  // auction houses
  address public constant opSurplusAuctionHouse = 0xe96EeAb3b69d026FF319a310459AD7ADDD8d22a9;
  address public constant opDebtAuctionHouse = 0xbEcB8EB637B486dCfbd8c6bb4C4ED2e9b673766a;

  // engines
  address public constant opAccountingEngine = 0xA639a991A6efce6Cf07075E2a85eD7Ac680A9a8A;
  address public constant opLiquidationEngine = 0xcCF4aef289CfbA9E5D1f55D6B2Cd6719E56c16D9;

  // core engine
  address public constant opSAFEEngine = 0xBDd34044Ab215Fd5547251D29e6972F7dCfb7D60;
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

abstract contract AnvilContracts {
  address public ChainlinkRelayerFactory_Address = 0xcE0066b1008237625dDDBE4a751827de037E53D2;
  address public DenominatedOracleFactory_Address = 0x82EdA215Fa92B45a3a76837C65Ab862b6C7564a8;
  address public DelayedOracleFactory_Address = 0x87006e75a5B6bE9D1bbF61AC8Cd84f05D9140589;
  address public MintableVoteERC20_Address = 0x8fC8CFB7f7362E44E472c690A6e025B80E406458;
  address public MintableERC20_WSTETH_Address = 0xC7143d5bA86553C06f5730c8dC9f8187a621A8D4;
  address public MintableERC20_CBETH_Address = 0x359570B3a0437805D0a71457D61AD26a28cAC9A2;
  address public MintableERC20_RETH_Address = 0xc9952Fc93Fa9bE383ccB39008c786b9f94eAc95d;
  address public DenominatedOracleChild_10_Address = 0xcafCfdF4517F504a473469F3723e674413EE9bce;
  address public DenominatedOracleChild_12_Address = 0xd1f8C3b3C9C63a7a7f0dCFd20ae9053A04182db1;
  address public DenominatedOracleChild_14_Address = 0x738AA5a01c7Df7E2Bc12722252989B5d019Fe24B;
  address public DelayedOracleChild_15_Address = 0x6212Adf47F935b95da3a72Ee68790b5975FE9C6B;
  address public DelayedOracleChild_16_Address = 0x1AD1f973e19eA7502cda4EE946FD5F5DF9DDA770;
  address public DelayedOracleChild_17_Address = 0x9124d3cd3741fA59CaB0f8eBfa9175a2286C0546;
  address public DelayedOracleChild_18_Address = 0xc82481Adac09Fa80f73323fEf5F83fab2D589BBd;
  address public SystemCoin_Address = 0x942ED2fa862887Dc698682cc6a86355324F0f01e;
  address public ProtocolToken_Address = 0x8D81A3DCd17030cD5F23Ac7370e4Efb10D2b3cA4;
  address public TimelockController_Address = 0xc7cDb7A2E5dDa1B7A0E792Fe1ef08ED20A6F56D4;
  address public ODGovernor_Address = 0x967AB65ef14c58bD4DcfFeaAA1ADb40a022140E5;
  address public SAFEEngine_Address = 0x871ACbEabBaf8Bed65c22ba7132beCFaBf8c27B5;
  address public OracleRelayer_Address = 0x6A59CC73e334b018C9922793d96Df84B538E6fD5;
  address public SurplusAuctionHouse_Address = 0xC1e0A9DB9eA830c52603798481045688c8AE99C2;
  address public DebtAuctionHouse_Address = 0x683d9CDD3239E0e01E8dC6315fA50AD92aB71D2d;
  address public AccountingEngine_Address = 0x1c9fD50dF7a4f066884b58A05D91e4b55005876A;
  address public LiquidationEngine_Address = 0x0fe4223AD99dF788A6Dcad148eB4086E6389cEB6;
  address public CollateralAuctionHouseFactory_Address = 0x71a0b8A2245A9770A4D887cE1E4eCc6C1d4FF28c;
  address public CoinJoin_Address = 0xb185E9f6531BA9877741022C92CE858cDCc5760E;
  address public CollateralJoinFactory_Address = 0xAe120F0df055428E45b264E7794A18c54a2a3fAF;
  address public TaxCollector_Address = 0x193521C8934bCF3473453AF4321911E7A89E0E12;
  address public StabilityFeeTreasury_Address = 0x9Fcca440F19c62CDF7f973eB6DDF218B15d4C71D;
  address public GlobalSettlement_Address = 0x95775fD3Afb1F4072794CA4ddA27F2444BCf8Ac3;
  address public PostSettlementSurplusAuctionHouse_Address = 0xd9fEc8238711935D6c8d79Bef2B9546ef23FC046;
  address public SettlementSurplusAuctioneer_Address = 0xd3FFD73C53F139cEBB80b6A524bE280955b3f4db;
  address public PIDController_Address = 0x572316aC11CB4bc5daf6BDae68f43EA3CCE3aE0e;
  address public PIDRateSetter_Address = 0x975Ab64F4901Af5f0C96636deA0b9de3419D0c2F;
  address public AccountingJob_Address = 0x94fFA1C7330845646CE9128450F8e6c3B5e44F86;
  address public LiquidationJob_Address = 0xCa1D199b6F53Af7387ac543Af8e8a34455BBe5E0;
  address public OracleJob_Address = 0xdF46e54aAadC1d55198A4a8b4674D7a4c927097A;
  address public CollateralJoinChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
    0xd04Fe2BB71024dAae0FB7Eb72983ffE2287EE6c6;
  address public
    CollateralAuctionHouseChild_0x4152420000000000000000000000000000000000000000000000000000000000_Address =
      0x2E571dc3F27343Bcd3c7d69aA213543EE3551812;
  address public CollateralJoinChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
    0x9290A08d4394bFaF90aaD66f78304bE202A74f98;
  address public
    CollateralAuctionHouseChild_0x5753544554480000000000000000000000000000000000000000000000000000_Address =
      0x2fd807D24be2c4F06Edf4351AF78c4b6984A15c1;
  address public CollateralJoinChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
    0xF6fdd472cee62b9238F3f05A4BE54F23f62c9C2C;
  address public
    CollateralAuctionHouseChild_0x4342455448000000000000000000000000000000000000000000000000000000_Address =
      0x3F0C1A7D8F3E1e783995c53fbFC3e4d9245C247E;
  address public CollateralJoinChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
    0xcC124a79CDcD40EA737Ff020918d3965eed1c49d;
  address public
    CollateralAuctionHouseChild_0x5245544800000000000000000000000000000000000000000000000000000000_Address =
      0x609d36Ac69735d134D7259e258e5BD5cF225742a;
  address public Vault721_Address = 0xd30bF3219A0416602bE8D482E0396eF332b0494E;
  address public ODSafeManager_Address = 0xAD2935E147b61175D5dc3A9e7bDa93B0975A43BA;
  address public NFTRenderer_Address = 0x00CAC06Dd0BB4103f8b62D280fE9BCEE8f26fD59;
  address public BasicActions_Address = 0x4951A1C579039EbfCBA0BE33D2cd3A6D30b0f802;
  address public DebtBidActions_Address = 0x2e8880cAdC08E9B438c6052F5ce3869FBd6cE513;
  address public SurplusBidActions_Address = 0xb007167714e2940013EC3bb551584130B7497E22;
  address public CollateralBidActions_Address = 0x6b39b761b1b64C8C095BF0e3Bb0c6a74705b4788;
  address public PostSettlementSurplusBidActions_Address = 0xeC827421505972a2AE9C320302d3573B42363C26;
  address public GlobalSettlementActions_Address = 0x74Df809b1dfC099E8cdBc98f6a8D1F5c2C3f66f8;
  address public RewardedActions_Address = 0x3f9A1B67F3a3548e0ea5c9eaf43A402d12b6a273;
}

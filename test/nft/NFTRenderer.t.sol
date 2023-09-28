// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Strings} from '@openzeppelin/utils/Strings.sol';
import {GoerliForkSetup} from '@test/nft/GoerliForkSetup.t.sol';
import {GOERLI_WETH, GOERLI_GOV_TOKEN} from '@script/Registry.s.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';
import {SAFEEngine, ISAFEEngine} from '@contracts/SAFEEngine.sol';
import {OracleRelayer, IOracleRelayer} from '@contracts/OracleRelayer.sol';
import {CollateralJoinFactory, ICollateralJoinFactory} from '@contracts/factories/CollateralJoinFactory.sol';
import {TaxCollector, ITaxCollector} from '@contracts/TaxCollector.sol';

// forge t --fork-url $URL --match-contract NFTRendererTest -vvvvv

contract NFTRendererTest is GoerliForkSetup {
  using Strings for uint256;

  /// @dev Uint256 representation of 1 RAY
  uint256 constant RAY = 10 ** 27;
  /// @dev Uint256 representation of 1 WAD
  uint256 constant WAD = 10 ** 18;

  NFTRenderer public r;

  function setUp() public override {
    super.setUp();

    r = new NFTRenderer(Vault721_Address, OracleRelayer_Address, TaxCollector_Address, CollateralJoinFactory_Address);
  }

  function testArbitrary() public {
    NFTRenderer.VaultParams memory p = r.renderParams(1);

    // IODSafeManager.SAFEData memory safeMangerData = IODSafeManager(ODSafeManager_Address).safeData(1);
    // address safeHandler = safeMangerData.safeHandler;
    // bytes32 cType = safeMangerData.collateralType;

    // ITaxCollector.TaxCollectorCollateralParams memory cParams = ITaxCollector(TaxCollector_Address).cParams(cType);
    // uint256 stabilityFee1 = cParams.stabilityFee;
    // emit log_uint(stabilityFee1 / RAY);

    // ITaxCollector.TaxCollectorCollateralData memory cData = ITaxCollector(TaxCollector_Address).cData(cType);
    // uint256 stabilityFee2 = cData.nextStabilityFee;
    // emit log_uint(stabilityFee2 / RAY);
  }
}

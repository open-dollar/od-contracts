// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Strings} from '@openzeppelin/utils/Strings.sol';
import {GoerliForkSetup} from '@test/nft/GoerliForkSetup.t.sol';
import {ARB_GOERLI_WETH, ARB_GOERLI_GOV_TOKEN} from '@script/Registry.s.sol';
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

  NFTRenderer public r;

  function setUp() public override {
    super.setUp();

    r = new NFTRenderer(Vault721_Address, OracleRelayer_Address, TaxCollector_Address, CollateralJoinFactory_Address);
  }

  function testParams1() public {
    NFTRenderer.VaultParams memory p = r.renderParams(1);
    // uint256 c = p.collateral;
    // uint256 d = p.debt;
    uint256 c = 1_111_222_233_334_444_555_566;

    uint256 lc = c / 1e18;
    uint256 explc = lc * 1e18;
    uint256 rc = c - explc;
    uint256 redrc = rc / 1e10;

    emit log_uint(c);
    emit log_uint(lc);
    emit log_uint(explc);
    emit log_uint(rc);
    emit log_uint(redrc);
  }
}

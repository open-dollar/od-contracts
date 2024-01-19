// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest, stdStorage, StdStorage} from '@testnet/utils/HaiTest.t.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {ITaxCollector} from '@interfaces/ITaxCollector.sol';
import {ICollateralJoinFactory} from '@interfaces/factories/ICollateralJoinFactory.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';

contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address owner = label('owner');
  address user = address(0xdeadce11);
  // address userProxy;

  NFTRenderer public nftRenderer;
  // protocol contracts
  IVault721 public vault721;
  IODSafeManager public safeManager;
  ISAFEEngine public safeEngine;
  IOracleRelayer public oracleRelayer;
  ITaxCollector public taxCollector;
  ICollateralJoinFactory public collateralJoinFactory;
  //address _vault721, address oracleRelayer, address taxCollector, address collateralJoinFactory

  function setUp() public virtual {
    vm.startPrank(deployer);

    safeManager = IODSafeManager(mockContract('IODSafeManager'));
    safeEngine = ISAFEEngine(mockContract('SAFEEngine'));
    oracleRelayer = IOracleRelayer(mockContract('oracleRelayer'));
    taxCollector = ITaxCollector(mockContract('taxCollector'));
    collateralJoinFactory = ICollateralJoinFactory(mockContract('collateralJoinFactory'));
    vault721 = IVault721(address(new Vault721()));

    vm.mockCall(
      address(vault721), abi.encodeWithSelector(IVault721.safeManager.selector), abi.encode(address(safeManager))
    );

    vm.mockCall(
      address(safeManager), abi.encodeWithSelector(IODSafeManager.safeEngine.selector), abi.encode(address(safeEngine))
    );

    nftRenderer =
      new NFTRenderer(address(vault721), address(oracleRelayer), address(taxCollector), address(collateralJoinFactory));
    vm.stopPrank();
  }
}

contract Unit_NFTRenderer_Deployment is Base {
  function test_Deployment_Params() public {
    assertEq(address(vault721), address(nftRenderer.vault721()), 'incorrect vault721 set');
  }
}

contract Unit_NFTRenderer_RenderParams is Base {
  function test_RenderParams() public {}
}

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
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ITaxCollector} from '@interfaces/ITaxCollector.sol';
import {ICollateralJoinFactory} from '@interfaces/factories/ICollateralJoinFactory.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {CollateralJoin} from '@contracts/utils/CollateralJoin.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';

import {Math} from '@libraries/Math.sol';
import {DateTime} from '@libraries/DateTime.sol';
import {Strings} from '@openzeppelin/utils/Strings.sol';
import {Base64} from '@openzeppelin/utils/Base64.sol';

contract Base is HaiTest {
  using stdStorage for StdStorage;
    using Strings for uint256;
  using Math for uint256;
  using DateTime for uint256;

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

contract Unit_NFTRenderer_GetVaultCTypeAndCollateralAndDebt is Base {

  function test_GetVaultCTypeAndCollateralAndDebt(IODSafeManager.SAFEData memory _safeData, ISAFEEngine.SAFE memory _safeEngineData) public {
    vm.mockCall(
      address(safeManager),
      abi.encodeWithSelector(IODSafeManager.safeData.selector),
      abi.encode(_safeData)
    );
    vm.mockCall(
      address(safeEngine),
      abi.encodeWithSelector(ISAFEEngine.safes.selector),
      abi.encode(_safeEngineData)
    );  
    (bytes32 cType, uint256 collateral, uint256 debt) =nftRenderer.getVaultCTypeAndCollateralAndDebt(1);

    assertEq(cType, _safeData.collateralType, 'incorrect cType');
    assertEq(collateral, _safeEngineData.lockedCollateral, 'incorrect safe engine collateral');
    assertEq( debt, _safeEngineData.generatedDebt, 'incorrect generated debt');
  }
}

contract Unit_NFTRenderer_GetStateHash is Base {

  function test_GetStateHashBySafeId(IODSafeManager.SAFEData memory _safeData, ISAFEEngine.SAFE memory _safeEngineData)public {
       vm.mockCall(
      address(safeManager),
      abi.encodeWithSelector(IODSafeManager.safeData.selector),
      abi.encode(_safeData)
    );
    vm.mockCall(
      address(safeEngine),
      abi.encodeWithSelector(ISAFEEngine.safes.selector),
      abi.encode(_safeEngineData)
    ); 
    bytes32 stateHash = nftRenderer.getStateHashBySafeId(1);

    assertEq(stateHash, keccak256(abi.encode( _safeEngineData.lockedCollateral,_safeEngineData.generatedDebt)), 'incorrect state hash');
  }

    function test_GetStateHash(ISAFEEngine.SAFE memory _safeEngineData)public {

    bytes32 stateHash = nftRenderer.getStateHash( _safeEngineData.lockedCollateral, _safeEngineData.generatedDebt);

    assertEq(stateHash, keccak256(abi.encode( _safeEngineData.lockedCollateral,_safeEngineData.generatedDebt)), 'incorrect state hash');
  }
}

contract Unit_NFTRenderer_RenderParams is Base {
IDelayedOracle oracle;

struct RenderParamsData {
  ITaxCollector.TaxCollectorCollateralData  taxData;
  IODSafeManager.SAFEData safeData;
  ISAFEEngine.SAFEEngineCollateralData  safeEngineCollateralData;
  ISAFEEngine.SAFE safeEngineData;
  IOracleRelayer.OracleRelayerCollateralParams  oracleParams;
  address collateralJoin;
  address collateral;
  string symbol;
  uint256 lastUpdateTime;
  uint256 readValue;
}

function setUp() public override {
  Base.setUp();
  oracle = IDelayedOracle(mockContract('oracle'));
}

modifier noOverFlow(RenderParamsData memory _data){
  vm.assume(notUnderOrOverflowMul(_data.readValue, int256(_data.safeEngineData.lockedCollateral)));
  _;
}
function test_RenderParams(RenderParamsData memory _data)public {
    vm.mockCall(
      address(safeManager),
      abi.encodeWithSelector(IODSafeManager.safeData.selector),
      abi.encode(_data.safeData)
    );
    vm.mockCall(
      address(safeEngine),
      abi.encodeWithSelector(ISAFEEngine.safes.selector),
      abi.encode(_data.safeEngineData)
    ); 

     vm.mockCall(
    address(oracleRelayer),
    abi.encodeWithSelector(oracleRelayer.cParams.selector),
    abi.encode(_data.oracleParams)
  );

  vm.mockCall(
    address(collateralJoinFactory),
    abi.encodeWithSelector(collateralJoinFactory.collateralJoins.selector),
    abi.encode(address(_data.collateralJoin))
  );

  vm.mockCall(
    address(_data.collateralJoin),
    abi.encodeWithSelector(ICollateralJoin.collateral.selector),
    abi.encode(address(_data.collateral))
  );

  vm.mockCall(
    address(taxCollector),
    abi.encodeWithSelector(ITaxCollector.cData.selector),
    abi.encode(_data.taxData)
  );

  vm.mockCall(
    address(_data.collateral),
    abi.encodeWithSelector(IERC20Metadata.symbol.selector),
    abi.encode(_data.symbol)
  );

  vm.mockCall(
    address(oracle),
    abi.encodeWithSelector(IDelayedOracle.lastUpdateTime.selector),
    abi.encode(_data.lastUpdateTime)
  );

    vm.mockCall(
    address(oracle),
    abi.encodeWithSelector(IBaseOracle.read.selector),
    abi.encode(_data.readValue)
  );

  NFTRenderer.VaultParams memory params = nftRenderer.renderParams(1);
}
}



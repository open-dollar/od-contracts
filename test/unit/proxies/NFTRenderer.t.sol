// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ODTest, stdStorage, StdStorage} from '@test/utils/ODTest.t.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {OracleForTest} from '@contracts/for-test/OracleForTest.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ITaxCollector} from '@interfaces/ITaxCollector.sol';
import {ICollateralJoinFactory} from '@interfaces/factories/ICollateralJoinFactory.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {CollateralJoin} from '@contracts/utils/CollateralJoin.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';

import {Math, WAD, RAY} from '@libraries/Math.sol';
import {DateTime} from '@libraries/DateTime.sol';
import {Strings} from '@openzeppelin/utils/Strings.sol';
import {Base64} from '@openzeppelin/utils/Base64.sol';

struct RenderParamsData {
  uint256 safeId;
  ITaxCollector.TaxCollectorCollateralData taxData;
  IODSafeManager.SAFEData safeData;
  ISAFEEngine.SAFEEngineCollateralData safeEngineCollateralData;
  ISAFEEngine.SAFE safeEngineData;
  IOracleRelayer.OracleRelayerCollateralParams oracleParams;
  uint256 readValue;
  uint256 timestamp;
}

contract Base is ODTest {
  using stdStorage for StdStorage;
  using Strings for uint256;
  using Math for uint256;
  using DateTime for uint256;

  address deployer = label('deployer');
  address owner = label('owner');
  address user = address(0xdeadce11);
  address _collateralJoin = address(0xdeadbeef);
  address _collateral = address(0xdeadc0ffee);
  string emptyString;

  NFTRenderer public nftRenderer;
  // protocol contracts
  IVault721 public vault721;
  IODSafeManager public safeManager;
  ISAFEEngine public safeEngine;
  IOracleRelayer public oracleRelayer;
  ITaxCollector public taxCollector;
  ICollateralJoinFactory public collateralJoinFactory;
  //address _vault721, address oracleRelayer, address taxCollector, address collateralJoinFactory

  modifier noOverFlow(RenderParamsData memory _data) {
    _data.oracleParams.oracle = IDelayedOracle(address(oracleRelayer));
    _data.safeEngineData.lockedCollateral = bound(_data.safeEngineData.lockedCollateral, 0, WAD * 1000);
    _data.safeEngineData.generatedDebt = bound(_data.safeEngineData.generatedDebt, 0, WAD * 1000);
    vm.assume(_data.safeEngineCollateralData.accumulatedRate > 0);
    _data.safeEngineCollateralData.accumulatedRate =
      bound(_data.safeEngineCollateralData.accumulatedRate, 1, WAD * 1000);
    vm.assume(
      notUnderOrOverflowMul(_data.safeEngineData.lockedCollateral, Math.toInt(_data.oracleParams.oracle.read()))
    );
    vm.assume(
      notUnderOrOverflowMul(
        _data.safeEngineData.generatedDebt, Math.toInt(_data.safeEngineCollateralData.accumulatedRate)
      )
    );
    vm.assume(
      _data.safeEngineData.lockedCollateral.wmul(_data.oracleParams.oracle.read())
        > _data.safeEngineData.generatedDebt.wmul(_data.safeEngineCollateralData.accumulatedRate)
    );
    _data.safeEngineData.lockedCollateral = _data.safeEngineData.lockedCollateral * WAD;
    _data.safeEngineData.generatedDebt = _data.safeEngineData.generatedDebt * WAD;
    _data.safeEngineCollateralData.accumulatedRate = _data.safeEngineCollateralData.accumulatedRate * WAD;

    _data.timestamp = bound(_data.timestamp, 100, 9_000_000_000);
    _;
  }

  function setUp() public virtual {
    vm.startPrank(deployer);

    safeManager = IODSafeManager(mockContract('IODSafeManager'));
    safeEngine = ISAFEEngine(mockContract('SAFEEngine'));
    oracleRelayer = IOracleRelayer(address(new OracleForTest(3 * WAD)));
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

  function _mockRenderCalls(RenderParamsData memory _data) internal {
    vm.mockCall(
      address(safeManager), abi.encodeWithSelector(IODSafeManager.safeData.selector), abi.encode(_data.safeData)
    );
    vm.mockCall(
      address(safeEngine), abi.encodeWithSelector(ISAFEEngine.safes.selector), abi.encode(_data.safeEngineData)
    );
    vm.mockCall(
      address(oracleRelayer), abi.encodeWithSelector(oracleRelayer.cParams.selector), abi.encode(_data.oracleParams)
    );
    vm.mockCall(
      address(safeEngine),
      abi.encodeWithSelector(ISAFEEngine.cData.selector),
      abi.encode(_data.safeEngineCollateralData)
    );
    vm.mockCall(
      address(collateralJoinFactory),
      abi.encodeWithSelector(collateralJoinFactory.collateralJoins.selector),
      abi.encode(address(_collateralJoin))
    );
    vm.mockCall(
      address(_collateralJoin),
      abi.encodeWithSelector(ICollateralJoin.collateral.selector),
      abi.encode(address(_collateral))
    );

    vm.mockCall(address(_collateral), abi.encodeWithSelector(IERC20Metadata.symbol.selector), abi.encode('TST'));
    vm.mockCall(
      address(_data.oracleParams.oracle),
      abi.encodeWithSelector(IDelayedOracle.lastUpdateTime.selector),
      abi.encode(_data.timestamp)
    );
    vm.mockCall(address(taxCollector), abi.encodeWithSelector(ITaxCollector.cData.selector), abi.encode(_data.taxData));
  }
}

contract Unit_NFTRenderer_Deployment is Base {
  function test_Deployment_Params() public {
    assertEq(address(vault721), address(nftRenderer.vault721()), 'incorrect vault721 set');
  }
}

contract Unit_NFTRenderer_GetVaultCTypeAndCollateralAndDebt is Base {
  function test_GetVaultCTypeAndCollateralAndDebt(
    IODSafeManager.SAFEData memory _safeData,
    ISAFEEngine.SAFE memory _safeEngineData
  ) public {
    vm.mockCall(address(safeManager), abi.encodeWithSelector(IODSafeManager.safeData.selector), abi.encode(_safeData));
    vm.mockCall(address(safeEngine), abi.encodeWithSelector(ISAFEEngine.safes.selector), abi.encode(_safeEngineData));
    (bytes32 cType, uint256 collateral, uint256 debt) = nftRenderer.getVaultCTypeAndCollateralAndDebt(1);

    assertEq(cType, _safeData.collateralType, 'incorrect cType');
    assertEq(collateral, _safeEngineData.lockedCollateral, 'incorrect safe engine collateral');
    assertEq(debt, _safeEngineData.generatedDebt, 'incorrect generated debt');
  }
}

contract Unit_NFTRenderer_GetStateHash is Base {
  function test_GetStateHashBySafeId(
    IODSafeManager.SAFEData memory _safeData,
    ISAFEEngine.SAFE memory _safeEngineData
  ) public {
    vm.mockCall(address(safeManager), abi.encodeWithSelector(IODSafeManager.safeData.selector), abi.encode(_safeData));
    vm.mockCall(address(safeEngine), abi.encodeWithSelector(ISAFEEngine.safes.selector), abi.encode(_safeEngineData));
    bytes32 stateHash = nftRenderer.getStateHashBySafeId(1);

    assertEq(
      stateHash,
      keccak256(abi.encode(_safeEngineData.lockedCollateral, _safeEngineData.generatedDebt)),
      'incorrect state hash'
    );
  }

  function test_GetStateHash(ISAFEEngine.SAFE memory _safeEngineData) public {
    bytes32 stateHash = nftRenderer.getStateHash(_safeEngineData.lockedCollateral, _safeEngineData.generatedDebt);

    assertEq(
      stateHash,
      keccak256(abi.encode(_safeEngineData.lockedCollateral, _safeEngineData.generatedDebt)),
      'incorrect state hash'
    );
  }
}

contract Unit_NFTRenderer_RenderParams is Base {
  using Math for uint256;
  using Strings for uint256;

  function test_RenderParams(RenderParamsData memory _data) public noOverFlow(_data) {
    _mockRenderCalls(_data);

    NFTRenderer.VaultParams memory params = nftRenderer.renderParams(_data.safeId);

    if (_data.safeEngineData.generatedDebt != 0 && _data.safeEngineData.lockedCollateral != 0) {
      assertEq(
        params.ratio,
        (
          (_data.safeEngineData.lockedCollateral.wmul(_data.oracleParams.oracle.read())).wdiv(
            _data.safeEngineData.generatedDebt.wmul(_data.safeEngineCollateralData.accumulatedRate)
          )
        ) / 1e7,
        'incorrect ratio'
      );
    } else if (_data.safeEngineData.generatedDebt == 0 && _data.safeEngineData.lockedCollateral != 0) {
      assertEq(params.ratio, 100, 'incorrect ratio');
    } else {
      assertEq(params.ratio, 0, 'incorrect ratio param');
    }

    if (bytes(params.collateral).length == 0) {
      fail('No collateral returned');
    }
    if (bytes(params.debt).length == 0) {
      fail('No debt returned');
    }
    if (bytes(params.metaDebt).length == 0) {
      fail('No metaDebt returned');
    }
  }

  function test_RenderParams_zeros(RenderParamsData memory _data) public noOverFlow(_data) {
    _data.safeEngineData.generatedDebt = 0;
    _data.safeEngineData.lockedCollateral = 0;
    _mockRenderCalls(_data);

    NFTRenderer.VaultParams memory params = nftRenderer.renderParams(_data.safeId);

    assertEq(params.ratio, 0, 'incorrect ratio param');

    if (bytes(params.collateral).length == 0) {
      fail('No collateral string returned');
    }
  }
}

contract Unit_NFTRenderer_Render is Base {
  function test_Render(RenderParamsData memory _data) public noOverFlow(_data) {
    _mockRenderCalls(_data);

    string memory returnedURI = nftRenderer.render(_data.safeId);

    if (bytes(returnedURI).length == 0) {
      fail('no URI returned');
    }
  }
}

contract Unit_NFTRenderer_SetImplementation is Base {
  struct Implementations {
    address safeManager;
    address oracleRelayer;
    address taxCollector;
    address collateralJoinFactory;
    address safeEngine;
  }

  event ImplementationSet(
    address safeManager, address safeEngine, address oracleRelayer, address taxCollector, address collateralJoinFactory
  );

  function test_SetImplementation(Implementations memory _imps) public {
    vm.mockCall(
      address(_imps.safeManager),
      abi.encodeWithSelector(IODSafeManager.safeEngine.selector),
      abi.encode(_imps.safeEngine)
    );

    vm.prank(address(vault721));
    vm.expectEmit();
    emit ImplementationSet(
      _imps.safeManager, _imps.safeEngine, _imps.oracleRelayer, _imps.taxCollector, _imps.collateralJoinFactory
    );
    nftRenderer.setImplementation(
      _imps.safeManager, _imps.oracleRelayer, _imps.taxCollector, _imps.collateralJoinFactory
    );
  }

  function test_SetImplementation_Revert(Implementations memory _imps) public {
    vm.expectRevert('NFT: only vault721');
    nftRenderer.setImplementation(
      _imps.safeManager, _imps.oracleRelayer, _imps.taxCollector, _imps.collateralJoinFactory
    );
  }
}

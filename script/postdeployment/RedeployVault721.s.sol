// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {Test} from 'forge-std/Test.sol';
import {IODCreate2Factory} from '@interfaces/factories/IODCreate2Factory.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {SAFEEngine} from '@contracts/SAFEEngine.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';
import {MainnetContracts} from '@script/MainnetContracts.s.sol';
import {MainnetDeployment} from '@script/MainnetDeployment.s.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {WSTETH, RETH, ARB} from '@script/MainnetParams.s.sol';

abstract contract Base is MainnetDeployment, Script, Test {
  IODCreate2Factory internal _create2 = IODCreate2Factory(MAINNET_CREATE2FACTORY);
  address internal constant _DEPLOYER = 0xF78dA2A37049627636546E0cFAaB2aD664950917;

  uint256 internal _deployerPk;
  address internal _deployer;

  bytes internal _vault721InitCode;
  bytes32 internal _vault721Hash;
  address internal _precomputeAddress;
  address internal _vault721;
  address internal _safeManager;
  address internal _nftRenderer;
  address internal _usdEthRelayer;

  function setUp() public {
    _deployerPk = vm.envUint('ARB_MAINNET_DEPLOYER_PK');
    _deployer = vm.addr(_deployerPk);

    _vault721InitCode = type(Vault721).creationCode;
    _vault721Hash = keccak256(_vault721InitCode);
  }
}

// SIMULATE
// source .env && forge script VerifyVault721VanityAddr --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract VerifyVault721VanityAddr is Base {
  function run() public {
    vm.startBroadcast(_deployerPk);
    _precomputeAddress = _create2.precomputeAddress(MAINNET_SALT_VAULT721, _vault721Hash);
    emit log_named_address('Vault721 Precompute Vanity Address', _precomputeAddress);
    vm.stopBroadcast();
  }
}

// BROADCAST
// source .env && forge script RedeployVault721 --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script RedeployVault721 --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract RedeployVault721 is Base {
  function run() public {
    bool _broadcast;
    if (_deployer == _DEPLOYER) _broadcast = true;

    if (_broadcast) vm.startBroadcast(_deployerPk);
    else vm.startPrank(_DEPLOYER);

    // _vault721 = _create2.create2deploy(MAINNET_SALT_VAULT721, _vault721InitCode);
    _vault721 = 0x0005AFE00fF7E7FF83667bFe4F2996720BAf0B36;
    // Vault721(_vault721).initialize(MAINNET_TIMELOCK_CONTROLLER, BLOCK_DELAY, TIME_DELAY);

    // _safeManager =
    //   address(new ODSafeManager(SAFEEngine_Address, _vault721, TaxCollector_Address, LiquidationEngine_Address));
    _safeManager = 0x8646CBd915eAAD1a4E2Ba5e2b67Acec4957d5f1a;
    _nftRenderer =
      address(new NFTRenderer(_vault721, OracleRelayer_Address, TaxCollector_Address, CollateralJoinFactory_Address));

    emit log_named_address('Vault721 Address', _vault721);
    emit log_named_address('ODSafeManager Address', _safeManager);
    emit log_named_address('NFTRenderer Address', _nftRenderer);

    SAFEEngine(SAFEEngine_Address).modifyParameters('odSafeManager', bytes(abi.encodePacked(_safeManager)));

    IAuthorizable(_safeManager).addAuthorization(MAINNET_TIMELOCK_CONTROLLER);

    if (_broadcast) vm.stopBroadcast();
    else vm.stopPrank();
  }
}

// BROADCAST
// source .env && forge script UpdateSafeManager --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script UpdateSafeManager --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC
contract UpdateSafeManager is Base {
  function run() public {
    bool _broadcast;
    if (_deployer == _DEPLOYER) _broadcast = true;

    if (_broadcast) vm.startBroadcast(_deployerPk);
    else vm.startPrank(_DEPLOYER);

    _safeManager = 0x8646CBd915eAAD1a4E2Ba5e2b67Acec4957d5f1a;

    SAFEEngine(SAFEEngine_Address).modifyParameters('odSafeManager', bytes(abi.encode(_safeManager)));

    assert(SAFEEngine(SAFEEngine_Address).odSafeManager() == _safeManager);

    if (_broadcast) vm.stopBroadcast();
    else vm.stopPrank();
  }
}

// BROADCAST
// source .env && forge script UpdateOracles --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script UpdateOracles --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC
contract UpdateOracles is Base {
  function run() public {
    bool _broadcast;
    if (_deployer == _DEPLOYER) _broadcast = true;

    if (_broadcast) vm.startBroadcast(_deployerPk);
    else vm.startPrank(_DEPLOYER);

    IBaseOracle _wstethETHPriceFeedNew =
      chainlinkRelayerFactory.deployChainlinkRelayer(CHAINLINK_WSTETH_ETH_FEED, 86_400);
    IBaseOracle _rethETHPriceFeedNew = chainlinkRelayerFactory.deployChainlinkRelayer(CHAINLINK_RETH_ETH_FEED, 86_400);

    emit log_named_address('WSTETH / ETH Oracle Address', address(_wstethETHPriceFeedNew));
    emit log_named_address('RETH / ETH Oracle Address', address(_rethETHPriceFeedNew));

    _usdEthRelayer = 0x3e6C1621f674da311E57646007fBfAd857084383;

    IBaseOracle _wstethUSDPriceFeedNew =
      denominatedOracleFactory.deployDenominatedOracle(_wstethETHPriceFeedNew, IBaseOracle(_usdEthRelayer), false);
    IBaseOracle _rethUSDPriceFeedNew =
      denominatedOracleFactory.deployDenominatedOracle(_rethETHPriceFeedNew, IBaseOracle(_usdEthRelayer), false);

    emit log_named_address('WSTETH / USD Oracle Address', address(_wstethUSDPriceFeedNew));
    emit log_named_address('RETH / USD Oracle Address', address(_rethUSDPriceFeedNew));

    IBaseOracle _wstethDelayedOracleNew =
      delayedOracleFactory.deployDelayedOracle(_wstethUSDPriceFeedNew, ORACLE_INTERVAL_PROD);
    IBaseOracle _rethDelayedOracleNew =
      delayedOracleFactory.deployDelayedOracle(_rethUSDPriceFeedNew, ORACLE_INTERVAL_PROD);

    emit log_named_address('WSTETH Delayed Oracle Address', address(_wstethDelayedOracleNew));
    emit log_named_address('RETH Delayed Oracle Address', address(_rethDelayedOracleNew));

    oracleRelayer.modifyParameters(WSTETH, 'oracle', bytes(abi.encode(_wstethDelayedOracleNew)));
    oracleRelayer.modifyParameters(RETH, 'oracle', bytes(abi.encode(_rethDelayedOracleNew)));

    if (_broadcast) vm.stopBroadcast();
    else vm.stopPrank();
  }
}

// BROADCAST
// source .env && forge script UpdateStabilityFee --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script UpdateStabilityFee --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC
contract UpdateStabilityFee is Base {
  function run() public {
    bool _broadcast;
    if (_deployer == _DEPLOYER) _broadcast = true;

    if (_broadcast) vm.startBroadcast(_deployerPk);
    else vm.startPrank(_DEPLOYER);

    // uint256 constant PLUS_5_PERCENT_PER_YEAR = 1_000_000_001_547_125_957_863_212_448;
    taxCollector.modifyParameters(ARB, 'stabilityFee', abi.encode(1_000_000_001_547_125_957_863_212_448));

    if (_broadcast) vm.stopBroadcast();
    else vm.stopPrank();
  }
}

// BROADCAST
// source .env && forge script DeployNFTRendererMainnet --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployNFTRendererMainnet --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract DeployNFTRendererMainnet is Base {
  function run() public {
    bool _broadcast;
    if (_deployer == _DEPLOYER) _broadcast = true;

    if (_broadcast) vm.startBroadcast(_deployerPk);
    NFTRenderer nftRenderer =
      new NFTRenderer(address(vault721), address(oracleRelayer), address(taxCollector), address(collateralJoinFactory));

    nftRenderer.updateStabilityFee(RETH, '1.75');
    nftRenderer.updateStabilityFee(WSTETH, '1.85');
    nftRenderer.updateStabilityFee(ARB, '5');

    nftRenderer.addAuthorization(address(timelockController));
    nftRenderer.removeAuthorization(_deployer);

    if (_broadcast) vm.stopBroadcast();
    else vm.stopPrank();
  }
}

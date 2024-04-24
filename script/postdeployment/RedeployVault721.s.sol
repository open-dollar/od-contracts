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

abstract contract Base is MainnetContracts, Script, Test {
  IODCreate2Factory internal _create2 = IODCreate2Factory(MAINNET_CREATE2FACTORY);

  uint256 internal _deployerPk;
  address internal _deployer;

  bytes internal _vault721InitCode;
  bytes32 internal _vault721Hash;
  address internal _precomputeAddress;
  address internal _vault721;
  address internal _safeManager;
  address internal _nftRenderer;

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
  address internal constant _DEPLOYER = 0xF78dA2A37049627636546E0cFAaB2aD664950917;

  function run() public {
    bool _broadcast;
    if (_deployer == _DEPLOYER) _broadcast = true;

    if (_broadcast) vm.startBroadcast(_deployerPk);
    else vm.startPrank(_DEPLOYER);

    _vault721 = _create2.create2deploy(MAINNET_SALT_VAULT721, _vault721InitCode);
    Vault721(_vault721).initialize(MAINNET_TIMELOCK_CONTROLLER, BLOCK_DELAY, TIME_DELAY);

    _safeManager =
      address(new ODSafeManager(SAFEEngine_Address, _vault721, TaxCollector_Address, LiquidationEngine_Address));
    _nftRenderer =
      address(new NFTRenderer(_vault721, OracleRelayer_Address, TaxCollector_Address, CollateralJoinFactory_Address));

    emit log_named_address('Vault721 Address', _vault721);
    emit log_named_address('ODSafeManager Address', _safeManager);
    emit log_named_address('NFTRenderer Address', _nftRenderer);

    SAFEEngine(SAFEEngine_Address).modifyParameters('odSafeManager', bytes(abi.encodePacked(_safeManager)));

    IAuthorizable(_safeManager).addAuthorization(MAINNET_TIMELOCK_CONTROLLER);
    IAuthorizable(_safeManager).removeAuthorization(_DEPLOYER);

    if (_broadcast) vm.stopBroadcast();
    else vm.stopPrank();
  }
}

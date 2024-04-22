// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {Script} from 'forge-std/Script.sol';
import {Test} from 'forge-std/Test.sol';
import {IODCreate2Factory} from '@interfaces/factories/IODCreate2Factory.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';
import {MainnetContracts} from '@script/MainnetContracts.s.sol';

// BROADCAST
// source .env && forge script Redeploy --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script Redeploy --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract Redeploy is MainnetContracts, Script, Test {
  IODCreate2Factory internal _create2 = IODCreate2Factory(MAINNET_CREATE2FACTORY);

  bytes internal _vault721InitCode;
  bytes32 internal _vault721Hash;
  address internal _precomputeAddress;

  address internal _vault721;
  address internal _safeManager;
  address internal _nftRenderer;

  function run() public {
    uint256 _deployerPk = vm.envUint('ARB_MAINNET_DEPLOYER_PK');
    address _deployer = vm.addr(_deployerPk);

    vm.startBroadcast(_deployerPk);

    _vault721InitCode = type(Vault721).creationCode;
    _vault721Hash = keccak256(_vault721InitCode);

    _precomputeAddress = _create2.precomputeAddress(MAINNET_SALT_VAULT721, _vault721Hash);
    emit log_named_address('Vault721 precompute', _precomputeAddress);

    _vault721 = _create2.create2deploy(MAINNET_SALT_VAULT721, _vault721InitCode);
    emit log_named_address('Vault721 deployment', _vault721);

    Vault721(_vault721).initialize(MAINNET_TIMELOCK_CONTROLLER, BLOCK_DELAY, TIME_DELAY);

    _safeManager =
      address(new ODSafeManager(SAFEEngine_Address, _vault721, TaxCollector_Address, LiquidationEngine_Address));
    emit log_named_address('ODSafeManager deployment', _safeManager);

    _nftRenderer =
      address(new NFTRenderer(_vault721, OracleRelayer_Address, TaxCollector_Address, CollateralJoinFactory_Address));
    emit log_named_address('NFTRenderer deployment', _nftRenderer);

    IAuthorizable(_safeManager).addAuthorization(MAINNET_TIMELOCK_CONTROLLER);
    IAuthorizable(_safeManager).removeAuthorization(_deployer);

    vm.stopBroadcast();
  }
}

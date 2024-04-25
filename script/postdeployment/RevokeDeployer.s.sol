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
import {MainnetDeployment} from '@script/MainnetDeployment.s.sol';

// BROADCAST
// source .env && forge script RevokeDeployer --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script RevokeDeployer --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_MAINNET_RPC

contract RevokeDeployer is MainnetDeployment, Script, Test {
  address internal constant _TIMELOCKCONTROLLER = MAINNET_TIMELOCK_CONTROLLER;
  address internal constant _OD_GOVERNOR = MAINNET_OD_GOVERNOR;
  address internal constant _DEPLOYER = 0xF78dA2A37049627636546E0cFAaB2aD664950917;

  function run() public {
    uint256 _deployerPk = vm.envUint('ARB_MAINNET_DEPLOYER_PK');
    address _deployer = vm.addr(_deployerPk);
    bool _broadcast;

    if (_deployer == _DEPLOYER) _broadcast = true;

    if (_broadcast) vm.startBroadcast(_deployerPk);
    else vm.startPrank(_DEPLOYER);

    // base contracts
    _updateAuth(safeEngine);
    _updateAuth(liquidationEngine);
    _updateAuth(accountingEngine);
    _updateAuth(oracleRelayer);

    // auction houses
    _updateAuth(surplusAuctionHouse);
    _updateAuth(debtAuctionHouse);

    // tax
    _updateAuth(taxCollector);
    _updateAuth(stabilityFeeTreasury);

    // tokens
    _updateAuth(systemCoin);
    _updateAuth(protocolToken);

    // pid controller
    _updateAuth(pidController);
    _updateAuth(pidRateSetter);

    // token adapters
    _updateAuth(coinJoin);

    // safe manager
    _updateAuth(safeManager);

    // factories or children
    _updateAuth(collateralJoinFactory);
    _updateAuth(collateralAuctionHouseFactory);

    // global settlement
    _updateAuth(globalSettlement);
    _updateAuth(postSettlementSurplusAuctionHouse);
    _updateAuth(settlementSurplusAuctioneer);

    // jobs
    _updateAuth(accountingJob);
    _updateAuth(liquidationJob);
    _updateAuth(oracleJob);

    if (_broadcast) vm.stopBroadcast();
    else vm.stopPrank();
  }

  /**
   * @dev authorize the timelockController to all protocol contracts
   * 	&& revoke the deployer and odGovernor
   *
   * @notice this script can only be run once by deployer
   */
  function _updateAuth(IAuthorizable _contract) internal {
    if (!_checkAuth(_contract, _TIMELOCKCONTROLLER)) _contract.addAuthorization(_TIMELOCKCONTROLLER);

    if (_checkAuth(_contract, _OD_GOVERNOR)) _contract.removeAuthorization(_OD_GOVERNOR);
    if (_checkAuth(_contract, _DEPLOYER)) _contract.removeAuthorization(_DEPLOYER);
  }

  function _checkAuth(IAuthorizable _contract, address _account) internal view returns (bool _auth) {
    _auth = _contract.authorizedAccounts(_account);
  }
}

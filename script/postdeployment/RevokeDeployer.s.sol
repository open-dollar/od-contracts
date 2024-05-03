// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import '@script/Registry.s.sol';
import {PrankSwitch} from '@script/utils/PrankSwitch.s.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
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

contract RevokeDeployer is MainnetDeployment, PrankSwitch {
  address internal constant _TIMELOCKCONTROLLER = MAINNET_TIMELOCK_CONTROLLER;
  address internal constant _DEPLOYER = 0xF78dA2A37049627636546E0cFAaB2aD664950917;

  error AuthUpdateFail();

  /**
   * IMPORTANT!
   * @notice renounces deployer from TIMELOCK_ADMIN_ROLE preventing governance upgradeability
   *
   * @dev this script can only be run once by deployer
   */
  function run() public prankSwitch(_deployer, MAINNET_TIMELOCK_CONTROLLER) {
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
    _updateAuth(vault721);

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

    // governance
    _renounceRoles(TimelockController(payable(_TIMELOCKCONTROLLER)));
  }

  /**
   * @dev check authorization of authorizable contract
   */
  function _checkAuth(IAuthorizable _contract, address _account) internal view returns (bool _auth) {
    _auth = _contract.authorizedAccounts(_account);
  }

  /**
   * @dev check that authorization of timelockController added & authorization of deployer revoked
   */
  function _enforceAuthTransfer(IAuthorizable _contract) internal view returns (bool) {
    if (_checkAuth(_contract, _TIMELOCKCONTROLLER) && !_checkAuth(_contract, _DEPLOYER)) return true;
    else return false;
  }

  /**
   * @dev authorize the timelockController to all protocol contracts & revoke the deployer
   */
  function _updateAuth(IAuthorizable _contract) internal {
    if (!_checkAuth(_contract, _TIMELOCKCONTROLLER)) _contract.addAuthorization(_TIMELOCKCONTROLLER);
    if (_checkAuth(_contract, _DEPLOYER)) _contract.removeAuthorization(_DEPLOYER);

    if (!_enforceAuthTransfer(_contract)) revert AuthUpdateFail();
  }

  /**
   * @dev revoke deployer from all roles on the timelockController
   */
  function _renounceRoles(TimelockController _tlc) internal {
    bytes32 proposer = _tlc.PROPOSER_ROLE();
    bytes32 executor = _tlc.EXECUTOR_ROLE();
    bytes32 canceller = _tlc.CANCELLER_ROLE();
    bytes32 admin = _tlc.TIMELOCK_ADMIN_ROLE();

    if (_tlc.hasRole(proposer, _DEPLOYER)) _tlc.renounceRole(proposer, _DEPLOYER);
    if (_tlc.hasRole(executor, _DEPLOYER)) _tlc.renounceRole(executor, _DEPLOYER);
    if (_tlc.hasRole(canceller, _DEPLOYER)) _tlc.renounceRole(canceller, _DEPLOYER);
    if (_tlc.hasRole(admin, _DEPLOYER)) _tlc.renounceRole(admin, _DEPLOYER);
  }
}

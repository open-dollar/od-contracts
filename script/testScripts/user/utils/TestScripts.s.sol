  // SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Deployment} from '@script/testScripts/user/utils/Deployment.s.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {Math} from '@libraries/Math.sol';

// TODO update these scritps to work with the NFT-mods / new contracts

contract TestScripts is Deployment {
  using Math for uint256;
  /**
   * @dev this function calls the proxyFactory directly,
   * therefore it bypasses the proxyRegistry and proxy address
   * will not be saved in the proxyRegistry mapping
   */

  function deploy() public returns (address payable) {
    return vault721.build();
  }

  /**
   * @dev this function calls the proxyFactory via ProxyRegistry,
   * and it will only allow 1 proxy per wallet/EOA.
   * use the `deployProxy` script to bypass the ProxyRegistry
   */
  function deployOrFind(address owner) public returns (address payable) {
    address proxy = vault721.getProxy(owner);
    if (proxy == address(0)) {
      return vault721.build(owner);
    } else {
      return payable(address(proxy));
    }
  }

  /**
   * @dev open new saf
   */
  function openSafe(bytes32 _cType, address _proxy) public returns (uint256 _safeId) {
    _labelAddresses(_proxy);
    bytes memory payload = abi.encodeWithSelector(basicActions.openSAFE.selector, address(safeManager), _cType, _proxy);
    bytes memory _safeData = ODProxy(_proxy).execute(address(basicActions), payload);
    _safeId = abi.decode(_safeData, (uint256));
  }

  /**
   * @dev lock collateral and generate debt
   * deltaWad can be set to zero to only lock collateral and generate zero debt
   */
  function depositCollatAndGenDebt(
    bytes32 _cType,
    uint256 _safeId,
    uint256 _collatAmount,
    uint256 _deltaWad,
    address _proxy
  ) public {
    _labelAddresses(_cType, _proxy);
    bytes memory payload = abi.encodeWithSelector(
      basicActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(collateralJoin[_cType]),
      address(coinJoin),
      _safeId,
      _collatAmount,
      _deltaWad
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  /**
   * @dev this function has a bug
   * in order to lockCollateral, use the lockCollatAndGenDebt script, with deltaWad (debt to generate) set to zero
   */
  function depositCollat(bytes32 _cType, uint256 _safeId, uint256 _collatAmount, address _proxy) public {
    _labelAddresses(_cType, _proxy);
    bytes memory payload = abi.encodeWithSelector(
      basicActions.lockTokenCollateral.selector,
      address(safeManager),
      address(collateralJoin[_cType]),
      _safeId,
      _collatAmount
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  /**
   * @dev generate debt from safe that has sufficient collateral locked
   */
  function genDebt(uint256 _safeId, uint256 _deltaWad, address _proxy) public {
    _labelAddresses(_proxy);
    bytes memory payload = abi.encodeWithSelector(
      basicActions.generateDebt.selector, address(safeManager), address(coinJoin), _safeId, _deltaWad
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  /**
   * @dev repays a specified amount of debt
   */
  function repayDebt(uint256 _safeId, uint256 _deltaWad, address _proxy) public {
    _labelAddresses(_proxy);
    bytes memory payload = abi.encodeWithSelector(
      basicActions.repayDebt.selector, address(safeManager), address(coinJoin), _safeId, _deltaWad
    );

    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function freeTokenCollateral(bytes32 _cType, uint256 _safeId, uint256 _deltaWad, address _proxy) public {
    _labelAddresses(_cType, _proxy);
    bytes memory payload = abi.encodeWithSelector(
      basicActions.freeTokenCollateral.selector,
      address(safeManager),
      address(collateralJoin[_cType]),
      _safeId,
      _deltaWad
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  /**
   * @dev repays all of debt with user's COIN BALANCE
   */
  function repayAllDebt(uint256 _safeId, address _proxy) public {
    bytes memory payload =
      abi.encodeWithSelector(basicActions.repayAllDebt.selector, address(safeManager), address(coinJoin), _safeId);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  /**
   * @dev will repays all debt with user's COIN balance and unlocks all collateral
   */
  function repayAllDebtAndFreeTokenCollateral(bytes32 _cType, uint256 _safeId, address _proxy) public {
    _labelAddresses(_proxy);

    bytes memory payload = abi.encodeWithSelector(
      basicActions.repayAllDebtAndFreeTokenCollateral.selector,
      address(safeManager),
      collateralJoin[_cType],
      address(coinJoin),
      _safeId,
      COLLATERAL
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  /**
   * @dev Allows a safe handler
   */
  function allowHandler(address _usr, bool _ok, address _proxy) public {
    bytes memory payload = abi.encodeWithSelector(basicActions.allowHandler.selector, address(safeManager), _usr, _ok);
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function safeData(uint256 _safeId) public view returns (IODSafeManager.SAFEData memory _safeData) {
    _safeData = safeManager.safeData(_safeId);
  }

  /**
   * @dev Allows a safe
   */
  function allowSAFE(address _usr, uint256 _safeId, bool _ok, address _proxy) public {
    bytes memory payload =
      abi.encodeWithSelector(basicActions.allowSAFE.selector, address(safeManager), _safeId, _usr, _ok);

    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function _labelAddresses(address _proxy) internal {
    vm.label(address(_proxy), 'ODProxy');
    _labelKnownAddresses();
  }

  function _labelAddresses(bytes32 _cType, address _proxy) internal {
    vm.label(address(collateralJoin[_cType]), 'Collateral Join');
    vm.label(address(_proxy), 'ODProxy');
    _labelKnownAddresses();
  }

  function _labelKnownAddresses() internal {
    vm.label(address(vault721), 'Vault721');
    vm.label(address(basicActions), 'BasicActions');
    vm.label(address(debtBidActions), 'DebtBidActions');
    vm.label(address(surplusBidActions), 'SurplusBidActions');
    vm.label(address(collateralBidActions), 'collateralBidActions');
    vm.label(address(rewardedActions), 'rewardedActions');
    vm.label(address(protocolToken), 'ProtocolToken');
    vm.label(address(systemCoin), 'SystemCoin');
    vm.label(address(taxCollector), 'TaxCollector');
    vm.label(address(safeEngine), 'SAFEEngine');
    vm.label(address(USER2), 'User');
    vm.label(address(safeManager), 'SAFE MANAGER');
    vm.label(address(coinJoin), 'COIN JOIN');
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ICamelotRelayerFactory} from '@interfaces/factories/ICamelotRelayerFactory.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';

import {CamelotRelayerChild} from '@contracts/factories/CamelotRelayerChild.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

contract CamelotRelayerFactory is Authorizable, ICamelotRelayerFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  // --- Data ---
  EnumerableSet.AddressSet internal _camelotRelayers;

  // --- Init ---
  constructor() Authorizable(msg.sender) {}

  // --- Methods ---
  function deployCamelotRelayer(
    address _algebraV3Factory,
    address _baseToken,
    address _quoteToken,
    uint32 _quotePeriod
  ) external isAuthorized returns (IBaseOracle _camelotRelayer) {
    _camelotRelayer = new CamelotRelayerChild(_algebraV3Factory, _baseToken, _quoteToken, _quotePeriod);
    _camelotRelayers.add(address(_camelotRelayer));
    emit NewCamelotRelayer(address(_camelotRelayer), _baseToken, _quoteToken, _quotePeriod);
  }

  // --- Views ---
  function camelotRelayersList() external view returns (address[] memory _camelotRelayersList) {
    return _camelotRelayers.values();
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IUniV3RelayerFactory} from '@interfaces/factories/IUniV3RelayerFactory.sol';

import {UniV3RelayerChild} from '@contracts/factories/UniV3RelayerChild.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

contract UniV3RelayerFactory is Authorizable, IUniV3RelayerFactory {
  using EnumerableSet for EnumerableSet.AddressSet;

  // --- Data ---
  EnumerableSet.AddressSet internal _uniV3Relayers;

  // --- Init ---
  constructor() Authorizable(msg.sender) {}

  // --- Methods ---
  function deployUniV3Relayer(
    address _baseToken,
    address _quoteToken,
    uint24 _feeTier,
    uint32 _quotePeriod
  ) external isAuthorized returns (address _uniV3Relayer) {
    _uniV3Relayer = address(new UniV3RelayerChild(_baseToken, _quoteToken, _feeTier, _quotePeriod));
    _uniV3Relayers.add(_uniV3Relayer);
    emit NewUniV3Relayer(_uniV3Relayer, _baseToken, _quoteToken, _feeTier, _quotePeriod);
  }

  // --- Views ---
  function uniV3RelayersList() external view returns (address[] memory _uniV3RelayersList) {
    return _uniV3Relayers.values();
  }
}

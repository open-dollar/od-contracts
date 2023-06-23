// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface IUniV3RelayerFactory is IAuthorizable {
  // --- Events ---
  event NewUniV3Relayer(
    address indexed _uniV3Relayer, address _baseToken, address _quoteToken, uint24 _feeTier, uint32 _quotePeriod
  );

  // --- Methods ---
  function deployUniV3Relayer(
    address _baseToken,
    address _quoteToken,
    uint24 _feeTier,
    uint32 _quotePeriod
  ) external returns (address _uniV3Relayer);

  // --- Views ---
  function uniV3RelayersList() external view returns (address[] memory _uniV3RelayersList);
}

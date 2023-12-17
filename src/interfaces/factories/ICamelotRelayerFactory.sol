// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface ICamelotRelayerFactory is IAuthorizable {
  // --- Events ---
  event NewCamelotRelayer(
    address indexed _camelotRelayer, address _baseToken, address _quoteToken, uint32 _quotePeriod
  );

  // --- Methods ---
  function deployCamelotRelayer(
    address _algebraV3Factory,
    address _baseToken,
    address _quoteToken,
    uint32 _quotePeriod
  ) external returns (IBaseOracle _camelotRelayer);

  // --- Views ---
  function camelotRelayersList() external view returns (address[] memory _camelotRelayersList);
}

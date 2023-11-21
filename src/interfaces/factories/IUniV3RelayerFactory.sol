// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface IUniV3RelayerFactory is IAuthorizable {
  // --- Events ---

  /**
   * @notice Emitted when a new UniV3Relayer contract is deployed
   * @param _uniV3Relayer Address of the deployed UniV3Relayer contract
   * @param _baseToken Address of the base token to be quoted by the UniV3Relayer contract
   * @param _quoteToken Address of the quote reference token for the UniV3Relayer contract
   * @param _feeTier Fee tier used to identify the pool for the UniV3Relayer contract
   * @param _quotePeriod Length of the period used to calculate the TWAP quote for the UniV3Relayer contract
   */
  event NewUniV3Relayer(
    address indexed _uniV3Relayer, address _baseToken, address _quoteToken, uint24 _feeTier, uint32 _quotePeriod
  );

  // --- Methods ---

  /**
   * @notice Deploys a new UniV3Relayer contract
   * @param _baseToken Address of the base token to be quoted
   * @param _quoteToken Address of the quote reference token
   * @param _feeTier Fee tier used to identify the UniV3 pool
   * @param _quotePeriod Length of the period used to calculate the TWAP quote
   * @return _uniV3Relayer Address of the deployed UniV3Relayer contract
   */
  function deployUniV3Relayer(
    address _baseToken,
    address _quoteToken,
    uint24 _feeTier,
    uint32 _quotePeriod
  ) external returns (IBaseOracle _uniV3Relayer);

  // --- Views ---

  /**
   * @notice Getter for the list of UniV3Relayer contracts
   * @return _uniV3RelayersList List of UniV3Relayer contracts
   */
  function uniV3RelayersList() external view returns (address[] memory _uniV3RelayersList);
}

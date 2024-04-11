// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface IDenominatedOracleFactory is IAuthorizable {
  // --- Events ---

  /**
   * @notice Emitted when a new DenominatedOracle contract is deployed
   * @param _denominatedOracle Address of the deployed DenominatedOracle contract
   * @param _priceSource Address of the price source for the DenominatedOracle contract
   * @param _denominationPriceSource Address of the denomination price source for the DenominatedOracle contract
   * @param _inverted Boolean indicating if the denomination calculation quote should be inverted
   */
  event NewDenominatedOracle(
    address indexed _denominatedOracle, address _priceSource, address _denominationPriceSource, bool _inverted
  );

  // --- Methods ---

  /**
   * @notice Deploys a new DenominatedOracle contract
   * @param _priceSource Address of the price source for the DenominatedOracle contract
   * @param _denominationPriceSource Address of the denomination price source for the DenominatedOracle contract
   * @param _inverted Boolean indicating if the denomination calculation quote should be inverted
   * @return _denominatedOracle Address of the deployed DenominatedOracle contract
   * @dev   The denomination quote should follow the format: `(A / B) * (B / C) = A / C`
   * @dev   If the quote is inverted, the format should be read as: `(B / A)^-1 * (B / C) = A / C`
   */
  function deployDenominatedOracle(
    IBaseOracle _priceSource,
    IBaseOracle _denominationPriceSource,
    bool _inverted
  ) external returns (IBaseOracle _denominatedOracle);

  // --- Views ---

  /**
   * @notice Getter for the list of DenominatedOracle contracts
   * @return _denominatedOraclesList List of DenominatedOracle contracts
   */
  function denominatedOraclesList() external view returns (address[] memory _denominatedOraclesList);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {Math} from '@libraries/Math.sol';

/**
 * @title  DeviatedOracle
 * @notice This oracle is used to simulate a price source that returns a price deviated from the redemption price
 */
contract DeviatedOracle is IBaseOracle {
  using Math for uint256;

  /// @notice The proportional deviation from the redemption price [wad %]
  uint256 public deviation;

  /// @inheritdoc IBaseOracle
  string public symbol;

  /// @notice The oracle relayer contract
  IOracleRelayer public oracleRelayer;

  /**
   * @param _symbol The symbol of the oracle
   * @param _oracleRelayer The address of the oracle relayer contract
   * @param _deviation The proportional deviation from the redemption price [wad %]
   */
  constructor(string memory _symbol, address _oracleRelayer, uint256 _deviation) {
    symbol = _symbol;
    oracleRelayer = IOracleRelayer(_oracleRelayer);
    deviation = _deviation;
  }

  /// @inheritdoc IBaseOracle
  function getResultWithValidity() external view returns (uint256 _price, bool _validity) {
    _validity = true;
    _price = oracleRelayer.calcRedemptionPrice();
    _price = (_price / 1e9).wmul(deviation);
  }

  /// @inheritdoc IBaseOracle
  function read() external view returns (uint256 _price) {
    _price = oracleRelayer.calcRedemptionPrice();
    _price = (_price / 1e9).wmul(deviation);
  }
}

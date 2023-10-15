// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ICamelotRelayer} from '@interfaces/oracles/ICamelotRelayer.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IAlgebraFactory} from '@cryptoalgebra-i-core/IAlgebraFactory.sol';
import {IAlgebraPool} from '@cryptoalgebra-i-core/IAlgebraPool.sol';
import {IDataStorageOperator} from 'lib/Algebra/src/core/contracts/interfaces/IDataStorageOperator.sol';
import {DataStorageLibrary} from 'lib/Algebra/src/periphery/contracts/libraries/DataStorageLibrary.sol';
import {CAMELOT_V3_FACTORY, GOERLI_CAMELOT_V3_FACTORY} from '@script/Registry.s.sol';

/**
 * @title  CamelotRelayer
 * @notice This contracts consults a CamelotRelayer TWAP and transforms the result into a standard IBaseOracle feed
 * @dev    The quote obtained from the pool query is transformed into an 18 decimals format
 */
contract CamelotRelayer is IBaseOracle, ICamelotRelayer {
  // --- Registry ---
  address internal constant _CAMELOT_FACTORY = GOERLI_CAMELOT_V3_FACTORY;

  /// @inheritdoc ICamelotRelayer
  address public camelotPool;
  /// @inheritdoc ICamelotRelayer
  address public baseToken;
  /// @inheritdoc ICamelotRelayer
  address public quoteToken;

  // --- Data ---
  /// @inheritdoc IBaseOracle
  string public symbol;

  /// @inheritdoc ICamelotRelayer
  uint128 public baseAmount;
  /// @inheritdoc ICamelotRelayer
  uint256 public multiplier;
  /// @inheritdoc ICamelotRelayer
  uint32 public quotePeriod;

  constructor(address _baseToken, address _quoteToken, uint32 _quotePeriod) {
    // camelotPool = ICamelotFactory(_CAMELOT_FACTORY).getPair(_baseToken, _quoteToken);
    camelotPool = IAlgebraFactory(_CAMELOT_FACTORY).poolByPair(_baseToken, _quoteToken);
    if (camelotPool == address(0)) revert CamelotRelayer_InvalidPool();

    address _token0 = IAlgebraPool(camelotPool).token0();
    address _token1 = IAlgebraPool(camelotPool).token1();

    // The factory validates that both token0 and token1 are desired baseToken and quoteTokens
    if (_token0 == _baseToken) {
      baseToken = _token0;
      quoteToken = _token1;
    } else {
      baseToken = _token1;
      quoteToken = _token0;
    }

    baseAmount = uint128(10 ** IERC20Metadata(_baseToken).decimals());
    multiplier = 18 - IERC20Metadata(_quoteToken).decimals();
    quotePeriod = _quotePeriod;

    symbol = string(abi.encodePacked(IERC20Metadata(_baseToken).symbol(), ' / ', IERC20Metadata(_quoteToken).symbol()));
  }

  /**
   * @dev    Method will return invalid if the pool doesn't have enough history
   * @inheritdoc IBaseOracle
   */
  function getResultWithValidity() external view returns (uint256 _result, bool _validity) {
    // If the pool doesn't have enough history return false
    // if (OracleLibrary.getOldestObservationSecondsAgo(camelotPool) < quotePeriod) {
    //   return (0, false);
    // }

    // Consult the query with a TWAP period of quotePeriod
    int24 _arithmeticMeanTick = DataStorageLibrary.consult(camelotPool, quotePeriod);
    // Calculate the quote amount
    uint256 _quoteAmount = DataStorageLibrary.getQuoteAtTick({
      tick: _arithmeticMeanTick,
      baseAmount: baseAmount,
      baseToken: baseToken,
      quoteToken: quoteToken
    });
    // Process the quote result to 18 decimal quote
    _result = _parseResult(_quoteAmount);
    _validity = true;
  }

  /**
   * @dev    This method may revert with 'OLD!' if the pool doesn't have enough cardinality or initialized history
   * @inheritdoc IBaseOracle
   */
  function read() external view returns (uint256 _result) {
    // This call may revert with 'OLD!' if the pool doesn't have enough cardinality or initialized history
    int24 _arithmeticMeanTick = DataStorageLibrary.consult(camelotPool, quotePeriod);
    uint256 _quoteAmount = DataStorageLibrary.getQuoteAtTick({
      tick: _arithmeticMeanTick,
      baseAmount: baseAmount,
      baseToken: baseToken,
      quoteToken: quoteToken
    });
    _result = _parseResult(_quoteAmount);
  }

  function _parseResult(uint256 _quoteResult) internal view returns (uint256 _result) {
    return _quoteResult * 10 ** multiplier;
  }
}

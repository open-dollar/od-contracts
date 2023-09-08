// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {ICamelotRelayer} from '@interfaces/oracles/ICamelotRelayer.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {ICamelotFactory} from '@camelot/interfaces/ICamelotFactory.sol';
import {ICamelotPair} from '@camelot/interfaces/ICamelotPair.sol';
import {OracleLibrary} from '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import {CAMELOT_FACTORY, GOERLI_CAMELOT_FACTORY} from '@script/Registry.s.sol';

/**
 * @title  CamelotRelayer
 * @notice This contracts consults a CamelotRelayer TWAP and transforms the result into a standard IBaseOracle feed
 * @dev    The quote obtained from the pool query is transformed into an 18 decimals format
 */
contract CamelotRelayer is IBaseOracle, ICamelotRelayer {
  // --- Registry ---
  address internal constant _CAMELOT_FACTORY = GOERLI_CAMELOT_FACTORY;

  /// @inheritdoc ICamelotRelayer
  address public camelotPair;
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

  constructor(address _baseToken, address _quoteToken, uint24 _feeTier, uint32 _quotePeriod) {
    camelotPair = ICamelotFactory(_CAMELOT_FACTORY).getPair(_baseToken, _quoteToken);
    if (camelotPair == address(0)) revert CamelotRelayer_InvalidPool();

    address _token0 = ICamelotPair(camelotPair).token0();
    address _token1 = ICamelotPair(camelotPair).token1();

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
    if (OracleLibrary.getOldestObservationSecondsAgo(camelotPair) < quotePeriod) {
      return (0, false);
    }
    // Consult the query with a TWAP period of quotePeriod
    (int24 _arithmeticMeanTick,) = OracleLibrary.consult(camelotPair, quotePeriod);
    // Calculate the quote amount
    uint256 _quoteAmount = OracleLibrary.getQuoteAtTick({
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
    (int24 _arithmeticMeanTick,) = OracleLibrary.consult(camelotPair, quotePeriod);
    uint256 _quoteAmount = OracleLibrary.getQuoteAtTick({
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

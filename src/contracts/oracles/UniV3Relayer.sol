// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IUniV3Relayer} from '@interfaces/oracles/IUniV3Relayer.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IUniswapV3Factory} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import {OracleLibrary, IUniswapV3Pool} from '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';

/**
 * @title  UniV3Relayer
 * @notice This contracts consults a UniswapV3Pool TWAP and transforms the result into a standard IBaseOracle feed
 * @dev    The quote obtained from the pool query is transformed into an 18 decimals format
 */
contract UniV3Relayer is IBaseOracle, IUniV3Relayer {
  // --- Registry ---
  address internal constant _UNI_V3_FACTORY = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);

  /// @inheritdoc IUniV3Relayer
  address public uniV3Pool;
  /// @inheritdoc IUniV3Relayer
  address public baseToken;
  /// @inheritdoc IUniV3Relayer
  address public quoteToken;

  // --- Data ---
  /// @inheritdoc IBaseOracle
  string public symbol;

  /// @inheritdoc IUniV3Relayer
  uint128 public baseAmount;
  /// @inheritdoc IUniV3Relayer
  uint256 public multiplier;
  /// @inheritdoc IUniV3Relayer
  uint32 public quotePeriod;

  constructor(address _baseToken, address _quoteToken, uint24 _feeTier, uint32 _quotePeriod) {
    uniV3Pool = IUniswapV3Factory(_UNI_V3_FACTORY).getPool(_baseToken, _quoteToken, _feeTier);
    if (uniV3Pool == address(0)) revert InvalidPool();

    address _token0 = IUniswapV3Pool(uniV3Pool).token0();
    address _token1 = IUniswapV3Pool(uniV3Pool).token1();

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
    if (OracleLibrary.getOldestObservationSecondsAgo(uniV3Pool) < quotePeriod) {
      return (0, false);
    }
    // Consult the query with a TWAP period of quotePeriod
    (int24 _arithmeticMeanTick,) = OracleLibrary.consult(uniV3Pool, quotePeriod);
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
    (int24 _arithmeticMeanTick,) = OracleLibrary.consult(uniV3Pool, quotePeriod);
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

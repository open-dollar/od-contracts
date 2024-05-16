// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ISAFESaviour} from './ISAFESaviour.sol';
import {IERC20} from '@openzeppelin/token/ERC20/ERC20.sol';

interface IODSaviour is ISAFESaviour {
  event VaultStatusSet(uint256 _vaultId, bool _enabled);
  event CollateralTypeAdded(bytes32 _cType, address _tokenAddress);
  event SafeSaved(uint256 _vaultId, uint256 _reqCollateral);
  event LiquidatorRewardSet(uint256 _newReward);

  error OnlySaviourTreasury();
  error LengthMismatch();
  error VaultNotAllowed(uint256 _vaultId);
  error CollateralTransferFailed();
  error OnlyLiquidationEngine();
  error SafetyRatioMet();
  error AlreadyInitialized(bytes32);
  error UninitializedCollateral(bytes32);
  error CollateralMustBeInitialized(bytes32);
  /**
   * @notice SaviourInit struct
   *   @param saviourTreasury the address of the saviour treasury
   *   @param protocolGovernor the address of the protocol governor
   *   @param liquidationEngine the address ot the liquidation engine;
   *   @param vault721 the address of the vault721
   *   @param cTypes an array of collateral types that can be used in this saviour (bytes32('ARB'));
   *   @param saviourTokens the addresses of the saviour tokens to be used in this contract;
   */

  struct SaviourInit {
    address vault721;
    address oracleRelayer;
    address collateralJoinFactory;
  }

  function isEnabled(uint256 _vaultId) external view returns (bool _enabled);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC721} from '@openzeppelin/tokens/ERC721.sol';

contract Vault721 is ERC721 {}

// Vars to inlcude in NFT

// Collateral Type
//   contract: HaiSafeManager
//   function: safeData(uint256 _safe)

// Collateral Ratio
//   contract: OracleRelayer
//   function: cParams(bytes32 _cType)

// Stability Fee
//   contract: TaxCollector
//   function: cParams(bytes32 _cType)

// Liquidation Penalty
//   contract: LiquidationEngine
//   function: cParams(bytes32 _cType)

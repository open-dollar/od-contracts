// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {IERC7496} from '@contracts/adapters/IERC7496.sol';

/**
 * @notice IERC7496 events are never emitted since NFVState is tracked in Vault721
 */
abstract contract ERC7496Adapter is IERC7496 {
  bytes32 public constant COLLATERAL = keccak256('COLLATERAL');
  bytes32 public constant DEBT = keccak256('DEBT');

  IVault721 public vault721;

  error Disabled();
  error UnknownTraitKeys();

  constructor(IVault721 _vault721) {
    vault721 = _vault721;
  }

  /**
   * @dev get NFV trait
   */
  function getTraitValue(uint256 _tokenId, bytes32 _traitKey) external view returns (bytes32 traitValue) {
    (bytes32 _collateral, bytes32 _debt) = _getTraitValues(_tokenId);
    if (_traitKey == COLLATERAL) return _collateral;
    if (_traitKey == DEBT) return _debt;
  }

  /**
   * @dev get NFV traits
   */
  function getTraitValues(
    uint256 _tokenId,
    bytes32[] calldata _traitKeys
  ) external view returns (bytes32[] memory traitValues) {
    (bytes32 _collateral, bytes32 _debt) = _getTraitValues(_tokenId);
    traitValues = new bytes32[](2);
    if (_traitKeys[0] == COLLATERAL && _traitKeys[1] == DEBT) {
      traitValues[0] = _collateral;
      traitValues[1] = _debt;
    } else if (_traitKeys[0] == DEBT && _traitKeys[1] == COLLATERAL) {
      traitValues[0] = _debt;
      traitValues[1] = _collateral;
    } else {
      revert UnknownTraitKeys();
    }
  }

  /**
   * @dev ???
   */
  function getTraitMetadataURI() external view returns (string memory uri) {
    uri = '?';
  }

  /**
   * @dev setTrait is disabled; NFVState is found in Vault721
   */
  function setTrait(uint256, bytes32, bytes32) external {
    revert Disabled();
  }

  /**
   * @dev get NFVState from Vault721
   * @notice return values are not hashed to enable enforceable condition in zone
   */
  function _getTraitValues(uint256 _tokenId) internal view returns (bytes32 _collateral, bytes32 _debt) {
    IVault721.NFVState memory nfvState = vault721.getNfvState(_tokenId);
    _collateral = bytes32(nfvState.collateral);
    _debt = bytes32(nfvState.debt);
  }
}

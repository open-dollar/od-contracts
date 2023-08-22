// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IERC721} from '@openzeppelin/token/ERC721/IERC721.sol';
import {Ownable} from '@contracts/utils/Ownable.sol';
import {ISafeManager} from '@interfaces/proxies/ISafeManager.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';

contract ODProxy is Ownable {
  error TargetAddressRequired();
  error TargetCallFailed(bytes _response);

  address private immutable _VAULT721;

  constructor(address _owner, address _safeManager) Ownable(_owner) {
    _VAULT721 = msg.sender;
  }

  function execute(address _target, bytes memory _data) external payable onlyOwner returns (bytes memory _response) {
    if (_target == address(0)) revert TargetAddressRequired();

    bool _succeeded;
    (_succeeded, _response) = _target.delegatecall(_data);

    if (!_succeeded) {
      revert TargetCallFailed(_response);
    }
  }

  function setOwner(address _owner) external override {
    require(msg.sender == _VAULT721, 'Only Vault721');
    _setOwner(_owner);
  }

  // --- Internal ---
  function _setOwner(address _newOwner) internal override {
    ISafeManager _safeManager = ISafeManager(IVault721(_VAULT721).safeManager());
    uint256[] memory _safeIds = _safeManager.getSafes(address(this));

    uint256 length = _safeIds.length;
    for (uint256 i = 0; i < length;) {
      IERC721(_VAULT721).safeTransferFrom(owner, _newOwner, _safeIds[i]);
      ++i; // gas optimized
    }

    owner = _newOwner;
    emit SetOwner(_newOwner);
  }
}

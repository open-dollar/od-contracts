// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IERC721} from '@openzeppelin/token/ERC721/IERC721.sol';
import {Ownable} from '@contracts/utils/Ownable.sol';
import {ISafeManager} from '@interfaces/proxies/ISafeManager.sol';

contract ODProxy is Ownable {
  error TargetAddressRequired();
  error TargetCallFailed(bytes _response);

  address immutable vault721;
  ISafeManager immutable safeManager;

  constructor(address _owner, address _safeManager) Ownable(_owner) {
    vault721 = msg.sender;
    safeManager = ISafeManager(_safeManager);
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
    require(msg.sender == vault721, 'Only Vault721');
    _setOwner(_owner);
  }

  // --- Internal ---
  function _setOwner(address _newOwner) internal override {
    uint256[] memory safeIds = safeManager.getSafes(address(this));

    uint256 length = safeIds.length;
    for (uint256 i = 0; i < length;) {
      IERC721(vault721).safeTransferFrom(owner, _newOwner, safeIds[i]);
      ++i; // gas optimized
    }

    owner = _newOwner;
    emit SetOwner(_newOwner);
  }
}

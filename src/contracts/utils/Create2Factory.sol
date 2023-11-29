// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Vault721} from '@contracts/proxies/Vault721.sol';
import {SystemCoin} from '@contracts/tokens/SystemCoin.sol';
import {ProtocolToken} from '@contracts/tokens/ProtocolToken.sol';

contract Create2Factory {
  bytes internal _systemCoin;
  bytes internal _protocolToken;
  bytes internal _vault721;

  bytes32 public systemCoinHash;
  bytes32 public protocolTokenHash;
  bytes32 public vault721Hash;

  mapping(address _admin => bool _ok) public approved;

  event Deployed(address _addr, uint256 _salt);

  error AdminOnly();

  constructor() {
    approved[msg.sender] = true;

    _systemCoin = type(SystemCoin).creationCode;
    _protocolToken = type(ProtocolToken).creationCode;
    _vault721 = type(Vault721).creationCode;

    systemCoinHash = keccak256(_systemCoin);
    protocolTokenHash = keccak256(_protocolToken);
    vault721Hash = keccak256(_vault721);
  }

  modifier onlyAdmin() {
    if (approved[msg.sender] == false) revert AdminOnly();
    _;
  }

  function addAdmin(address _admin) external onlyAdmin {
    approved[_admin] = true;
  }

  function deployTokens(
    uint256 _salt1,
    uint256 _salt2
  ) external onlyAdmin returns (address _deployment1, address _deployment2) {
    _deployment1 = _deploy(_salt1, _systemCoin);
    _deployment2 = _deploy(_salt2, _protocolToken);
  }

  function deployVault721(uint256 _salt) external onlyAdmin returns (address _deployment) {
    _deployment = _deploy(_salt, _vault721);
  }

  function _deploy(uint256 _salt, bytes memory _bytecode) internal returns (address _deployment) {
    assembly {
      _deployment := create2(callvalue(), add(_bytecode, 0x20), mload(_bytecode), _salt)
      if iszero(extcodesize(_deployment)) { revert(0, 0) }
    }
    emit Deployed(_deployment, _salt);
  }
}

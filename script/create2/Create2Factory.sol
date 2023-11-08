// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {Vault721} from '@contracts/proxies/Vault721.sol';
import {SystemCoin} from '@contracts/tokens/SystemCoin.sol';
import {ProtocolToken} from '@contracts/tokens/ProtocolToken.sol';

contract Create2Factory {
  bytes internal _vault721;
  bytes internal _systemCoin;
  bytes internal _protocolToken;

  mapping(address _admin => bool _ok) public approved;

  event Deployed(address _addr, uint256 _salt);

  error AdminOnly();

  constructor() {
    approved[msg.sender] = true;

    _vault721 = type(Vault721).creationCode;
    _systemCoin = type(SystemCoin).creationCode;
    _protocolToken = type(ProtocolToken).creationCode;
  }

  modifier onlyAdmin() {
    if (approved[msg.sender] == false) revert AdminOnly();
    _;
  }

  function addAdmin(address _admin) external onlyAdmin {
    approved[_admin] = true;
  }

  function deploy(uint256 _salt1, uint256 _salt2, uint256 _salt3) external onlyAdmin {
    _deploy(_salt1, _vault721);
    _deploy(_salt2, _systemCoin);
    _deploy(_salt3, _protocolToken);
  }

  function _deploy(uint256 _salt, bytes memory _bytecode) internal {
    address _deployment;

    assembly {
      _deployment := create2(callvalue(), add(_bytecode, 0x20), mload(_bytecode), _salt)
      if iszero(extcodesize(_deployment)) { revert(0, 0) }
    }
    emit Deployed(_deployment, _salt);
  }
}

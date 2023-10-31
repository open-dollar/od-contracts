// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ERC20} from '@openzeppelin/token/ERC20/ERC20.sol';
import {ERC20Votes} from '@openzeppelin/token/ERC20/extensions/ERC20Votes.sol';
import {ERC20Permit} from '@openzeppelin/token/ERC20/extensions/ERC20Permit.sol';
import {Nonces} from '@openzeppelin/utils/Nonces.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {IProtocolToken, IERC20Permit} from '@interfaces/tokens/IProtocolToken.sol';

/**
 * @title  ProtocolToken
 * @notice This contract represents the protocol ERC20Votes token to be used for governance purposes
 */
contract ProtocolToken is ERC20, ERC20Permit, ERC20Votes, Authorizable, IProtocolToken {
  // --- Init ---

  /**
   * @param  _name String with the name of the token
   * @param  _symbol String with the symbol of the token
   */
  constructor(
    string memory _name,
    string memory _symbol
  ) ERC20(_name, _symbol) ERC20Permit(_name) Authorizable(msg.sender) {}

  // --- Methods ---

  /// @inheritdoc IProtocolToken
  function mint(address _dst, uint256 _wad) external isAuthorized {
    _mint(_dst, _wad);
  }

  /// @inheritdoc IProtocolToken
  function burn(uint256 _wad) external {
    _burn(msg.sender, _wad);
  }

  // --- Overrides ---

  function _update(address _from, address _to, uint256 _value) internal override(ERC20, ERC20Votes) {
    super._update(_from, _to, _value);
  }

  function nonces(address _owner) public view override(ERC20Permit, IERC20Permit, Nonces) returns (uint256 _nonce) {
    return super.nonces(_owner);
  }
}

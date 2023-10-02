// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC20Permit, ERC20} from '@openzeppelin/token/ERC20/extensions/ERC20Permit.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';

/**
 * @title  SystemCoin
 * @notice This contract represents the system coin ERC20 token to be used outside the system
 */
contract SystemCoin is ERC20Permit, Authorizable, ISystemCoin {
  // --- Init ---

  /**
   * @param  _name String with the name of the token
   * @param  _symbol String with the symbol of the token
   */
  constructor(
    string memory _name,
    string memory _symbol
  ) ERC20Permit(_name) ERC20(_name, _symbol) Authorizable(msg.sender) {}

  // --- Methods ---

  /// @inheritdoc ISystemCoin
  function mint(address _dst, uint256 _wad) external isAuthorized {
    _mint(_dst, _wad);
  }

  /// @inheritdoc ISystemCoin
  function burn(uint256 _wad) external {
    _burn(msg.sender, _wad);
  }
}

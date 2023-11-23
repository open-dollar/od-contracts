// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC20Upgradeable, IERC20Upgradeable} from '@openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import {AuthorizableUpgradeable} from '@contracts/utils/AuthorizableUpgradeable.sol';

import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';

/**
 * @title  SystemCoin
 * @notice This contract represents the system coin ERC20 token to be used outside the system
 */
contract SystemCoin is ERC20Upgradeable, AuthorizableUpgradeable, ISystemCoin {
  // --- Init ---

  constructor() {
    _disableInitializers();
  }

  /**
   * @param  _name String with the name of the token
   * @param  _symbol String with the symbol of the token
   */
  function initialize(string memory _name, string memory _symbol) external initializer {
    __ERC20_init(_name, _symbol);
    __authorizable_init(msg.sender);
  }

  // --- Methods ---

  /// @inheritdoc ISystemCoin
  function mint(address _dst, uint256 _wad) external isAuthorized {
    _mint(_dst, _wad);
  }

  /// @inheritdoc ISystemCoin
  function burn(uint256 _wad) external {
    _burn(msg.sender, _wad);
  }

  /// @inheritdoc ISystemCoin
  function burn(address _usr, uint256 _wad) external isAuthorized {
    _burn(_usr, _wad);
  }
}

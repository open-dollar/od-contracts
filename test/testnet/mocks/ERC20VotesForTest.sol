// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC20Upgradeable} from '@openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import {ERC20PermitUpgradeable} from '@openzeppelin-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol';
import {ERC20VotesUpgradeable} from '@openzeppelin-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol';

contract ERC20VotesForTest is ERC20PermitUpgradeable, ERC20VotesUpgradeable {
  function mint(uint256 _wad) external {
    _mint(msg.sender, _wad);
  }

  function mint(address _usr, uint256 _wad) external {
    _mint(_usr, _wad);
  }

  // --- Overrides ---

  function _mint(address _to, uint256 _amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
    super._mint(_to, _amount);
  }

  function _burn(address _account, uint256 _amount) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
    super._burn(_account, _amount);
  }

  function _afterTokenTransfer(
    address _from,
    address _to,
    uint256 _amount
  ) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
    super._afterTokenTransfer(_from, _to, _amount);
  }
}

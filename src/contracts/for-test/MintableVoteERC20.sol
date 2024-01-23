// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC20} from '@openzeppelin/token/ERC20/ERC20.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {ERC20Votes} from '@openzeppelin/token/ERC20/extensions/ERC20Votes.sol';
import {ERC20Permit} from '@openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol';
import {ERC20Burnable} from '@openzeppelin/token/ERC20/extensions/ERC20Burnable.sol';
import {MintableERC20} from '@contracts/for-test/MintableERC20.sol';

/**
 * @title  MintableERC20 with governance extensions
 * @notice This ERC20 contract is used for testing purposes, to allow users to mint delegatable tokens
 */
contract MintableVoteERC20 is MintableERC20, ERC20Burnable, ERC20Votes {
  constructor(
    string memory _name,
    string memory _symbol,
    uint8 __decimals
  ) MintableERC20(_name, _symbol, __decimals) ERC20Permit(_name) {}

  function decimals() public view virtual override(ERC20, MintableERC20) returns (uint8) {
    return _decimals;
  }

  function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
    super._afterTokenTransfer(from, to, amount);
  }

  function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
    super._mint(to, amount);
  }

  function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
    super._burn(account, amount);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC20} from '@openzeppelin/token/ERC20/ERC20.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';

contract ERC20ForTestnet is IERC20Metadata, ERC20 {
  uint8 internal _decimals;

  constructor(string memory _name, string memory _symbol, uint8 __decimals) ERC20(_name, _symbol) {
    _decimals = __decimals;
  }

  function decimals() public view virtual override(ERC20, IERC20Metadata) returns (uint8 __decimals) {
    return _decimals;
  }

  function mint(uint256 _wad) external {
    _mint(msg.sender, _wad);
  }

  function mint(address _usr, uint256 _wad) external {
    _mint(_usr, _wad);
  }
}

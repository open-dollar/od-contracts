// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC20} from 'isolmate/tokens/ERC20.sol';

contract ERC20ForTest is ERC20 {
  constructor() ERC20('TOKEN', 'TKN', 18) {}

  function mint(uint256 _wad) external {
    _mint(msg.sender, _wad);
  }

  function mint(address _usr, uint256 _wad) external {
    _mint(_usr, _wad);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC20Votes, ERC20Permit, ERC20} from '@openzeppelin/token/ERC20/extensions/ERC20Votes.sol';

contract ERC20VotesForTest is ERC20Votes {
  constructor() ERC20Permit('TOKEN') ERC20('TOKEN', 'TKN') {}

  function mint(uint256 _wad) external {
    _mint(msg.sender, _wad);
  }

  function mint(address _usr, uint256 _wad) external {
    _mint(_usr, _wad);
  }
}

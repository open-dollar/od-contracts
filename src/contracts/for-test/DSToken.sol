// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC20} from 'isolmate/tokens/ERC20.sol';

contract DSToken is ERC20 {
  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol, 18) {}

  function approve(address _guy) public {
    approve(_guy, uint256(int256(-1)));
  }

  function mint(uint256 _wad) external {
    _mint(msg.sender, _wad);
  }

  function mint(address _usr, uint256 _wad) external {
    _mint(_usr, _wad);
  }

  function burn(uint256 _wad) external {
    _burn(msg.sender, _wad);
  }

  function burn(address _usr, uint256 _wad) external {
    _burn(_usr, _wad);
  }

  function push(address _guy, uint256 _wad) external {
    transfer(_guy, _wad);
  }

  function move(address _from, address _to, uint256 _amount) external {
    transferFrom(_from, _to, _amount);
  }

  function setOwner(address) external {}
}

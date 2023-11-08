// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ERC20, IERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';

contract CoinForTest is ERC20, Authorizable {
  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Authorizable(msg.sender) {}

  function mint(uint256 _wad) external isAuthorized {
    _mint(msg.sender, _wad);
  }

  function mint(address _usr, uint256 _wad) external isAuthorized {
    _mint(_usr, _wad);
  }

  function burn(uint256 _wad) external {
    _burn(msg.sender, _wad);
  }

  function burn(address _usr, uint256 _wad) external isAuthorized {
    _burn(_usr, _wad);
  }
}

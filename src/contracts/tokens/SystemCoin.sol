// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC20, IERC20} from '@openzeppelin/token/ERC20/ERC20.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';

contract SystemCoin is ERC20, Authorizable, ISystemCoin {
  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) Authorizable(msg.sender) {}

  function mint(address _dst, uint256 _wad) external isAuthorized {
    _mint(_dst, _wad);
  }

  function burn(uint256 _wad) external {
    _burn(msg.sender, _wad);
  }

  function burn(address _usr, uint256 _wad) external isAuthorized {
    _burn(_usr, _wad);
  }
}

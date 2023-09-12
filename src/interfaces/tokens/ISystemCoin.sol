// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

interface ISystemCoin is IERC20Metadata, IAuthorizable {
  function mint(address _account, uint256 _amount) external;
  function burn(address _account, uint256 _amount) external;
  function burn(uint256 _amount) external;
}

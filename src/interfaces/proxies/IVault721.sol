// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';

interface IVault721 {
  // public variables
  function governor() external returns (address);

  function safeManager() external returns (IODSafeManager);

  function nftRenderer() external returns (NFTRenderer);

  // initializers
  function initializeManager() external;

  function initializeRenderer() external;

  // external
  function getProxy(address _user) external view returns (address);

  function build() external returns (address payable);

  function build(address _user) external returns (address payable);

  // external: only SafeManager
  function mint(address proxy, uint256 safeId) external;

  // external: only Governor
  function updateNftRenderer(
    address _nftRenderer,
    address _oracleRelayer,
    address _taxCollector,
    address _collateralJoinFactory
  ) external;

  function updateContractURI(string memory _metaData) external;

  function setSafeManager(address _safeManager) external;

  function setNftRenderer(address _nftRenderer) external;

  // public
  function tokenURI(uint256 _safeId) external returns (string memory);

  function contractURI() external returns (string memory);
}

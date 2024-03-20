// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';

interface IVault721 {
  error NotGovernor();
  error ProxyAlreadyExist();
  error ZeroAddress();

  // public variables
  function timelockController() external returns (address);
  function safeManager() external returns (IODSafeManager);
  function nftRenderer() external returns (NFTRenderer);
  function blockDelay() external returns (uint8);
  function timeDelay() external returns (uint256);
  function contractMetaData() external returns (string memory);

  // initializers
  function initializeManager() external;
  function initializeRenderer() external;

  // external
  function getProxy(address _user) external view returns (address);
  function getHashState(uint256 _vaultId) external view returns (uint256, uint256, uint256);
  function build() external returns (address payable);
  function build(address _user) external returns (address payable);
  function build(address[] memory _users) external returns (address payable[] memory _proxies);

  // external: only SafeManager
  function mint(address proxy, uint256 safeId) external;
  function updateVaultHashState(uint256 _vaultId) external;

  // external: only Governor
  function updateNftRenderer(
    address _nftRenderer,
    address _oracleRelayer,
    address _taxCollector,
    address _collateralJoinFactory
  ) external;
  function updateContractURI(string memory _metaData) external;
  function setNftRenderer(address _nftRenderer) external;
  function updateWhitelist(address _user, bool _status) external;
  function updateTimeDelay(uint256 _timeDelay) external;
  function updateBlockDelay(uint8 _blockDelay) external;

  // public
  function tokenURI(uint256 _safeId) external returns (string memory);
  function contractURI() external returns (string memory);
}

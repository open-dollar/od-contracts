// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC721} from '@openzeppelin/token/ERC721/ERC721.sol';
import {ISafeManager} from '@interfaces/proxies/ISafeManager.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';

contract Vault721 is ERC721('OpenDollarVault', 'ODV') {
  address public safeManager;
  address public governor;

  mapping(address proxy => address user) internal _proxyRegistry;
  mapping(address user => address proxy) internal _userRegistry;

  event Mint(address _proxy, uint256 _safeId);
  event CreateProxy(address indexed _user, address _proxy);

  /**
   * @dev initializes DAO governor contract
   */
  constructor(address _governor) {
    governor = _governor;
  }

  /**
   * @dev initializes SafeManager contract
   */
  function initialize() external {
    require(safeManager == address(0), 'Vault: already initialized');
    safeManager = msg.sender;
  }

  function getProxy(address _user) external returns (address _proxy) {
    _proxy = _userRegistry[_user];
  }

  /**
   * @dev allows msg.sender without an ODProxy to deploy a new ODProxy
   */
  function build() external returns (address payable _proxy) {
    require(_isNotProxy(msg.sender), 'Vault: proxy already exists');
    _proxy = _build(msg.sender);
  }

  /**
   * @dev allows user without an ODProxy to deploy a new ODProxy
   */
  function build(address _user) external returns (address payable _proxy) {
    require(_isNotProxy(_user), 'Vault: proxy already exists');
    _proxy = _build(_user);
  }

  /**
   * @dev mint can only be called by the SafeManager
   * enforces that only ODProxies call `openSafe` function by checking _proxyRegistry
   */
  function mint(address _proxy, uint256 _safeId) external {
    require(msg.sender == safeManager, 'Vault: Only safeManager.');
    require(_proxyRegistry[_proxy] != address(0), 'Vault: Non-native proxy');
    address _user = _proxyRegistry[_proxy];
    _safeMint(_user, _safeId);
  }

  /**
   * @dev allows DAO to update protocol implementation
   */
  function updateImplementation(address _safeManager) external {
    require(msg.sender == governor, 'Vault: Only governor');
    require(_safeManager != address(0), 'Vault: ZeroAddr');
    safeManager = _safeManager;
  }

  /**
   * @dev check that proxy does not exist OR that the user does not own proxy
   */
  function _isNotProxy(address _user) internal view returns (bool) {
    return _userRegistry[_user] == address(0) || ODProxy(_userRegistry[_user]).OWNER() != _user;
  }

  /**
   * @dev deploys ODProxy for user to interact with protocol
   * updates _proxyRegistry and _userRegistry mappings for new ODProxy
   */
  function _build(address _user) internal returns (address payable _proxy) {
    _proxy = payable(address(new ODProxy(_user)));
    _proxyRegistry[_proxy] = _user;
    _userRegistry[_user] = _proxy;
    emit CreateProxy(_user, address(_proxy));
  }

  /**
   * @dev _transfer calls `transferSAFEOwnership` on SafeManager
   * enforces that ODProxy exists for transfer or it deploys a new ODProxy for receiver of vault/nft
   */
  function _afterTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal override {
    require(to != address(0), 'Vault: No burn');
    if (from != address(0)) {
      address payable proxy;

      if (_isNotProxy(to)) {
        proxy = _build(to);
      } else {
        proxy = payable(_userRegistry[to]);
      }
      ISafeManager(safeManager).transferSAFEOwnership(firstTokenId, address(proxy));
    }
  }
}

// TODO Vars to inlcude and where to find them:
// these vars will be for NFT marketplace to show up-to-date vault info

// Collateral Type
//   contract: HaiSafeManager
//   function: safeData(uint256 _safe)

// Collateral Ratio
//   contract: OracleRelayer
//   function: cParams(bytes32 _cType)

// Stability Fee
//   contract: TaxCollector
//   function: cParams(bytes32 _cType)

// Liquidation Penalty
//   contract: LiquidationEngine
//   function: cParams(bytes32 _cType)

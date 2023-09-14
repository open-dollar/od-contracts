// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC721} from '@openzeppelin/token/ERC721/ERC721.sol';
import {ERC721Enumerable} from '@openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';

contract Vault721 is ERC721Enumerable {
  error NotGovernor();
  error ProxyAlreadyExist();

  address public governor;
  IODSafeManager public safeManager;
  NFTRenderer public nftRenderer;

  string public contractMetaData =
    '{"name": "Open Dollar Vaults","description": "Tradable Vaults for the Open Dollar stablecoin protocol. Caution! Trading this NFT means trading the ownership of your Vault in the Open Dollar protocol and all of the assets/collateral inside each Vault.","image": "opendollar.com/logo.png","external_link": "opendollar.com"}';

  mapping(address proxy => address user) internal _proxyRegistry;
  mapping(address user => address proxy) internal _userRegistry;

  event CreateProxy(address indexed _user, address _proxy);

  /**
   * @dev initializes DAO governor contract
   */
  constructor(address _governor) ERC721('OpenDollar Vault', 'ODV') {
    governor = _governor;
  }

  /**
   * @dev control access for DAO governor
   */
  modifier onlyGovernor() {
    if (msg.sender != governor) revert NotGovernor();
    _;
  }

  /**
   * @dev initializes SafeManager contract
   */
  function initialize() external {
    require(address(safeManager) == address(0), 'Vault: initialized');
    safeManager = IODSafeManager(msg.sender);
  }

  /**
   * @dev get proxy by user address
   */
  function getProxy(address _user) external view returns (address _proxy) {
    _proxy = _userRegistry[_user];
  }

  /**
   * @dev allows msg.sender without an ODProxy to deploy a new ODProxy
   */
  function build() external returns (address payable _proxy) {
    if (!_isNotProxy(msg.sender)) revert ProxyAlreadyExist();
    _proxy = _build(msg.sender);
  }

  /**
   * @dev allows user without an ODProxy to deploy a new ODProxy
   */
  function build(address _user) external returns (address payable _proxy) {
    if (!_isNotProxy(_user)) revert ProxyAlreadyExist();
    _proxy = _build(_user);
  }

  /**
   * @dev mint can only be called by the SafeManager
   * enforces that only ODProxies call `openSafe` function by checking _proxyRegistry
   */
  function mint(address _proxy, uint256 _safeId) external {
    require(msg.sender == address(safeManager), 'Vault: only safeManager');
    require(_proxyRegistry[_proxy] != address(0), 'Vault: non-native proxy');
    address _user = _proxyRegistry[_proxy];
    _safeMint(_user, _safeId);
  }

  /**
   * @dev allows DAO to update protocol implementation of SafeManager
   */
  function setSafeManager(address _safeManager) external onlyGovernor {
    require(_safeManager != address(0), 'Vault: ZeroAddr');
    safeManager = IODSafeManager(_safeManager);
  }

  /**
   * @dev allows DAO to update protocol implementation on NFTRenderer
   */
  function updateNftRenderer(
    address _nftRenderer,
    address _oracleRelayer,
    address _taxCollector,
    address _collateralJoinFactory
  ) external onlyGovernor {
    address _safeManager = address(safeManager);
    require(
      _safeManager != address(0) && _oracleRelayer != address(0) && _taxCollector != address(0)
        && _collateralJoinFactory != address(0),
      'Vault: ZeroAddr'
    );
    setNftRenderer(_nftRenderer);
    nftRenderer.setImplementation(_safeManager, _oracleRelayer, _taxCollector, _collateralJoinFactory);
  }

  /**
   * @dev allows DAO to update protocol implementation of NFTRenderer
   */
  function setNftRenderer(address _nftRenderer) public onlyGovernor {
    require(_nftRenderer != address(0), 'Vault: ZeroAddr');
    nftRenderer = NFTRenderer(_nftRenderer);
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
    require(to != address(0), 'Vault: no burn');
    if (from != address(0)) {
      address payable proxy;

      if (_isNotProxy(to)) {
        proxy = _build(to);
      } else {
        proxy = payable(_userRegistry[to]);
      }
      IODSafeManager(safeManager).transferSAFEOwnership(firstTokenId, address(proxy));
    }
  }

  /**
   * @dev create URI
   */
  function tokenURI(uint256 _safeId) public view override returns (string memory uri) {
    uri = nftRenderer.render(_safeId);
  }

  /**
   * @dev contract level meta data
   */
  function contractURI() public view returns (string memory) {
    return string.concat('data:application/json;utf8,', contractMetaData);
  }

  /**
   * @dev update meta data
   */
  function updateContractURI(string memory _metaData) external onlyGovernor {
    contractMetaData = _metaData;
  }
}

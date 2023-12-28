// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC721Upgradeable, IERC721Upgradeable} from '@openzeppelin-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import {ERC721EnumerableUpgradeable} from
  '@openzeppelin-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';

// Open Dollar
// Version 1.5.8

struct HashState {
  bytes32 lastHash;
  uint256 lastBlockNumber;
  uint256 lastBlockTimestamp;
}

/**
 * @notice Upgradeable contract used as singleton, but is not upgradeable
 */
contract Vault721 is ERC721EnumerableUpgradeable {
  error NotGovernor();
  error NotSafeManager();
  error ProxyAlreadyExist();
  error BlockDelayNotOver();
  error TimeDelayNotOver();
  error ZeroAddress();

  address public timelockController;
  IODSafeManager public safeManager;
  NFTRenderer public nftRenderer;
  uint8 public blockDelay;
  uint256 public timeDelay;

  string public contractMetaData =
    '{"name": "Open Dollar Vaults","description": "Open Dollar is a DeFi lending protocol that enables borrowing against liquid staking tokens while earning staking rewards and enabling liquidity via Non-Fungible Vaults (NFVs).","image": "https://app.opendollar.com/collectionImage.png","external_link": "https://opendollar.com"}';

  mapping(address proxy => address user) internal _proxyRegistry;
  mapping(address user => address proxy) internal _userRegistry;
  mapping(uint256 vaultId => HashState hashState) internal _hashState;
  mapping(address nftExchange => bool whitelisted) internal _allowlist;

  event CreateProxy(address indexed _user, address _proxy);

  /**
   * @dev initializes DAO timelockController contract
   */
  function initialize(address _timelockController) external initializer nonZero(_timelockController) {
    timelockController = _timelockController;
    __ERC721_init('OpenDollar Vault', 'ODV');
  }

  /**
   * @dev control access for DAO timelockController
   */
  modifier onlyGovernance() {
    if (msg.sender != timelockController) revert NotGovernor();
    _;
  }

  /**
   * @dev control access for SafeManager
   */
  modifier onlySafeManager() {
    if (msg.sender != address(safeManager)) revert NotSafeManager();
    _;
  }

  /**
   * @dev enforce non-zero address params
   */
  modifier nonZero(address _addr) {
    if (_addr == address(0)) revert ZeroAddress();
    _;
  }

  /**
   * @dev initializes SafeManager contract
   */
  function initializeManager() external {
    if (address(safeManager) == address(0)) _setSafeManager(msg.sender);
  }

  /**
   * @dev initializes NFTRenderer contract
   */
  function initializeRenderer() external {
    if (address(nftRenderer) == address(0)) _setNftRenderer(msg.sender);
  }

  /**
   * @dev get proxy by user address
   */
  function getProxy(address _user) external view returns (address _proxy) {
    _proxy = _userRegistry[_user];
  }

  /**
   * @dev get hash state by vault id
   */
  function getHashState(uint256 _vaultId) external view returns (HashState memory) {
    return _hashState[_vaultId];
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
  function mint(address _proxy, uint256 _safeId) external onlySafeManager {
    require(_proxyRegistry[_proxy] != address(0), 'V721: non-native proxy');
    address _user = _proxyRegistry[_proxy];
    _safeMint(_user, _safeId);
  }

  function transferFrom(
    address _from,
    address _to,
    uint256 _tokenId
  ) public override(ERC721Upgradeable, IERC721Upgradeable) {
    // on allowlist wallets, we check the block delay along with the state hash
    if (_allowlist[msg.sender]) {
      if (
        block.number < _hashState[_tokenId].lastBlockNumber + blockDelay
          || _hashState[_tokenId].lastHash != nftRenderer.getStateHashBySafeId(_tokenId)
      ) {
        revert BlockDelayNotOver();
      }
      // on non-allowlist wallets, we just check the time delay
    } else {
      if (block.timestamp < _hashState[_tokenId].lastBlockTimestamp + timeDelay) {
        revert TimeDelayNotOver();
      }
    }

    super.transferFrom(_from, _to, _tokenId);
  }

  /**
   * @dev allows DAO to update protocol implementation on NFTRenderer
   */
  function updateNftRenderer(
    address _nftRenderer,
    address _oracleRelayer,
    address _taxCollector,
    address _collateralJoinFactory
  ) external onlyGovernance nonZero(_oracleRelayer) nonZero(_taxCollector) nonZero(_collateralJoinFactory) {
    address _safeManager = address(safeManager);
    require(_safeManager != address(0));
    _setNftRenderer(_nftRenderer);
    nftRenderer.setImplementation(_safeManager, _oracleRelayer, _taxCollector, _collateralJoinFactory);
  }

  /**
   * @dev allows ODSafeManager to update the hash state
   */
  function updateVaultHashState(uint256 _vaultId) external onlySafeManager {
    _hashState[_vaultId] = HashState({
      lastHash: nftRenderer.getStateHashBySafeId(_vaultId),
      lastBlockNumber: block.number,
      lastBlockTimestamp: block.timestamp
    });
  }

  /**
   * @dev allows DAO to update allowlist
   */
  function updateAllowlist(address _user, bool _allowed) external onlyGovernance nonZero(_user) {
    _allowlist[_user] = _allowed;
  }

  /**
   * @dev allows DAO to update the time delay
   */
  function updateTimeDelay(uint256 _timeDelay) external onlyGovernance {
    timeDelay = _timeDelay;
  }

  /**
   * @dev allows DAO to update the block delay
   */
  function updateBlockDelay(uint8 _blockDelay) external onlyGovernance {
    blockDelay = _blockDelay;
  }

  /**
   * @dev update meta data
   */
  function updateContractURI(string memory _metaData) external onlyGovernance {
    contractMetaData = _metaData;
  }

  /**
   * @dev allows DAO to update protocol implementation of SafeManager
   */
  function setSafeManager(address _safeManager) external onlyGovernance {
    _setSafeManager(_safeManager);
  }

  /**
   * @dev allows DAO to update protocol implementation of NFTRenderer
   */
  function setNftRenderer(address _nftRenderer) external onlyGovernance {
    _setNftRenderer(_nftRenderer);
  }

  /**
   * @dev generate URI with updated vault information
   */
  function tokenURI(uint256 _safeId) public view override returns (string memory uri) {
    _requireMinted(_safeId);
    uri = nftRenderer.render(_safeId);
  }

  /**
   * @dev contract level meta data
   */
  function contractURI() public view returns (string memory uri) {
    uri = string.concat('data:application/json;utf8,', contractMetaData);
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
   * @dev allows DAO to update protocol implementation of SafeManager
   */
  function _setSafeManager(address _safeManager) internal nonZero(_safeManager) {
    safeManager = IODSafeManager(_safeManager);
  }

  /**
   * @dev allows DAO to update protocol implementation of NFTRenderer
   */
  function _setNftRenderer(address _nftRenderer) internal nonZero(_nftRenderer) {
    nftRenderer = NFTRenderer(_nftRenderer);
  }

  /**
   * @dev _transfer calls `transferSAFEOwnership` on SafeManager
   * enforces that ODProxy exists for transfer or it deploys a new ODProxy for receiver of vault/nft
   */
  function _afterTokenTransfer(address _from, address _to, uint256 _tokenId, uint256) internal override {
    require(_to != address(0), 'V721: no burn');
    if (_from != address(0)) {
      address payable proxy;

      if (_isNotProxy(_to)) {
        proxy = _build(_to);
      } else {
        proxy = payable(_userRegistry[_to]);
      }
      IODSafeManager(safeManager).transferSAFEOwnership(_tokenId, address(proxy));
    }
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ERC721Upgradeable, IERC721Upgradeable} from '@openzeppelin-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import {ERC721EnumerableUpgradeable} from
  '@openzeppelin-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {Modifiable} from '@contracts/utils/Modifiable.sol';
import {Authorizable} from '@contracts/utils/Authorizable.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {Encoding} from '@libraries/Encoding.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

// Open Dollar
// Version 1.7.0

/**
 * @notice Upgradeable contract used as singleton, but is not upgradeable
 */
contract Vault721 is ERC721EnumerableUpgradeable, Authorizable, Modifiable, IVault721 {
  using Assertions for address;
  using Encoding for bytes;

  address public timelockController;
  IODSafeManager public safeManager;
  NFTRenderer public nftRenderer;
  uint256 public blockDelay;
  uint256 public timeDelay;

  string public contractMetaData =
    '{"name": "Open Dollar Vaults","description": "Open Dollar is a stablecoin protocol built on Arbitrum designed to help you earn yield and leverage your assets with safety and predictability.","image": "https://app.opendollar.com/collectionImage.png","external_link": "https://app.opendollar.com"}';

  mapping(address proxy => address user) internal _proxyRegistry;
  mapping(address user => address proxy) internal _userRegistry;
  mapping(uint256 vaultId => NFVState nfvState) internal _nfvState;
  mapping(address nftExchange => bool whitelisted) internal _allowlist;

  constructor() Authorizable(msg.sender) {}

  function initialize(
    address _timelockController,
    uint256 _blockDelay,
    uint256 _timeDelay
  ) external initializer nonZero(_timelockController) {
    timelockController = _timelockController;
    if (!_isAuthorized(timelockController)) _addAuthorization(timelockController);
    __ERC721_init('OpenDollar Vault', 'ODV');
    blockDelay = _blockDelay;
    timeDelay = _timeDelay;
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

  /// @inheritdoc IVault721
  function initializeManager() external {
    if (address(safeManager) == address(0)) safeManager = IODSafeManager(msg.sender);
  }

  /// @inheritdoc IVault721
  function initializeRenderer() external {
    if (address(nftRenderer) == address(0)) nftRenderer = NFTRenderer(msg.sender);
  }

  /// @inheritdoc IVault721
  function getProxy(address _user) external view returns (address _proxy) {
    _proxy = _userRegistry[_user];
  }

  /// @inheritdoc IVault721
  function getNfvState(uint256 _vaultId) external view returns (NFVState memory) {
    return _nfvState[_vaultId];
  }

  /// @inheritdoc IVault721
  function getIsAllowlisted(address _user) external view returns (bool) {
    return _allowlist[_user];
  }

  /// @inheritdoc IVault721
  function build() external returns (address payable _proxy) {
    if (!_shouldBuildProxy(msg.sender)) revert ProxyAlreadyExist();
    _proxy = _build(msg.sender);
  }

  /// @inheritdoc IVault721
  function build(address _user) external returns (address payable _proxy) {
    if (!_shouldBuildProxy(_user)) revert ProxyAlreadyExist();
    _proxy = _build(_user);
  }

  /// @inheritdoc IVault721
  function build(address[] memory _users) external returns (address payable[] memory _proxies) {
    uint256 len = _users.length;
    _proxies = new address payable[](len);
    for (uint256 i = 0; i < len; i++) {
      if (!_shouldBuildProxy(_users[i])) revert ProxyAlreadyExist();
      _proxies[i] = _build(_users[i]);
    }
  }

  /// @inheritdoc IVault721
  function mint(address _proxy, uint256 _safeId) external onlySafeManager {
    require(_proxyRegistry[_proxy] != address(0), 'V721: non-native proxy');
    address _user = _proxyRegistry[_proxy];
    _safeMint(_user, _safeId);
  }

  /// @inheritdoc IVault721
  function updateNfvState(uint256 _vaultId) external onlySafeManager {
    (bytes32 _cType, uint256 _collateral, uint256 _debt, address _safeHandler) = _getNfvValue(_vaultId);

    _nfvState[_vaultId] = NFVState({
      cType: _cType,
      collateral: _collateral,
      debt: _debt,
      lastBlockNumber: block.number,
      lastBlockTimestamp: block.timestamp,
      safeHandler: _safeHandler
    });

    emit NFVStateUpdated(_vaultId);
  }

  /**
   * @dev allows DAO to update allowlist
   */
  function _updateAllowlist(address _user, bool _allowed) internal nonZero(_user) {
    _allowlist[_user] = _allowed;
  }

  /**
   * @dev generate URI with updated vault information
   */
  /// @inheritdoc ERC721Upgradeable
  function tokenURI(uint256 _safeId) public view override returns (string memory uri) {
    _requireMinted(_safeId);
    uri = nftRenderer.render(_safeId);
  }

  /// @inheritdoc IVault721
  function contractURI() public view returns (string memory uri) {
    uri = string.concat('data:application/json;utf8,', contractMetaData);
  }

  /**
   * @dev check that proxy does not exist OR that the user does not own proxy
   */
  function _shouldBuildProxy(address _user) internal view returns (bool) {
    return _userRegistry[_user] == address(0) || ODProxy(_userRegistry[_user]).OWNER() != _user;
  }

  /**
   * @dev deploys ODProxy for user to interact with protocol
   * updates _proxyRegistry and _userRegistry mappings for new ODProxy
   */
  function _build(address _user) internal virtual returns (address payable _proxy) {
    if (_proxyRegistry[_user] != address(0)) revert NotWallet();
    _proxy = payable(address(new ODProxy(_user)));
    _proxyRegistry[_proxy] = _user;
    _userRegistry[_user] = _proxy;
    emit CreateProxy(_user, address(_proxy));
  }

  /**
   * @dev get generated debt and locked collateral of nfv by tokenId
   */
  function _getNfvValue(uint256 _vaultId) internal view returns (bytes32, uint256, uint256, address) {
    IODSafeManager.SAFEData memory safeMangerData = safeManager.safeData(_vaultId);
    address safeHandler = safeMangerData.safeHandler;
    if (safeHandler == address(0)) revert ZeroAddress();
    bytes32 cType = safeMangerData.collateralType;
    ISAFEEngine.SAFE memory SafeEngineData = ISAFEEngine(safeManager.safeEngine()).safes(cType, safeHandler);
    return (cType, SafeEngineData.lockedCollateral, SafeEngineData.generatedDebt, safeHandler);
  }

  /**
   * @dev prevent undesirable frontrun state change during token transferFrom
   * @notice frontrunning that increases the lockedCollateral or decreases the generatedDebt is accepted
   */
  function _enforceStaticState(address _operator, uint256 _tokenId) internal view {
    (, uint256 _collateralNow, uint256 _debtNow,) = _getNfvValue(_tokenId);
    NFVState memory _nfv = _nfvState[_tokenId];

    if (_collateralNow < _nfv.collateral || _debtNow > _nfv.debt) revert StateViolation();

    if (_allowlist[_operator]) {
      if (block.number < _nfv.lastBlockNumber + blockDelay) revert BlockDelayNotOver();
    } else {
      if (block.timestamp < _nfv.lastBlockTimestamp + timeDelay) revert TimeDelayNotOver();
    }
  }

  /**
   * @dev allows DAO to update protocol implementation on NFTRenderer
   */
  function _updateNftRenderer(
    address _nftRenderer,
    address _oracleRelayer,
    address _taxCollector,
    address _collateralJoinFactory
  ) internal {
    address _safeManager = address(safeManager);
    _safeManager.assertNonNull();
    nftRenderer = NFTRenderer(_nftRenderer);
    nftRenderer.setImplementation(_safeManager, _oracleRelayer, _taxCollector, _collateralJoinFactory);
  }

  /**
   * @dev allows DAO to update protocol implementation of SafeManager
   *
   * WARNING: SafeManager should not be updated unless the new SafeManager
   * is capable of correctly persisting the proper safeId as it relates to the
   * current tokenId. Additional considerations regarding data migration of
   * core contracts should be addressed.
   */
  /// @inheritdoc Modifiable
  function _modifyParameters(bytes32 _param, bytes memory _data) internal override {
    address _address = _data.toAddress();

    if (_param == 'safeManager') {
      safeManager = IODSafeManager(_address.assertNonNull());
    } else if (_param == 'timelockController') {
      address oldController = timelockController;
      _addAuthorization(_address.assertNonNull());
      timelockController = _address;
      _removeAuthorization(oldController);
    } else if (_param == 'nftRenderer') {
      nftRenderer = NFTRenderer(_address.assertNonNull());
    } else if (_param == 'blockDelay') {
      blockDelay = _data.toUint256();
    } else if (_param == 'timeDelay') {
      timeDelay = _data.toUint256();
    } else if (_param == 'updateNFTRenderer') {
      (address _nftRenderer, address _oracleRelayer, address _taxCollector, address _collateralJoinFactory) =
        abi.decode(_data, (address, address, address, address));
      _updateNftRenderer(
        _nftRenderer.assertNonNull(),
        _oracleRelayer.assertNonNull(),
        _taxCollector.assertNonNull(),
        _collateralJoinFactory.assertNonNull()
      );
    } else if (_param == 'updateAllowlist') {
      (address _user, bool _bool) = abi.decode(_data, (address, bool));
      _user.assertNonNull();
      _updateAllowlist(_user, _bool);
    } else if (_param == 'contractURI') {
      contractMetaData = abi.decode(_data, (string));
    } else {
      revert UnrecognizedParam();
    }
  }

  /**
   * @dev enforce state before _transfer
   */
  function _transfer(address _from, address _to, uint256 _tokenId) internal override {
    _enforceStaticState(msg.sender, _tokenId);
    super._transfer(_from, _to, _tokenId);
  }

  /**
   * @dev _transfer calls `transferSAFEOwnership` on SafeManager
   * @notice check that NFV receiver has proxy or build
   */
  function _afterTokenTransfer(address _from, address _to, uint256 _tokenId, uint256) internal override {
    require(_to != address(0), 'V721: no burn');
    if (_from != address(0)) {
      address payable proxy;

      if (_shouldBuildProxy(_to)) {
        proxy = _build(_to);
      } else {
        proxy = payable(_userRegistry[_to]);
      }
      IODSafeManager(safeManager).transferSAFEOwnership(_tokenId, address(proxy));
    }
  }
}

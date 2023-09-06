// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC721} from '@openzeppelin/token/ERC721/ERC721.sol';
import {ERC721Enumerable} from '@openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol';
import {ISafeManager} from '@interfaces/proxies/ISafeManager.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {ITaxCollector} from '@interfaces/ITaxCollector.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {NFTRenderer} from '@libraries/NFTRenderer.sol';

contract Vault721 is ERC721, ERC721Enumerable {
  address public governor;
  ISafeManager public safeManager;
  ISAFEEngine public safeEngine;
  IOracleRelayer public oracleRelayer;
  ITaxCollector public taxCollector;

  mapping(address proxy => address user) internal _proxyRegistry;
  mapping(address user => address proxy) internal _userRegistry;

  event CreateProxy(address indexed _user, address _proxy);

  /**
   * @dev initializes DAO governor contract
   */
  constructor(
    address _governor,
    IOracleRelayer _oracleRelayer,
    ITaxCollector _taxCollector
  ) ERC721('OpenDollar Vault', 'ODV') {
    governor = _governor;
    oracleRelayer = _oracleRelayer;
    taxCollector = _taxCollector;
  }

  /**
   * @dev initializes SafeManager contract
   */
  function initialize() external {
    require(address(safeManager) == address(0), 'Vault: already initialized');
    safeManager = ISafeManager(msg.sender);
    safeEngine = ISAFEEngine(safeManager.safeEngine());
  }

  function getProxy(address _user) external view returns (address _proxy) {
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
    require(msg.sender == address(safeManager), 'Vault: Only safeManager.');
    require(_proxyRegistry[_proxy] != address(0), 'Vault: Non-native proxy');
    address _user = _proxyRegistry[_proxy];
    _safeMint(_user, _safeId);
  }

  /**
   * @dev allows DAO to update protocol implementation
   */
  function updateImplementation(address _safeManager, address _oracleRelayer, address _taxCollector) external {
    require(msg.sender == governor, 'Vault: Only governor');
    require(
      _safeManager != address(0) && _oracleRelayer != address(0) && _taxCollector != address(0), 'Vault: ZeroAddr'
    );
    safeManager = ISafeManager(_safeManager);
    safeEngine = ISAFEEngine(safeManager.safeEngine());
    oracleRelayer = IOracleRelayer(_oracleRelayer);
    taxCollector = ITaxCollector(_taxCollector);
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

  /**
   * @dev
   * The following functions are overrides required by Solidity.
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId,
    uint256 batchSize
  ) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId, batchSize);
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
    return super.supportsInterface(interfaceId);
  }

  /**
   * @dev
   */
  function tokenURI(uint256 _safeId) public view override returns (string memory uri) {
    (bytes32 cType, address safeHandler) = _getCType(_safeId);
    (uint256 lockedCollat, uint256 genDebt) = _getLockedCollatAndGenDebt(cType, safeHandler);
    uint256 safetyCRatio = _getCTypeRatio(cType);
    uint256 stabilityFee = _getStabilityFee(cType);

    NFTRenderer.VaultParams memory params = NFTRenderer.VaultParams({
      cType: cType,
      handler: safeHandler,
      tokenId: _safeId,
      collat: lockedCollat,
      debt: genDebt,
      ratio: safetyCRatio,
      fee: stabilityFee
    });

    uri = NFTRenderer.render(params);
  }

  /**
   * @dev getter functions to render SVG image
   */
  function _getCType(uint256 _safeId) public view returns (bytes32 cType, address safeHandler) {
    ISafeManager.SAFEData memory sData = ISafeManager(safeManager).safeData(_safeId);
    cType = sData.collateralType;
    safeHandler = sData.safeHandler;
  }

  function _getLockedCollatAndGenDebt(
    bytes32 _cType,
    address _safeHandler
  ) public view returns (uint256 lockedCollat, uint256 genDebt) {
    ISAFEEngine.SAFE memory sData = safeEngine.safes(_cType, _safeHandler);
    lockedCollat = sData.lockedCollateral;
    genDebt = sData.generatedDebt;
  }

  function _getCTypeRatio(bytes32 _cType) public view returns (uint256 safetyCRatio) {
    IOracleRelayer.OracleRelayerCollateralParams memory cParams = oracleRelayer.cParams(_cType);
    safetyCRatio = cParams.safetyCRatio;
  }

  function _getStabilityFee(bytes32 _cType) public view returns (uint256 stabilityFee) {
    ITaxCollector.TaxCollectorCollateralParams memory cParams = taxCollector.cParams(_cType);
    stabilityFee = cParams.stabilityFee;
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC721} from '@openzeppelin/token/ERC721/ERC721.sol';
import {ERC721Enumerable} from '@openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol';
import {ISafeManager} from '@interfaces/proxies/ISafeManager.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {ITaxCollector} from '@interfaces/ITaxCollector.sol';
import {ICollateralJoinFactory} from '@interfaces/factories/ICollateralJoinFactory.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {NFTRenderer2} from '@libraries/NFTRenderer2.sol';

contract Vault721 is ERC721Enumerable {
  address public governor;
  ISafeManager public safeManager;
  ISAFEEngine public safeEngine;
  IOracleRelayer public oracleRelayer;
  ITaxCollector public taxCollector;
  ICollateralJoinFactory public collateralJoinFactory;

  string public contractMetaData = "{'name': 'Open Dollar Vaults','description': 'Tradable Vaults for the Open Dollar stablecoin protocol. Caution! Trading this NFT means trading the ownership of your Vault in the Open Dollar protocol and all of the assets/collateral inside each Vault.','image': 'opendollar.com/logo.png','external_link': 'opendollar.com'}";

  mapping(address proxy => address user) internal _proxyRegistry;
  mapping(address user => address proxy) internal _userRegistry;

  event CreateProxy(address indexed _user, address _proxy);

  /**
   * @dev initializes DAO governor contract
   */
  constructor(
    address _governor,
    IOracleRelayer _oracleRelayer,
    ITaxCollector _taxCollector,
    ICollateralJoinFactory _collateralJoinFactory
  ) ERC721('OpenDollar Vault', 'ODV') {
    governor = _governor;
    oracleRelayer = _oracleRelayer;
    taxCollector = _taxCollector;
    collateralJoinFactory = _collateralJoinFactory;
  }

  /**
   * @dev initializes SafeManager contract
   */
  function initialize(address _safeEngine) external {
    require(address(safeManager) == address(0), 'Vault: already initialized');
    safeManager = ISafeManager(msg.sender);
    safeEngine = ISAFEEngine(_safeEngine);
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
  function updateImplementation(
    address _safeManager,
    address _oracleRelayer,
    address _taxCollector,
    address _collateralJoinFactory
  ) external {
    require(msg.sender == governor, 'Vault: Only governor');
    require(
      _safeManager != address(0) && _oracleRelayer != address(0) && _taxCollector != address(0)
        && _collateralJoinFactory != address(0),
      'Vault: ZeroAddr'
    );
    safeManager = ISafeManager(_safeManager);
    safeEngine = ISAFEEngine(safeManager.safeEngine());
    oracleRelayer = IOracleRelayer(_oracleRelayer);
    taxCollector = ITaxCollector(_taxCollector);
    collateralJoinFactory = ICollateralJoinFactory(_collateralJoinFactory);
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
   */
  function tokenURI(uint256 _safeId) public view override returns (string memory uri) {
    (bytes32 cType, address safeHandler) = _getCType(_safeId);
    (uint256 lockedCollat, uint256 genDebt) = _getLockedCollatAndGenDebt(cType, safeHandler);
    uint256 safetyCRatio = _getCTypeRatio(cType);
    uint256 stabilityFee = _getStabilityFee(cType);
    string memory symbol = _getTokenSymbol(cType);

    NFTRenderer2.VaultParams memory params = NFTRenderer2.VaultParams({
      tokenId: _safeId,
      collat: lockedCollat,
      debt: genDebt,
      ratio: safetyCRatio,
      fee: stabilityFee,
      symbol: symbol
    });

    uri = NFTRenderer2.render(params);
  }

  /**
   * @dev getter functions to render SVG image
   */
  function _getCType(uint256 _safeId) internal view returns (bytes32 cType, address safeHandler) {
    ISafeManager.SAFEData memory sData = ISafeManager(safeManager).safeData(_safeId);
    cType = sData.collateralType;
    safeHandler = sData.safeHandler;
  }

  function _getLockedCollatAndGenDebt(
    bytes32 _cType,
    address _safeHandler
  ) internal view returns (uint256 lockedCollat, uint256 genDebt) {
    ISAFEEngine.SAFE memory sData = safeEngine.safes(_cType, _safeHandler);
    lockedCollat = sData.lockedCollateral;
    genDebt = sData.generatedDebt;
  }

  function _getCTypeRatio(bytes32 _cType) internal view returns (uint256 safetyCRatio) {
    IOracleRelayer.OracleRelayerCollateralParams memory cParams = oracleRelayer.cParams(_cType);
    safetyCRatio = cParams.safetyCRatio;
  }

  function _getStabilityFee(bytes32 _cType) internal view returns (uint256 stabilityFee) {
    ITaxCollector.TaxCollectorCollateralParams memory cParams = taxCollector.cParams(_cType);
    stabilityFee = cParams.stabilityFee;
  }

  function _getTokenSymbol(bytes32 cType) internal view returns (string memory tokenSymbol) {
    address collateralJoin = collateralJoinFactory.collateralJoins(cType);
    IERC20Metadata token = ICollateralJoin(collateralJoin).collateral();
    tokenSymbol = token.symbol();
  }

  //Contract level meta data
  function contractURI() public view returns (string memory) {
    return string.concat("data:application/json;utf8,", contractMetaData);
  }

  function updateContractURI(string memory _metaData) external{
    require(msg.sender == governor, "Only the DAO can update this.");
    contractMetaData = _metaData;
  }
}

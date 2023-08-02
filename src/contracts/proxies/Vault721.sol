// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {ERC721} from '@openzeppelin/token/ERC721/ERC721.sol';
import {Ownable} from '@contracts/utils/Ownable.sol';

// TODO move to interfaces
interface ISafeManager {
  function openSAFE(bytes32 _cType, address _usr) external returns (uint256 _id);
  function transferSAFEOwnership(uint256 _safe, address _dst) external;
}

contract ODProxy is Ownable {
  error TargetAddressRequired();
  error TargetCallFailed(bytes _response);

  constructor(address _owner) Ownable(_owner) {}

  function execute(address _target, bytes memory _data) external payable onlyOwner returns (bytes memory _response) {
    if (_target == address(0)) revert TargetAddressRequired();

    bool _succeeded;
    (_succeeded, _response) = _target.delegatecall(_data);

    if (!_succeeded) {
      revert TargetCallFailed(_response);
    }
  }
}

contract Vault721 is ERC721('OpenDollarVault', 'ODV') {
  address public safeManager;
  address public governor;

  mapping(address proxy => address user) private _proxyRegistry;
  mapping(address user => address proxy) private _userRegistry;

  event Mint(address proxy, uint256 safeId);
  event CreateProxy(address indexed owner, address proxy);

  constructor(address _safeManager, address _governor) {
    safeManager = _safeManager;
    governor = _governor;
  }

  function build() external returns (address payable _proxy) {
    require(!_checkUserProxy(msg.sender), 'Vault721: User proxy already exists.');
    _proxy = _build(msg.sender);
  }

  /**
   * @dev mint can only be called by the SafeManager
   * enforces that only ODProxies call `openSafe` function by checking _proxyRegistry
   */
  function mint(address proxy, uint256 safeId) external {
    require(msg.sender == safeManager, 'Vault721: Only safeManager.');
    require(_proxyRegistry[proxy] != address(0), 'Vault721: Non-native proxy call.');
    address user = _proxyRegistry[proxy];
    _safeMint(user, safeId);
  }

  function updateImplementation(address _safeManager) external {
    require(msg.sender == governor, 'Vault721: Only governor.');
    safeManager = _safeManager;
  }

  function _checkUserProxy(address user) internal view returns (bool) {
    return _userRegistry[user] == address(0) || ODProxy(_userRegistry[user]).owner() != user;
  }

  function _build(address _owner) internal returns (address payable _proxy) {
    _proxy = payable(address(new ODProxy(address(this))));
    _userRegistry[_owner] = _proxy;
    emit CreateProxy(_owner, address(_proxy));
  }

  /**
   * @dev transfer calls `transferSAFEOwnership` on SafeManager
   * enforces that ODProxy exists for transfer or it deploys a new ODProxy for receiver of vault/nft
   */
  function _afterTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal override {
    address payable proxy;

    if (_checkUserProxy(to)) {
      proxy = _build(to);
    } else {
      proxy = payable(_userRegistry[to]);
    }
    ISafeManager(safeManager).transferSAFEOwnership(firstTokenId, address(proxy));
  }
}

// Vars to inlcude in NFT

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

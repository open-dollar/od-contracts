// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {SAFEHandler} from '@contracts/proxies/SAFEHandler.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {ILiquidationEngine} from '@interfaces/ILiquidationEngine.sol';

import {Math} from '@libraries/Math.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {Assertions} from '@libraries/Assertions.sol';

import {IHaiSafeManager} from '@interfaces/proxies/IHaiSafeManager.sol';

/**
 * @title  HaiSafeManager
 * @notice This contract acts as interface to the SAFEEngine, facilitating the management of SAFEs
 * @dev    This contract is meant to be used by users that interact with the protocol through a proxy contract
 */
contract HaiSafeManager is IHaiSafeManager {
  using Math for uint256;
  using EnumerableSet for EnumerableSet.UintSet;
  using Assertions for address;

  // --- Registry ---

  /// @inheritdoc IHaiSafeManager
  address public safeEngine;

  // --- Data ---

  /// @notice Nonce used to generate safe ids (autoincremental)
  uint256 internal _safeId;
  /// @notice Mapping of user addresses to their enumerable set of safes
  mapping(address _safeOwner => EnumerableSet.UintSet) internal _usrSafes;
  /// @notice Mapping of user addresses to their enumerable set of safes per collateral type
  mapping(address _safeOwner => mapping(bytes32 _cType => EnumerableSet.UintSet)) internal _usrSafesPerCollat;
  /// @notice Mapping of safe ids to their data
  mapping(uint256 _safeId => SAFEData) internal _safeData;

  /// @inheritdoc IHaiSafeManager
  mapping(address _owner => mapping(uint256 _safeId => mapping(address _caller => bool _ok))) public safeCan;
  /// @inheritdoc IHaiSafeManager
  mapping(address _safeHandler => mapping(address _caller => bool _ok)) public handlerCan;

  // --- Modifiers ---

  /**
   * @notice Checks if the sender is the owner of the safe or the safe has permissions to call the function
   * @param  _safe Id of the safe to check if msg.sender has permissions for
   */
  modifier safeAllowed(uint256 _safe) {
    address _owner = _safeData[_safe].owner;
    if (msg.sender != _owner && !safeCan[_owner][_safe][msg.sender]) revert SafeNotAllowed();
    _;
  }

  /**
   * @notice Checks if the sender is the safe handler has permissions to call the function
   * @param  _handler Address of the handler to check if msg.sender has permissions for
   */
  modifier handlerAllowed(address _handler) {
    if (msg.sender != _handler && !handlerCan[_handler][msg.sender]) revert HandlerNotAllowed();
    _;
  }

  // --- Init ---

  /**
   * @param  _safeEngine Address of the SAFEEngine
   */
  constructor(address _safeEngine) {
    safeEngine = _safeEngine.assertNonNull();
  }

  // --- Getters ---

  /// @inheritdoc IHaiSafeManager
  function getSafes(address _usr) external view returns (uint256[] memory _safes) {
    _safes = _usrSafes[_usr].values();
  }

  /// @inheritdoc IHaiSafeManager
  function getSafes(address _usr, bytes32 _cType) external view returns (uint256[] memory _safes) {
    _safes = _usrSafesPerCollat[_usr][_cType].values();
  }

  /// @inheritdoc IHaiSafeManager
  function getSafesData(address _usr)
    external
    view
    returns (uint256[] memory _safes, address[] memory _safeHandlers, bytes32[] memory _cTypes)
  {
    _safes = _usrSafes[_usr].values();
    _safeHandlers = new address[](_safes.length);
    _cTypes = new bytes32[](_safes.length);
    for (uint256 _i; _i < _safes.length; _i++) {
      _safeHandlers[_i] = _safeData[_safes[_i]].safeHandler;
      _cTypes[_i] = _safeData[_safes[_i]].collateralType;
    }
  }

  /// @inheritdoc IHaiSafeManager
  function safeData(uint256 _safe) external view returns (SAFEData memory _sData) {
    _sData = _safeData[_safe];
  }

  // --- Methods ---

  /// @inheritdoc IHaiSafeManager
  function allowSAFE(uint256 _safe, address _usr, bool _ok) external safeAllowed(_safe) {
    address _owner = _safeData[_safe].owner;
    safeCan[_owner][_safe][_usr] = _ok;
    emit AllowSAFE(msg.sender, _safe, _usr, _ok);
  }

  /// @inheritdoc IHaiSafeManager
  function allowHandler(address _usr, bool _ok) external {
    handlerCan[msg.sender][_usr] = _ok;
    emit AllowHandler(msg.sender, _usr, _ok);
  }

  /// @inheritdoc IHaiSafeManager
  function openSAFE(bytes32 _cType, address _usr) external returns (uint256 _id) {
    if (_usr == address(0)) revert ZeroAddress();

    ++_safeId;
    address _safeHandler = address(new SAFEHandler(safeEngine));

    _safeData[_safeId] =
      SAFEData({owner: _usr, pendingOwner: address(0), safeHandler: _safeHandler, collateralType: _cType});

    _usrSafes[_usr].add(_safeId);
    _usrSafesPerCollat[_usr][_cType].add(_safeId);

    emit OpenSAFE(msg.sender, _usr, _safeId);
    return _safeId;
  }

  /// @inheritdoc IHaiSafeManager
  function transferSAFEOwnership(uint256 _safe, address _dst) external safeAllowed(_safe) {
    SAFEData memory _sData = _safeData[_safe];
    if (_dst == _sData.owner) revert AlreadySafeOwner();

    _safeData[_safe].pendingOwner = _dst;
    emit InitiateTransferSAFEOwnership(msg.sender, _safe, _dst);
  }

  /// @inheritdoc IHaiSafeManager
  function acceptSAFEOwnership(uint256 _safe) external {
    SAFEData memory _sData = _safeData[_safe];
    address _newOwner = _sData.pendingOwner;
    address _prevOwner = _sData.owner;

    if (msg.sender != _newOwner) revert SafeNotAllowed();

    _usrSafes[_prevOwner].remove(_safe);
    _usrSafesPerCollat[_prevOwner][_sData.collateralType].remove(_safe);

    _usrSafes[_newOwner].add(_safe);
    _usrSafesPerCollat[_newOwner][_sData.collateralType].add(_safe);

    _safeData[_safe].owner = _newOwner;
    _safeData[_safe].pendingOwner = address(0);

    emit TransferSAFEOwnership(_prevOwner, _safe, _newOwner);
  }

  /// @inheritdoc IHaiSafeManager
  function modifySAFECollateralization(
    uint256 _safe,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) external safeAllowed(_safe) {
    SAFEData memory _sData = _safeData[_safe];
    ISAFEEngine(safeEngine).modifySAFECollateralization(
      _sData.collateralType, _sData.safeHandler, _sData.safeHandler, _sData.safeHandler, _deltaCollateral, _deltaDebt
    );
    emit ModifySAFECollateralization(msg.sender, _safe, _deltaCollateral, _deltaDebt);
  }

  /// @inheritdoc IHaiSafeManager
  function transferCollateral(uint256 _safe, address _dst, uint256 _wad) external safeAllowed(_safe) {
    SAFEData memory _sData = _safeData[_safe];
    ISAFEEngine(safeEngine).transferCollateral(_sData.collateralType, _sData.safeHandler, _dst, _wad);
    emit TransferCollateral(msg.sender, _safe, _dst, _wad);
  }

  /// @inheritdoc IHaiSafeManager
  function transferCollateral(bytes32 _cType, uint256 _safe, address _dst, uint256 _wad) external safeAllowed(_safe) {
    SAFEData memory _sData = _safeData[_safe];
    ISAFEEngine(safeEngine).transferCollateral(_cType, _sData.safeHandler, _dst, _wad);
    emit TransferCollateral(msg.sender, _cType, _safe, _dst, _wad);
  }

  /// @inheritdoc IHaiSafeManager
  function transferInternalCoins(uint256 _safe, address _dst, uint256 _rad) external safeAllowed(_safe) {
    SAFEData memory _sData = _safeData[_safe];
    ISAFEEngine(safeEngine).transferInternalCoins(_sData.safeHandler, _dst, _rad);
    emit TransferInternalCoins(msg.sender, _safe, _dst, _rad);
  }

  /// @inheritdoc IHaiSafeManager
  function quitSystem(uint256 _safe, address _dst) external safeAllowed(_safe) handlerAllowed(_dst) {
    SAFEData memory _sData = _safeData[_safe];
    ISAFEEngine.SAFE memory _safeInfo = ISAFEEngine(safeEngine).safes(_sData.collateralType, _sData.safeHandler);
    int256 _deltaCollateral = _safeInfo.lockedCollateral.toInt();
    int256 _deltaDebt = _safeInfo.generatedDebt.toInt();
    ISAFEEngine(safeEngine).transferSAFECollateralAndDebt(
      _sData.collateralType, _sData.safeHandler, _dst, _deltaCollateral, _deltaDebt
    );

    // Remove safe from owner's list (notice it doesn't erase safe ownership)
    _usrSafes[_sData.owner].remove(_safe);
    _usrSafesPerCollat[_sData.owner][_sData.collateralType].remove(_safe);
    emit QuitSystem(msg.sender, _safe, _dst);
  }

  /// @inheritdoc IHaiSafeManager
  function enterSystem(address _src, uint256 _safe) external handlerAllowed(_src) safeAllowed(_safe) {
    SAFEData memory _sData = _safeData[_safe];
    ISAFEEngine.SAFE memory _safeInfo = ISAFEEngine(safeEngine).safes(_sData.collateralType, _sData.safeHandler);
    int256 _deltaCollateral = _safeInfo.lockedCollateral.toInt();
    int256 _deltaDebt = _safeInfo.generatedDebt.toInt();
    ISAFEEngine(safeEngine).transferSAFECollateralAndDebt(
      _sData.collateralType, _src, _sData.safeHandler, _deltaCollateral, _deltaDebt
    );
    emit EnterSystem(msg.sender, _src, _safe);
  }

  /// @inheritdoc IHaiSafeManager
  function moveSAFE(uint256 _safeSrc, uint256 _safeDst) external safeAllowed(_safeSrc) safeAllowed(_safeDst) {
    SAFEData memory _srcData = _safeData[_safeSrc];
    SAFEData memory _dstData = _safeData[_safeDst];
    if (_srcData.collateralType != _dstData.collateralType) revert CollateralTypesMismatch();
    ISAFEEngine.SAFE memory _safeInfo = ISAFEEngine(safeEngine).safes(_srcData.collateralType, _srcData.safeHandler);
    int256 _deltaCollateral = _safeInfo.lockedCollateral.toInt();
    int256 _deltaDebt = _safeInfo.generatedDebt.toInt();
    ISAFEEngine(safeEngine).transferSAFECollateralAndDebt(
      _srcData.collateralType, _srcData.safeHandler, _dstData.safeHandler, _deltaCollateral, _deltaDebt
    );

    // Remove safe from owner's list (notice it doesn't erase safe ownership)
    _usrSafes[_srcData.owner].remove(_safeSrc);
    _usrSafesPerCollat[_srcData.owner][_srcData.collateralType].remove(_safeSrc);
    emit MoveSAFE(msg.sender, _safeSrc, _safeDst);
  }

  /// @inheritdoc IHaiSafeManager
  function addSAFE(uint256 _safe) external {
    SAFEData memory _sData = _safeData[_safe];
    _usrSafes[msg.sender].add(_safe);
    _usrSafesPerCollat[msg.sender][_sData.collateralType].add(_safe);
  }

  /// @inheritdoc IHaiSafeManager
  function removeSAFE(uint256 _safe) external safeAllowed(_safe) {
    SAFEData memory _sData = _safeData[_safe];
    _usrSafes[_sData.owner].remove(_safe);
    _usrSafesPerCollat[_sData.owner][_sData.collateralType].remove(_safe);
  }

  /// @inheritdoc IHaiSafeManager
  function protectSAFE(uint256 _safe, address _liquidationEngine, address _saviour) external safeAllowed(_safe) {
    SAFEData memory _sData = _safeData[_safe];
    ILiquidationEngine(_liquidationEngine).protectSAFE(_sData.collateralType, _sData.safeHandler, _saviour);
    emit ProtectSAFE(msg.sender, _safe, _liquidationEngine, _saviour);
  }
}

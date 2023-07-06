// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiSafeManager} from '@contracts/proxies/HaiSafeManager.sol';
import {HaiProxyRegistry} from '@contracts/proxies/HaiProxyRegistry.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';
import {TaxCollector} from '@contracts/TaxCollector.sol';
import {CollateralJoin} from '@contracts/utils/CollateralJoin.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';

import {Math, WAD, RAY, RAD} from '@libraries/Math.sol';

import {CommonActions} from '@contracts/proxies/actions/CommonActions.sol';

/**
 * TODO:
 * - test all methods
 * - ensure all SafeEngine calls are proxied
 * - import all interfaces (not contracts)
 */

// solhint-disable
// TODO: enable linter
/**
 * @title BasicActions
 * @notice All methods here are executed as delegatecalls from the user's proxy
 */
contract BasicActions is CommonActions {
  using Math for uint256;

  // Internal functions

  /**
   * @notice Gets delta debt generated (Total Safe debt minus available safeHandler COIN balance)
   * @param _safeEngine address
   * @param _taxCollector address
   * @param _safeHandler address
   * @param _cType bytes32
   * @param _wad uint
   */
  function _getGeneratedDeltaDebt(
    address _safeEngine,
    address _taxCollector,
    address _safeHandler,
    bytes32 _cType,
    uint256 _wad
  ) internal returns (int256 _deltaDebt) {
    // Updates stability fee rate
    uint256 _rate = TaxCollector(_taxCollector).taxSingle(_cType);
    require(_rate > 0, 'invalid-collateral-type');

    // Gets COIN balance of the handler in the safeEngine
    uint256 _coin = ISAFEEngine(_safeEngine).coinBalance(_safeHandler);

    // If there was already enough COIN in the safeEngine balance, just exits it without adding more debt
    if (_coin < _wad * RAY) {
      // Calculates the needed deltaDebt so together with the existing coins in the safeEngine is enough to exit wad amount of COIN tokens
      _deltaDebt = ((_wad * RAY - _coin) / _rate).toInt();
      // This is neeeded due lack of precision. It might need to sum an extra deltaDebt wei (for the given COIN wad amount)
      _deltaDebt = uint256(_deltaDebt) * _rate < _wad * RAY ? _deltaDebt + 1 : _deltaDebt;
    }
  }

  /**
   * @notice Gets repaid delta debt generated (rate adjusted debt)
   * @param _safeEngine address
   * @param _coin uint amount
   * @param _safeId uint - safeId
   * @param _cType bytes32
   * @return _deltaDebt uint - amount of debt to be repayed
   */
  function _getRepaidDeltaDebt(
    address _safeEngine,
    uint256 _coin,
    address _safeId,
    bytes32 _cType
  ) internal view returns (int256 _deltaDebt) {
    // Gets actual rate from the safeEngine
    uint256 _rate = ISAFEEngine(_safeEngine).cData(_cType).accumulatedRate;
    require(_rate > 0, 'invalid-collateral-type');

    // Gets actual generatedDebt value of the safe
    ISAFEEngine.SAFE memory _safeData = ISAFEEngine(_safeEngine).safes(_cType, _safeId);

    // Uses the whole coin balance in the safeEngine to reduce the debt
    _deltaDebt = (_coin / _rate).toInt();
    // Checks the calculated deltaDebt is not higher than safe.generatedDebt (total debt), otherwise uses its value
    _deltaDebt = uint256(_deltaDebt) <= _safeData.generatedDebt ? -_deltaDebt : -_safeData.generatedDebt.toInt();
  }

  /**
   * @notice Gets repaid debt (rate adjusted rate minus COIN balance available in usr's address)
   * @param _safeEngine address
   * @param _usr address
   * @param _safeId uint - safeId
   * @param _cType  bytes32
   * @return _wad
   */
  function _getRepaidAlDebt(
    address _safeEngine,
    address _usr,
    address _safeId,
    bytes32 _cType
  ) internal view returns (uint256 _wad) {
    // Gets actual rate from the safeEngine
    uint256 _rate = ISAFEEngine(_safeEngine).cData(_cType).accumulatedRate;
    // Gets actual generatedDebt value of the safe
    ISAFEEngine.SAFE memory _safeData = ISAFEEngine(_safeEngine).safes(_cType, _safeId);
    // Gets actual coin amount in the safe
    uint256 _coin = ISAFEEngine(_safeEngine).coinBalance(_usr);

    uint256 _rad = _safeData.generatedDebt * _rate - _coin;
    _wad = _rad / RAY;

    // If the rad precision has some dust, it will need to request for 1 extra wad wei
    _wad = _wad * RAY < _rad ? _wad + 1 : _wad;
  }

  /**
   * @notice Generates debt and sends COIN amount to `_to` address
   * @param _manager address
   * @param _taxCollector address
   * @param _coinJoin address
   * @param _safeId uint - safeId
   * @param _wad uint - amount of debt to be generated
   * @param _to address - receiver of the balance of generated COIN
   */
  function _generateDebt(
    address _manager,
    address _taxCollector,
    address _coinJoin,
    uint256 _safeId,
    uint256 _wad,
    address _to
  ) internal {
    address _safeEngine = HaiSafeManager(_manager).safeEngine();
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(_manager).safeData(_safeId);
    // Generates debt in the SAFE
    modifySAFECollateralization(
      _manager,
      _safeId,
      0,
      _getGeneratedDeltaDebt(_safeEngine, _taxCollector, _safeInfo.safeHandler, _safeInfo.collateralType, _wad)
    );
    // Moves the COIN amount (balance in the safeEngine in rad) to proxy's address
    transferInternalCoins(_manager, _safeId, address(this), _wad * RAY);
    // Allows adapter to access to proxy's COIN balance in the safeEngine
    if (!ISAFEEngine(_safeEngine).canModifySAFE(address(this), address(_coinJoin))) {
      ISAFEEngine(_safeEngine).approveSAFEModification(_coinJoin);
    }
    // Exits COIN to this contract
    CoinJoin(_coinJoin).exit(_to, _wad);
  }

  /**
   * @notice Repays debt
   * @param _manager address
   * @param _coinJoin addres
   * @param _safeId uint - safeId
   * @param _wad uint - amount of debt to be repayed
   * @param _transferFromCaller bool
   */
  function _repayDebt(
    address _manager,
    address _coinJoin,
    uint256 _safeId,
    uint256 _wad,
    bool _transferFromCaller
  ) internal {
    address _safeEngine = HaiSafeManager(_manager).safeEngine();
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(_manager).safeData(_safeId);

    if (
      _safeInfo.owner == address(this) || HaiSafeManager(_manager).safeCan(_safeInfo.owner, _safeId, address(this)) == 1
    ) {
      // Joins COIN amount into the safeEngine
      if (_transferFromCaller) coinJoin_join(_coinJoin, _safeInfo.safeHandler, _wad);
      else _coinJoin_join(_coinJoin, _safeInfo.safeHandler, _wad);
      // Paybacks debt to the SAFE
      modifySAFECollateralization(
        _manager,
        _safeId,
        0,
        _getRepaidDeltaDebt(
          _safeEngine,
          ISAFEEngine(_safeEngine).coinBalance(_safeInfo.safeHandler),
          _safeInfo.safeHandler,
          _safeInfo.collateralType
        )
      );
    } else {
      // Joins COIN amount into the safeEngine
      if (_transferFromCaller) coinJoin_join(_coinJoin, address(this), _wad);
      else _coinJoin_join(_coinJoin, address(this), _wad);
      // Paybacks debt to the SAFE
      ISAFEEngine(_safeEngine).modifySAFECollateralization(
        _safeInfo.collateralType,
        _safeInfo.safeHandler,
        address(this),
        address(this),
        0,
        _getRepaidDeltaDebt(_safeEngine, _wad * RAY, _safeInfo.safeHandler, _safeInfo.collateralType)
      );
    }
  }

  // Public functions

  /**
   * @notice ERC20 transfer
   * @param _collateral address - address of ERC20 collateral
   * @param _dst address - Transfer destination
   * @param _amt address - Amount to transfer
   */
  function transfer(address _collateral, address _dst, uint256 _amt) external delegateCall {
    IERC20Metadata(_collateral).transfer(_dst, _amt);
  }

  /**
   * @notice Approves an address to modify the Safe
   * @param _safeEngine address
   * @param _usr address - Address allowed to modify Safe
   */
  function approveSAFEModification(address _safeEngine, address _usr) external delegateCall {
    ISAFEEngine(_safeEngine).approveSAFEModification(_usr);
  }

  /**
   * @notice Denies an address to modify the Safe
   * @param _safeEngine address
   * @param _usr address - Address disallowed to modify Safe
   */
  function denySAFEModification(address _safeEngine, address _usr) external delegateCall {
    ISAFEEngine(_safeEngine).denySAFEModification(_usr);
  }

  /**
   * @notice Opens a brand new Safe
   * @param _manager address
   * @param _cType bytes32
   * @param _usr address
   */
  function openSAFE(address _manager, bytes32 _cType, address _usr) public delegateCall returns (uint256 _safeId) {
    _safeId = HaiSafeManager(_manager).openSAFE(_cType, _usr);
  }

  /**
   * @notice Transfer the ownership of a proxy owned Safe
   * @param _manager address
   * @param _safeId uint - Safe Id
   * @param _usr address - Owner of the safe
   */
  function transferSAFEOwnership(address _manager, uint256 _safeId, address _usr) public delegateCall {
    HaiSafeManager(_manager).transferSAFEOwnership(_safeId, _usr);
  }

  /**
   * @notice Transfer the ownership to a new proxy owned by a different address
   * @param _proxyRegistry address
   * @param _manager address
   * @param _safeId uint - Safe Id
   * @param _dst address - Owner of the new proxy
   */
  function transferSAFEOwnershipToProxy(
    address _proxyRegistry,
    address _manager,
    uint256 _safeId,
    address _dst
  ) external delegateCall {
    // Gets actual proxy address
    HaiProxy _proxy = HaiProxyRegistry(_proxyRegistry).proxies(_dst);
    // Checks if the proxy address already existed and dst address is still the owner
    if (address(_proxy) == address(0) || _proxy.owner() != _dst) {
      uint256 csize;
      assembly {
        csize := extcodesize(_dst)
      }
      // We want to avoid creating a proxy for a contract address that might not be able to handle proxies, then losing the SAFE
      require(csize == 0, 'dst-is-a-contract');
      // Creates the proxy for the dst address
      _proxy = HaiProxy(HaiProxyRegistry(_proxyRegistry).build(_dst));
    }
    // Transfers SAFE to the dst proxy
    transferSAFEOwnership(_manager, _safeId, address(_proxy));
  }

  /**
   * @notice Allow/disallow a usr address to manage the safe
   * @param _manager address
   * @param _safeId uint - Safe Id
   * @param _usr address
   * @param _ok uint - 1 for allowed
   */
  function allowSAFE(address _manager, uint256 _safeId, address _usr, uint256 _ok) external delegateCall {
    HaiSafeManager(_manager).allowSAFE(_safeId, _usr, _ok);
  }

  /**
   * @notice Allow/disallow a usr address to quit to the sender handler
   * @param _manager address
   * @param _usr address
   * @param _ok uint - 1 for allowed
   */
  function allowHandler(address _manager, address _usr, uint256 _ok) external delegateCall {
    HaiSafeManager(_manager).allowHandler(_usr, _ok);
  }

  /**
   * @notice Transfer wad amount of safe collateral from the safe address to a dst address.
   * @param _manager address
   * @param _safeId uint - Safe Id
   * @param _dst address - destination address
   * @param _wad uint - amount
   */
  function transferCollateral(address _manager, uint256 _safeId, address _dst, uint256 _wad) public delegateCall {
    HaiSafeManager(_manager).transferCollateral(_safeId, _dst, _wad);
  }

  /**
   * @notice Transfer rad amount of COIN from the safe address to a dst address.
   * @param _manager address
   * @param _safeId uint - Safe Id
   * @param _dst address - destination address
   * @param _rad uin - amount
   */
  function transferInternalCoins(address _manager, uint256 _safeId, address _dst, uint256 _rad) public delegateCall {
    HaiSafeManager(_manager).transferInternalCoins(_safeId, _dst, _rad);
  }

  /**
   * @notice Modify a SAFE's collateralization ratio while keeping the generated COIN or collateral freed in the SAFE handler address.
   * @param _manager address
   * @param _safeId uint - Safe Id
   * @param _deltaCollateral int
   * @param _deltaDebt int
   */
  function modifySAFECollateralization(
    address _manager,
    uint256 _safeId,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) public delegateCall {
    HaiSafeManager(_manager).modifySAFECollateralization(_safeId, _deltaCollateral, _deltaDebt);
  }

  /**
   * @notice Quit the system, migrating the safe (lockedCollateral, generatedDebt) to a different dst handler
   * @param _manager address
   * @param _safeId uint - Safe Id
   * @param _dst address - destination handler
   */
  function quitSystem(address _manager, uint256 _safeId, address _dst) external delegateCall {
    HaiSafeManager(_manager).quitSystem(_safeId, _dst);
  }

  /**
   * @notice Import a position from src handler to the handler owned by safe
   * @param _manager address
   * @param _src address - source handler
   * @param _safeId uint - Safe Id
   */
  function enterSystem(address _manager, address _src, uint256 _safeId) external delegateCall {
    HaiSafeManager(_manager).enterSystem(_src, _safeId);
  }

  /**
   * @notice Move a position from safeSrc handler to the safeDst handler
   * @param _manager address
   * @param _srcSafeId uint - Source Safe Id
   * @param _dstSafeId uint - Destination Safe Id
   */
  function moveSAFE(address _manager, uint256 _srcSafeId, uint256 _dstSafeId) external delegateCall {
    HaiSafeManager(_manager).moveSAFE(_srcSafeId, _dstSafeId);
  }

  /**
   * @notice Generates debt and sends COIN amount to msg.sender
   * @param _manager address
   * @param _taxCollector address
   * @param _coinJoin address
   * @param _safeId uint - Safe Id
   * @param _wad uint
   */
  function generateDebt(
    address _manager,
    address _taxCollector,
    address _coinJoin,
    uint256 _safeId,
    uint256 _wad
  ) public delegateCall {
    _generateDebt(_manager, _taxCollector, _coinJoin, _safeId, _wad, msg.sender);
  }

  /**
   * @notice Repays debt
   * @param _manager address
   * @param _coinJoin address
   * @param _safeId uint - Safe Id
   * @param _wad uint - Amount
   */
  function repayDebt(address _manager, address _coinJoin, uint256 _safeId, uint256 _wad) public delegateCall {
    _repayDebt(_manager, _coinJoin, _safeId, _wad, true);
  }

  function _tokenCollateralJoin_join(address _joinAdapter, address _safe, uint256 _wad, bool _transferFrom) internal {
    // Only executes for tokens that have approval/transferFrom implementation
    CollateralJoin _collateralJoin = CollateralJoin(_joinAdapter);
    IERC20Metadata _token = IERC20Metadata(_collateralJoin.collateral());
    uint256 _decimals = _token.decimals();
    // Transforms the token amount into ERC20 native decimals
    uint256 _wei = _wad / 10 ** (18 - _decimals);

    if (_transferFrom) {
      // Gets token from the user's wallet
      _token.transferFrom(msg.sender, address(this), _wei);
      // Approves adapter to take the token amount
      _token.approve(_joinAdapter, _wei);
    }

    // Joins token collateral into the safeEngine
    _collateralJoin.join(_safe, _wei);
  }

  function lockTokenCollateral(
    address _manager,
    address _collateralJoin,
    uint256 _safeId,
    uint256 _wad,
    bool _transferFrom
  ) public delegateCall {
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(_manager).safeData(_safeId);

    // Takes token amount from user's wallet and joins into the safeEngine
    _tokenCollateralJoin_join(_collateralJoin, address(this), _wad, _transferFrom);
    // Locks token amount into the SAFE
    ISAFEEngine(HaiSafeManager(_manager).safeEngine()).modifySAFECollateralization(
      _safeInfo.collateralType, _safeInfo.safeHandler, address(this), address(this), _wad.toInt(), 0
    );
  }

  function freeTokenCollateral(
    address _manager,
    address _collateralJoin,
    uint256 _safeId,
    uint256 _wad
  ) public delegateCall {
    // Calculates wei amount in collateral token decimals
    uint256 _decimals = CollateralJoin(_collateralJoin).decimals();
    uint256 _wei = _wad / 10 ** (18 - _decimals);
    // Rounds down wad amount to collateral token precision
    _wad = _wei * 10 ** (18 - _decimals);
    // Unlocks token amount from the SAFE
    modifySAFECollateralization(_manager, _safeId, -_wad.toInt(), 0);
    // Moves the amount from the SAFE handler to proxy's address
    transferCollateral(_manager, _safeId, address(this), _wad);
    // Exits token amount to the user's wallet as a token
    CollateralJoin(_collateralJoin).exit(msg.sender, _wei);
  }

  function exitTokenCollateral(
    address _manager,
    address _collateralJoin,
    uint256 _safeId,
    uint256 _wad
  ) public delegateCall {
    // Calculates wei amount in collateral token decimals
    uint256 _decimals = CollateralJoin(_collateralJoin).decimals();
    uint256 _wei = _wad / 10 ** (18 - _decimals);
    // Rounds down wad amount to collateral token precision
    _wad = _wei * 10 ** (18 - _decimals);
    // Moves the amount from the SAFE handler to proxy's address
    transferCollateral(_manager, _safeId, address(this), _wad);
    // Exits token amount to the user's wallet as a token
    CollateralJoin(_collateralJoin).exit(msg.sender, _wei);
  }

  function repayAllDebt(address _manager, address _coinJoin, uint256 _safeId) public delegateCall {
    address _safeEngine = HaiSafeManager(_manager).safeEngine();
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(_manager).safeData(_safeId);

    ISAFEEngine.SAFE memory _safeData = ISAFEEngine(_safeEngine).safes(_safeInfo.collateralType, _safeInfo.safeHandler);

    address _owner = _safeInfo.owner;
    if (_owner == address(this) || HaiSafeManager(_manager).safeCan(_owner, _safeId, address(this)) == 1) {
      // Joins COIN amount into the safeEngine
      coinJoin_join(
        _coinJoin,
        _safeInfo.safeHandler,
        _getRepaidAlDebt(_safeEngine, _safeInfo.safeHandler, _safeInfo.safeHandler, _safeInfo.collateralType)
      );
      // Paybacks debt to the SAFE
      modifySAFECollateralization(_manager, _safeId, 0, -int256(_safeData.generatedDebt));
    } else {
      // Joins COIN amount into the safeEngine
      coinJoin_join(
        _coinJoin,
        address(this),
        _getRepaidAlDebt(_safeEngine, address(this), _safeInfo.safeHandler, _safeInfo.collateralType)
      );
      // Paybacks debt to the SAFE
      ISAFEEngine(_safeEngine).modifySAFECollateralization(
        _safeInfo.collateralType,
        _safeInfo.safeHandler,
        address(this),
        address(this),
        0,
        -int256(_safeData.generatedDebt)
      );
    }
  }

  function lockTokenCollateralAndGenerateDebt(
    address _manager,
    address _taxCollector,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safe,
    uint256 _collateralAmount,
    uint256 _deltaWad,
    bool _transferFrom
  ) public delegateCall {
    address safeEngine = HaiSafeManager(_manager).safeEngine();
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(_manager).safeData(_safe);

    // Takes token amount from user's wallet and joins into the safeEngine
    _tokenCollateralJoin_join(_collateralJoin, _safeInfo.safeHandler, _collateralAmount, _transferFrom);
    // Locks token amount into the SAFE and generates debt
    modifySAFECollateralization(
      _manager,
      _safe,
      _collateralAmount.toInt(),
      _getGeneratedDeltaDebt(safeEngine, _taxCollector, _safeInfo.safeHandler, _safeInfo.collateralType, _deltaWad)
    );
    // Moves the COIN amount (balance in the safeEngine in rad) to proxy's address
    transferInternalCoins(_manager, _safe, address(this), _deltaWad * RAY);
    // Allows adapter to access to proxy's COIN balance in the safeEngine
    if (!ISAFEEngine(safeEngine).canModifySAFE(address(this), address(_coinJoin))) {
      ISAFEEngine(safeEngine).approveSAFEModification(_coinJoin);
    }
    // Exits COIN to the user's wallet as a token
    CoinJoin(_coinJoin).exit(msg.sender, _deltaWad);
  }

  function openLockTokenCollateralAndGenerateDebt(
    address _manager,
    address _taxCollector,
    address _collateralJoin,
    address _coinJoin,
    bytes32 _cType,
    uint256 _collateralAmount,
    uint256 _deltaWad,
    bool _transferFrom
  ) public delegateCall returns (uint256 _safe) {
    _safe = openSAFE(_manager, _cType, address(this));
    lockTokenCollateralAndGenerateDebt(
      _manager, _taxCollector, _collateralJoin, _coinJoin, _safe, _collateralAmount, _deltaWad, _transferFrom
    );
  }

  function repayDebtAndFreeTokenCollateral(
    address _manager,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safe,
    uint256 _collateralWad,
    uint256 _deltaWad
  ) external delegateCall {
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(_manager).safeData(_safe);
    // Joins COIN amount into the safeEngine
    coinJoin_join(_coinJoin, _safeInfo.safeHandler, _deltaWad);
    // Paybacks debt to the SAFE and unlocks token amount from it
    modifySAFECollateralization(
      _manager,
      _safe,
      -_collateralWad.toInt(),
      _getRepaidDeltaDebt(
        HaiSafeManager(_manager).safeEngine(),
        ISAFEEngine(HaiSafeManager(_manager).safeEngine()).coinBalance(_safeInfo.safeHandler),
        _safeInfo.safeHandler,
        _safeInfo.collateralType
      )
    );
    // Moves the amount from the SAFE handler to proxy's address
    transferCollateral(_manager, _safe, address(this), _collateralWad);
    uint256 _decimals = CollateralJoin(_collateralJoin).decimals();
    uint256 _wei = _collateralWad / 10 ** (18 - _decimals);
    // Exits token amount to the user's wallet as a token
    CollateralJoin(_collateralJoin).exit(msg.sender, _wei);
  }

  function repayAllDebtAndFreeTokenCollateral(
    address _manager,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safe,
    uint256 _collateralWad
  ) public delegateCall {
    address _safeEngine = HaiSafeManager(_manager).safeEngine();
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(_manager).safeData(_safe);

    ISAFEEngine.SAFE memory _safeData = ISAFEEngine(_safeEngine).safes(_safeInfo.collateralType, _safeInfo.safeHandler);

    // Joins COIN amount into the safeEngine
    coinJoin_join(
      _coinJoin,
      _safeInfo.safeHandler,
      _getRepaidAlDebt(_safeEngine, _safeInfo.safeHandler, _safeInfo.safeHandler, _safeInfo.collateralType)
    );
    // Paybacks debt to the SAFE and unlocks token amount from it
    modifySAFECollateralization(_manager, _safe, -_collateralWad.toInt(), -_safeData.generatedDebt.toInt());
    // Moves the amount from the SAFE handler to proxy's address
    transferCollateral(_manager, _safe, address(this), _collateralWad);
    uint256 _decimals = CollateralJoin(_collateralJoin).decimals();
    uint256 _wei = _collateralWad / 10 ** (18 - _decimals);
    // Exits token amount to the user's wallet as a token
    CollateralJoin(_collateralJoin).exit(msg.sender, _wei);
  }
}

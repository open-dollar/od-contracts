// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiSafeManager} from '@contracts/proxies/HaiSafeManager.sol';
import {HaiProxyRegistry} from '@contracts/proxies/HaiProxyRegistry.sol';
import {HaiProxy} from '@contracts/proxies/HaiProxy.sol';

import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';
import {CoinJoin} from '@contracts/utils/CoinJoin.sol';
import {TaxCollector} from '@contracts/TaxCollector.sol';
import {CollateralJoin, IERC20Metadata} from '@contracts/utils/CollateralJoin.sol';

import {Math, WAD, RAY, RAD} from '@libraries/Math.sol';

import {Common} from '@contracts/proxies/actions/Common.sol';

/**
 * TODO:
 * - test all methods
 * - ensure all SafeEngine calls are proxied
 * - import all interfaces (not contracts)
 */

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// WARNING: These functions meant to be used as a a library for a HaiProxy. Some are unsafe if you call them directly.
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

// solhint-disable
// TODO: enable linter
contract BasicActions is Common {
  using Math for uint256;

  // Internal functions

  /// @notice Gets delta debt generated (Total Safe debt minus available safeHandler COIN balance)
  /// @param _safeEngine address
  /// @param _taxCollector address
  /// @param _safeHandler address
  /// @param _collateralType bytes32
  /// @return _deltaDebt
  function _getGeneratedDeltaDebt(
    address _safeEngine,
    address _taxCollector,
    address _safeHandler,
    bytes32 _collateralType,
    uint256 _wad
  ) internal returns (int256 _deltaDebt) {
    // Updates stability fee rate
    uint256 _rate = TaxCollector(_taxCollector).taxSingle(_collateralType);
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

  /// @notice Gets repaid delta debt generated (rate adjusted debt)
  /// @param _safeEngine address
  /// @param _coin uint amount
  /// @param _safe uint - safeId
  /// @param _collateralType bytes32
  /// @return _deltaDebt
  function _getRepaidDeltaDebt(
    address _safeEngine,
    uint256 _coin,
    address _safe,
    bytes32 _collateralType
  ) internal view returns (int256 _deltaDebt) {
    // Gets actual rate from the safeEngine
    uint256 _rate = ISAFEEngine(_safeEngine).cData(_collateralType).accumulatedRate;
    require(_rate > 0, 'invalid-collateral-type');

    // Gets actual generatedDebt value of the safe
    ISAFEEngine.SAFE memory _safeData = ISAFEEngine(_safeEngine).safes(_collateralType, _safe);

    // Uses the whole coin balance in the safeEngine to reduce the debt
    _deltaDebt = (_coin / _rate).toInt();
    // Checks the calculated deltaDebt is not higher than safe.generatedDebt (total debt), otherwise uses its value
    _deltaDebt = uint256(_deltaDebt) <= _safeData.generatedDebt ? -_deltaDebt : -_safeData.generatedDebt.toInt();
  }

  /// @notice Gets repaid debt (rate adjusted rate minus COIN balance available in usr's address)
  /// @param _safeEngine address
  /// @param _usr address
  /// @param _safe uint
  /// @param _collateralType address
  /// @return _wad
  function _getRepaidAlDebt(
    address _safeEngine,
    address _usr,
    address _safe,
    bytes32 _collateralType
  ) internal view returns (uint256 _wad) {
    // Gets actual rate from the safeEngine
    uint256 _rate = ISAFEEngine(_safeEngine).cData(_collateralType).accumulatedRate;
    // Gets actual generatedDebt value of the safe
    ISAFEEngine.SAFE memory _safeData = ISAFEEngine(_safeEngine).safes(_collateralType, _safe);
    // Gets actual coin amount in the safe
    uint256 _coin = ISAFEEngine(_safeEngine).coinBalance(_usr);

    uint256 _rad = _safeData.generatedDebt * _rate - _coin;
    _wad = _rad / RAY;

    // If the rad precision has some dust, it will need to request for 1 extra wad wei
    _wad = _wad * RAY < _rad ? _wad + 1 : _wad;
  }

  /// @notice Generates Debt (and sends coin balance to address to)
  /// @param _manager address
  /// @param _taxCollector address
  /// @param _coinJoin address
  /// @param _safe uint
  /// @param _wad uint - amount of debt to be generated
  /// @param _to address - receiver of the balance of generated COIN
  function _generateDebt(
    address _manager,
    address _taxCollector,
    address _coinJoin,
    uint256 _safe,
    uint256 _wad,
    address _to
  ) internal {
    address safeEngine = HaiSafeManager(_manager).safeEngine();
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(_manager).safeData(_safe);
    // Generates debt in the SAFE
    modifySAFECollateralization(
      _manager,
      _safe,
      0,
      _getGeneratedDeltaDebt(safeEngine, _taxCollector, _safeInfo.safeHandler, _safeInfo.collateralType, _wad)
    );
    // Moves the COIN amount (balance in the safeEngine in rad) to proxy's address
    transferInternalCoins(_manager, _safe, address(this), _wad * RAY);
    // Allows adapter to access to proxy's COIN balance in the safeEngine
    if (!ISAFEEngine(safeEngine).canModifySAFE(address(this), address(_coinJoin))) {
      ISAFEEngine(safeEngine).approveSAFEModification(_coinJoin);
    }
    // Exits COIN to this contract
    CoinJoin(_coinJoin).exit(_to, _wad);
  }

  /// @notice Repays debt
  /// @param manager address
  /// @param coinJoin address
  /// @param safe uint
  /// @param wad uint - amount of debt to be repayed
  function _repayDebt(address manager, address coinJoin, uint256 safe, uint256 wad, bool transferFromCaller) internal {
    address safeEngine = HaiSafeManager(manager).safeEngine();
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(manager).safeData(safe);

    if (_safeInfo.owner == address(this) || HaiSafeManager(manager).safeCan(_safeInfo.owner, safe, address(this)) == 1)
    {
      // Joins COIN amount into the safeEngine
      if (transferFromCaller) coinJoin_join(coinJoin, _safeInfo.safeHandler, wad);
      else _coinJoin_join(coinJoin, _safeInfo.safeHandler, wad);
      // Paybacks debt to the SAFE
      modifySAFECollateralization(
        manager,
        safe,
        0,
        _getRepaidDeltaDebt(
          safeEngine,
          ISAFEEngine(safeEngine).coinBalance(_safeInfo.safeHandler),
          _safeInfo.safeHandler,
          _safeInfo.collateralType
        )
      );
    } else {
      // Joins COIN amount into the safeEngine
      if (transferFromCaller) coinJoin_join(coinJoin, address(this), wad);
      else _coinJoin_join(coinJoin, address(this), wad);
      // Paybacks debt to the SAFE
      ISAFEEngine(safeEngine).modifySAFECollateralization(
        _safeInfo.collateralType,
        _safeInfo.safeHandler,
        address(this),
        address(this),
        0,
        _getRepaidDeltaDebt(safeEngine, wad * RAY, _safeInfo.safeHandler, _safeInfo.collateralType)
      );
    }
  }

  // Public functions

  /// @notice ERC20 transfer
  /// @param collateral address - address of ERC20 collateral
  /// @param dst address - Transfer destination
  /// @param amt address - Amount to transfer
  function transfer(address collateral, address dst, uint256 amt) external {
    IERC20Metadata(collateral).transfer(dst, amt);
  }

  /// @notice Approves an address to modify the Safe
  /// @param safeEngine address
  /// @param usr address - Address allowed to modify Safe
  function approveSAFEModification(address safeEngine, address usr) external {
    ISAFEEngine(safeEngine).approveSAFEModification(usr);
  }

  /// @notice Denies an address to modify the Safe
  /// @param safeEngine address
  /// @param usr address - Address disallowed to modify Safe
  function denySAFEModification(address safeEngine, address usr) external {
    ISAFEEngine(safeEngine).denySAFEModification(usr);
  }

  /// @notice Opens a brand new Safe
  /// @param manager address - Safe Manager
  /// @param collateralType bytes32 - collateral type
  /// @param usr address - Owner of the safe
  function openSAFE(address manager, bytes32 collateralType, address usr) public returns (uint256 safe) {
    safe = HaiSafeManager(manager).openSAFE(collateralType, usr);
  }

  /// @notice Transfer the ownership of a proxy owned Safe
  /// @param manager address - Safe Manager
  /// @param safe uint - Safe Id
  /// @param usr address - Owner of the safe
  function transferSAFEOwnership(address manager, uint256 safe, address usr) public {
    HaiSafeManager(manager).transferSAFEOwnership(safe, usr);
  }

  /// @notice Transfer the ownership to a new proxy owned by a different address
  /// @param proxyRegistry address - Safe Manager
  /// @param manager address - Safe Manager
  /// @param safe uint - Safe Id
  /// @param dst address - Owner of the new proxy
  function transferSAFEOwnershipToProxy(address proxyRegistry, address manager, uint256 safe, address dst) external {
    // Gets actual proxy address
    HaiProxy proxy = HaiProxyRegistry(proxyRegistry).proxies(dst);
    // Checks if the proxy address already existed and dst address is still the owner
    if (address(proxy) == address(0) || proxy.owner() != dst) {
      uint256 csize;
      assembly {
        csize := extcodesize(dst)
      }
      // We want to avoid creating a proxy for a contract address that might not be able to handle proxies, then losing the SAFE
      require(csize == 0, 'dst-is-a-contract');
      // Creates the proxy for the dst address
      proxy = HaiProxy(HaiProxyRegistry(proxyRegistry).build(dst));
    }
    // Transfers SAFE to the dst proxy
    transferSAFEOwnership(manager, safe, address(proxy));
  }

  /// @notice Allow/disallow a usr address to manage the safe
  /// @param manager address - Safe Manager
  /// @param safe uint - Safe Id
  /// @param usr address - usr address
  /// uint ok - 1 for allowed
  function allowSAFE(address manager, uint256 safe, address usr, uint256 ok) external {
    HaiSafeManager(manager).allowSAFE(safe, usr, ok);
  }

  /// @notice Allow/disallow a usr address to quit to the sender handler
  /// @param manager address - Safe Manager
  /// @param usr address - usr address
  /// uint ok - 1 for allowed
  function allowHandler(address manager, address usr, uint256 ok) external {
    HaiSafeManager(manager).allowHandler(usr, ok);
  }

  /// @notice Transfer wad amount of safe collateral from the safe address to a dst address.
  /// @param manager address - Safe Manager
  /// @param safe uint - Safe Id
  /// @param dst address - destination address
  /// uint wad - amount
  function transferCollateral(address manager, uint256 safe, address dst, uint256 wad) public {
    HaiSafeManager(manager).transferCollateral(safe, dst, wad);
  }

  /// @notice Transfer rad amount of COIN from the safe address to a dst address.
  /// @param manager address - Safe Manager
  /// @param safe uint - Safe Id
  /// @param dst address - destination address
  /// uint rad - amount
  function transferInternalCoins(address manager, uint256 safe, address dst, uint256 rad) public {
    HaiSafeManager(manager).transferInternalCoins(safe, dst, rad);
  }

  /// @notice Modify a SAFE's collateralization ratio while keeping the generated COIN or collateral freed in the SAFE handler address.
  /// @param manager address - Safe Manager
  /// @param safe uint - Safe Id
  /// @param deltaCollateral - int
  /// @param deltaDebt - int
  function modifySAFECollateralization(address manager, uint256 safe, int256 deltaCollateral, int256 deltaDebt) public {
    HaiSafeManager(manager).modifySAFECollateralization(safe, deltaCollateral, deltaDebt);
  }

  /// @notice Quit the system, migrating the safe (lockedCollateral, generatedDebt) to a different dst handler
  /// @param manager address - Safe Manager
  /// @param safe uint - Safe Id
  /// @param dst - destination handler
  function quitSystem(address manager, uint256 safe, address dst) external {
    HaiSafeManager(manager).quitSystem(safe, dst);
  }

  /// @notice Import a position from src handler to the handler owned by safe
  /// @param manager address - Safe Manager
  /// @param src - source handler
  /// @param safe uint - Safe Id
  function enterSystem(address manager, address src, uint256 safe) external {
    HaiSafeManager(manager).enterSystem(src, safe);
  }

  /// @notice Move a position from safeSrc handler to the safeDst handler
  /// @param manager address - Safe Manager
  /// @param safeSrc uint - Source Safe Id
  /// @param safeDst uint - Destination Safe Id
  function moveSAFE(address manager, uint256 safeSrc, uint256 safeDst) external {
    HaiSafeManager(manager).moveSAFE(safeSrc, safeDst);
  }

  /// @notice Generates debt and sends COIN amount to msg.sender
  /// @param manager address
  /// @param taxCollector address
  /// @param coinJoin address
  /// @param safe uint - Safe Id
  /// @param wad uint - Amount
  function generateDebt(address manager, address taxCollector, address coinJoin, uint256 safe, uint256 wad) public {
    _generateDebt(manager, taxCollector, coinJoin, safe, wad, msg.sender);
  }

  /// @notice Repays debt
  /// @param manager address
  /// @param coinJoin address
  /// @param safe uint - Safe Id
  /// @param wad uint - Amount
  function repayDebt(address manager, address coinJoin, uint256 safe, uint256 wad) public {
    _repayDebt(manager, coinJoin, safe, wad, true);
  }

  function _tokenCollateralJoin_join(address apt, address safe, uint256 wad, bool transferFrom) internal {
    // Only executes for tokens that have approval/transferFrom implementation
    CollateralJoin _collateralJoin = CollateralJoin(apt);
    if (transferFrom) {
      IERC20Metadata token = IERC20Metadata(_collateralJoin.collateral());
      // Gets token from the user's wallet
      token.transferFrom(msg.sender, address(this), wad);
      // Approves adapter to take the token amount
      token.approve(apt, wad);
    }
    // Joins token collateral into the safeEngine
    _collateralJoin.join(safe, wad);
  }

  function lockTokenCollateral(
    address manager,
    address collateralJoin,
    uint256 safe,
    uint256 wad,
    bool transferFrom
  ) public {
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(manager).safeData(safe);

    // Takes token amount from user's wallet and joins into the safeEngine
    _tokenCollateralJoin_join(collateralJoin, address(this), wad, transferFrom);
    // Locks token amount into the SAFE
    ISAFEEngine(HaiSafeManager(manager).safeEngine()).modifySAFECollateralization(
      _safeInfo.collateralType, _safeInfo.safeHandler, address(this), address(this), wad.toInt(), 0
    );
  }

  function freeTokenCollateral(address manager, address collateralJoin, uint256 safe, uint256 wad) public {
    // Unlocks token amount from the SAFE
    modifySAFECollateralization(manager, safe, -wad.toInt(), 0);
    // Moves the amount from the SAFE handler to proxy's address
    transferCollateral(manager, safe, address(this), wad);
    // Exits token amount to the user's wallet as a token
    CollateralJoin(collateralJoin).exit(msg.sender, wad);
  }

  function exitTokenCollateral(address manager, address collateralJoin, uint256 safe, uint256 wad) public {
    // Moves the amount from the SAFE handler to proxy's address
    transferCollateral(manager, safe, address(this), wad);

    // Exits token amount to the user's wallet as a token
    CollateralJoin(collateralJoin).exit(msg.sender, wad);
  }

  function repayAllDebt(address manager, address coinJoin, uint256 safe) public {
    address safeEngine = HaiSafeManager(manager).safeEngine();
    HaiSafeManager.SAFEData memory _safeInfo = HaiSafeManager(manager).safeData(safe);

    ISAFEEngine.SAFE memory _safeData = ISAFEEngine(safeEngine).safes(_safeInfo.collateralType, _safeInfo.safeHandler);

    address own = _safeInfo.owner;
    if (own == address(this) || HaiSafeManager(manager).safeCan(own, safe, address(this)) == 1) {
      // Joins COIN amount into the safeEngine
      coinJoin_join(
        coinJoin,
        _safeInfo.safeHandler,
        _getRepaidAlDebt(safeEngine, _safeInfo.safeHandler, _safeInfo.safeHandler, _safeInfo.collateralType)
      );
      // Paybacks debt to the SAFE
      modifySAFECollateralization(manager, safe, 0, -int256(_safeData.generatedDebt));
    } else {
      // Joins COIN amount into the safeEngine
      coinJoin_join(
        coinJoin,
        address(this),
        _getRepaidAlDebt(safeEngine, address(this), _safeInfo.safeHandler, _safeInfo.collateralType)
      );
      // Paybacks debt to the SAFE
      ISAFEEngine(safeEngine).modifySAFECollateralization(
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
  ) public {
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
    bytes32 _collateralType,
    uint256 _collateralAmount,
    uint256 _deltaWad,
    bool _transferFrom
  ) public returns (uint256 _safe) {
    _safe = openSAFE(_manager, _collateralType, address(this));
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
  ) external {
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
    // Exits token amount to the user's wallet as a token
    CollateralJoin(_collateralJoin).exit(msg.sender, _collateralWad);
  }

  function repayAllDebtAndFreeTokenCollateral(
    address _manager,
    address _collateralJoin,
    address _coinJoin,
    uint256 _safe,
    uint256 _collateralWad
  ) public {
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
    // Exits token amount to the user's wallet as a token
    CollateralJoin(_collateralJoin).exit(msg.sender, _collateralWad);
  }
}

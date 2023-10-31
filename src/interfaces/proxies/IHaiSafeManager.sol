// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IHaiSafeManager {
  // --- Events ---

  /// @notice Emitted when calling allowSAFE with the sender address and the method arguments
  event AllowSAFE(address indexed _sender, uint256 indexed _safe, address _usr, bool _ok);
  /// @notice Emitted when calling allowHandler with the sender address and the method arguments
  event AllowHandler(address indexed _sender, address _usr, bool _ok);
  /// @notice Emitted when calling initiateTransferSAFEOwnership with the sender address and the method arguments
  event InitiateTransferSAFEOwnership(address indexed _sender, uint256 indexed _safe, address _dst);
  /// @notice Emitted when calling transferSAFEOwnership with the sender address and the method arguments
  event TransferSAFEOwnership(address indexed _sender, uint256 indexed _safe, address _dst);
  /// @notice Emitted when calling openSAFE with the sender address and the method arguments
  event OpenSAFE(address indexed _sender, address indexed _own, uint256 indexed _safe);
  /// @notice Emitted when calling modifySAFECollateralization with the sender address and the method arguments
  event ModifySAFECollateralization(
    address indexed _sender, uint256 indexed _safe, int256 _deltaCollateral, int256 _deltaDebt
  );
  /// @notice Emitted when calling transferCollateral with the sender address and the method arguments
  event TransferCollateral(address indexed _sender, uint256 indexed _safe, address _dst, uint256 _wad);
  /// @notice Emitted when calling transferCollateral (specifying cType) with the sender address and the method arguments
  event TransferCollateral(address indexed _sender, bytes32 _cType, uint256 indexed _safe, address _dst, uint256 _wad);
  /// @notice Emitted when calling transferInternalCoins with the sender address and the method arguments
  event TransferInternalCoins(address indexed _sender, uint256 indexed _safe, address _dst, uint256 _rad);
  /// @notice Emitted when calling quitSystem with the sender address and the method arguments
  event QuitSystem(address indexed _sender, uint256 indexed _safe, address _dst);
  /// @notice Emitted when calling enterSystem with the sender address and the method arguments
  event EnterSystem(address indexed _sender, address _src, uint256 indexed _safe);
  /// @notice Emitted when calling moveSAFE with the sender address and the method arguments
  event MoveSAFE(address indexed _sender, uint256 indexed _safeSrc, uint256 indexed _safeDst);
  /// @notice Emitted when calling protectSAFE with the sender address and the method arguments
  event ProtectSAFE(address indexed _sender, uint256 indexed _safe, address _liquidationEngine, address _saviour);

  // --- Errors ---

  /// @notice Throws if the provided address is null
  error ZeroAddress();
  /// @notice Throws when trying to call a function not allowed for a given safe
  error SafeNotAllowed();
  /// @notice Throws when trying to call a function not allowed for a given handler
  error HandlerNotAllowed();
  /// @notice Throws when trying to transfer safe ownership to the current owner
  error AlreadySafeOwner();
  /// @notice Throws when trying to move a safe to another one with different collateral type
  error CollateralTypesMismatch();

  // --- Structs ---

  struct SAFEData {
    // Address of the safe owner
    address owner;
    // Address of the safe owner pending to be set
    address pendingOwner;
    // Address of the safe handler
    address safeHandler;
    // Collateral type of the safe
    bytes32 collateralType;
  }

  // --- Data ---

  /// @notice Address of the SAFEEngine
  function safeEngine() external view returns (address _safeEngine);

  /// @notice Mapping of owner and safe permissions to a caller permissions
  function safeCan(address _owner, uint256 _safeId, address _caller) external view returns (bool _ok);

  /// @notice Mapping of handler to a caller permissions
  function handlerCan(address _safeHandler, address _caller) external view returns (bool _ok);

  // --- Getters ---

  /**
   * @notice Getter for the list of safes owned by a user
   * @param  _usr Address of the user
   * @return _safes List of safe ids owned by the user
   */
  function getSafes(address _usr) external view returns (uint256[] memory _safes);

  /**
   * @notice Getter for the list of safes owned by a user for a given collateral type
   * @param  _usr Address of the user
   * @param  _cType Bytes32 representation of the collateral type
   * @return _safes List of safe ids owned by the user for the given collateral type
   */
  function getSafes(address _usr, bytes32 _cType) external view returns (uint256[] memory _safes);

  /**
   * @notice Getter for the details of the safes owned by a user
   * @param  _usr Address of the user
   * @return _safes List of safe ids owned by the user
   * @return _safeHandlers List of safe handlers addresses owned by the user
   * @return _cTypes List of collateral types of the safes owned by the user
   */
  function getSafesData(address _usr)
    external
    view
    returns (uint256[] memory _safes, address[] memory _safeHandlers, bytes32[] memory _cTypes);

  /**
   * @notice Getter for the details of a SAFE
   * @param  _safe Id of the SAFE
   * @return _sData Struct with the safe data
   */
  function safeData(uint256 _safe) external view returns (SAFEData memory _sData);

  // --- Methods ---

  /**
   * @notice Allow/disallow a user address to manage the safe
   * @param  _safe Id of the SAFE
   * @param  _usr Address of the user to allow/disallow
   * @param  _ok Boolean state to allow/disallow
   */
  function allowSAFE(uint256 _safe, address _usr, bool _ok) external;

  /**
   * @notice Allow/disallow a handler address to manage the safe
   * @param  _usr Address of the user to allow/disallow
   * @param  _ok Boolean state to allow/disallow
   */
  function allowHandler(address _usr, bool _ok) external;

  /**
   * @notice Open a new safe for a user address
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _usr Address of the user to open the safe for
   * @return _id Id of the new SAFE
   */
  function openSAFE(bytes32 _cType, address _usr) external returns (uint256 _id);

  /**
   * @notice Initiate the transfer of the ownership of a safe to a dst address
   * @param  _safe Id of the SAFE
   * @param  _dst Address of the dst address
   */
  function transferSAFEOwnership(uint256 _safe, address _dst) external;

  /**
   * @notice Accept the transfer of the ownership of a safe
   * @param  _safe Id of the SAFE
   */
  function acceptSAFEOwnership(uint256 _safe) external;

  /**
   * @notice Modify a SAFE's collateralization ratio while keeping the generated COIN or collateral freed in the safe handler address
   * @param  _safe Id of the SAFE
   * @param  _deltaCollateral Delta of collateral to add/remove [wad]
   * @param  _deltaDebt Delta of debt to add/remove [wad]
   */
  function modifySAFECollateralization(uint256 _safe, int256 _deltaCollateral, int256 _deltaDebt) external;

  /**
   * @notice Transfer wad amount of safe collateral from the safe address to a dst address
   * @param  _safe Id of the SAFE
   * @param  _dst Address of the dst address
   * @param  _wad Amount of collateral to transfer [wad]
   */
  function transferCollateral(uint256 _safe, address _dst, uint256 _wad) external;

  /**
   * @notice Transfer wad amount of any type of collateral from the safe address to a dst address
   * @param  _cType Bytes32 representation of the collateral type
   * @param  _safe Id of the SAFE
   * @param  _dst Address of the dst address
   * @param  _wad Amount of collateral to transfer [wad]
   * @dev    This function has the purpose to take away collateral from the system that doesn't correspond to the safe but was sent there wrongly.
   */
  function transferCollateral(bytes32 _cType, uint256 _safe, address _dst, uint256 _wad) external;

  /**
   * @notice Transfer an amount of COIN from the safe address to a dst address [rad]
   * @param  _safe Id of the SAFE
   * @param  _dst Address of the dst address
   * @param  _rad Amount of COIN to transfer [rad]
   */
  function transferInternalCoins(uint256 _safe, address _dst, uint256 _rad) external;

  /**
   * @notice Quit the system, migrating the safe (lockedCollateral, generatedDebt) to a different dst handler
   * @param  _safe Id of the SAFE
   * @param  _dst Address of the dst handler
   */
  function quitSystem(uint256 _safe, address _dst) external;

  /**
   * @notice Enter the system, migrating the safe (lockedCollateral, generatedDebt) from a src handler to the safe handler
   * @param  _src Address of the src handler
   * @param  _safe Id of the SAFE
   */
  function enterSystem(address _src, uint256 _safe) external;

  /**
   * @notice Move a position from safeSrc handler to the safeDst handler
   * @param  _safeSrc Id of the source SAFE
   * @param  _safeDst Id of the destination SAFE
   */
  function moveSAFE(uint256 _safeSrc, uint256 _safeDst) external;

  /**
   * @notice Add a safe to the user's list of safes (doesn't set safe ownership)
   * @param  _safe Id of the SAFE
   * @dev    This function is meant to allow the user to add a safe to their list (if it was previously removed)
   */
  function addSAFE(uint256 _safe) external;

  /**
   * @notice Remove a safe from the user's list of safes (doesn't erase safe ownership)
   * @param  _safe Id of the SAFE
   * @dev    This function is meant to allow the user to remove a safe from their list (if it was added against their will)
   */
  function removeSAFE(uint256 _safe) external;

  /**
   * @notice Choose a safe saviour inside LiquidationEngine for the SAFE
   * @param  _safe Id of the SAFE
   * @param  _liquidationEngine Address of the LiquidationEngine
   * @param  _saviour Address of the saviour
   */
  function protectSAFE(uint256 _safe, address _liquidationEngine, address _saviour) external;
}

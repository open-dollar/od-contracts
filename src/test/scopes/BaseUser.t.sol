// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

/**
 * @title  BaseUser
 * @notice Abstract contract containing all methods to interact with the system
 * @dev    Used to override it with different implementations (e.g. ProxyUser, DirectUser)
 */
abstract contract BaseUser {
  // TODO: make method view (needs to re-route `_getSafe` in ProxyUser.t.sol)
  function _getSafeStatus(
    bytes32 _cType,
    address _user
  ) internal virtual returns (uint256 _generatedDebt, uint256 _lockedCollateral);

  function _lockETH(address _user, uint256 _amount) internal virtual;

  function _joinTKN(address _user, address _collateralJoin, uint256 _amount) internal virtual;

  function _joinCoins(address _user, uint256 _amount) internal virtual;

  function _generateDebt(
    address _user,
    address _collateralJoin,
    int256 _deltaCollat,
    int256 _deltaDebt
  ) internal virtual;

  function _exitCoin(address _user, uint256 _amount) internal virtual;

  function _liquidateSAFE(bytes32 _cType, address _user) internal virtual;
}
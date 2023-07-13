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

  function _getCollateralBalance(address _user, bytes32 _cType) internal view virtual returns (uint256 _wad);

  function _lockETH(address _user, uint256 _amount) internal virtual;

  function _joinTKN(address _user, address _collateralJoin, uint256 _amount) internal virtual;

  function _exitCollateral(address _user, address _collateralJoin, uint256 _amount) internal virtual;

  function _joinCoins(address _user, uint256 _amount) internal virtual;

  function _generateDebt(
    address _user,
    address _collateralJoin,
    int256 _deltaCollat,
    int256 _deltaDebt
  ) internal virtual;

  function _repayDebtAndExit(
    address _user,
    address _collateralJoin,
    uint256 _deltaCollat,
    uint256 _deltaDebt
  ) internal virtual;

  function _exitCoin(address _user, uint256 _amount) internal virtual;

  function _liquidateSAFE(bytes32 _cType, address _user) internal virtual;

  function _buyCollateral(
    address _user,
    address _collateralAuctionHouse,
    uint256 _auctionId,
    uint256 _soldAmount,
    uint256 _amountToBid
  ) internal virtual;

  function _buyProtocolToken(
    address _user,
    uint256 _auctionId,
    uint256 _amountToBuy,
    uint256 _amountToBid
  ) internal virtual;

  function _settleDebtAuction(address _user, uint256 _auctionId) internal virtual;

  function _auctionSurplusAndBid(address _user, uint256 _bidAmount) internal virtual;

  function _increaseBidSize(address _user, uint256 _auctionId, uint256 _bidAmount) internal virtual;

  function _settleAuction(address _user, uint256 _auctionId) internal virtual;

  function _collectSystemCoins(address _user) internal virtual;
}

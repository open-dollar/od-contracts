pragma solidity 0.6.7;

import {IDisableable} from './IDisableable.sol';
import {IAuthorizable} from './IAuthorizable.sol';

interface ISAFEEngine is IDisableable, IAuthorizable {
  function coinBalance(address _coinAddress) external view returns (uint256 _balance);
  function debtBalance(address _coinAddress) external view returns (uint256 _debtBalance);
  function settleDebt(uint256 _rad) external;
  function transferInternalCoins(address _source, address _destination, uint256 _rad) external;
  function transferCollateral(bytes32 _collateralType, address _source, address _destination, uint256 _wad) external;
  function canModifySAFE(address _safe, address _account) external view returns (bool);
  function approveSAFEModification(address _account) external;
  function denySAFEModification(address _acount) external;
  function createUnbackedDebt(address _debtDestination, address _coinDestination, uint256 _rad) external;
  function collateralTypes(bytes32)
    external
    view
    returns (
      uint256 /* wad */ _debtAmount,
      uint256 /* ray */ _accumulatedRate,
      uint256 /* ray */ _safetyPrice,
      uint256 /* rad */ _debtCeiling,
      uint256 /* rad */ _debtFloor,
      uint256 /* ray */ _liquidationPrice
    );

  function safes(
    bytes32,
    address
  ) external view returns (uint256 /* wad */ _lockedCollateral, uint256 /* wad */ _generatedDebt);

  function globalDebt() external returns (uint256 _globalDebt);
  function confiscateSAFECollateralAndDebt(
    bytes32 _collateralType,
    address _safe,
    address _collateralSource,
    address _debtDestination,
    int256 _deltaCollateral,
    int256 _deltaDebt
  ) external;
  function modifyParameters(bytes32 _collateralType, bytes32 _parameter, uint256 _data) external;
  function updateAccumulatedRate(bytes32 _collateralType, address _surplusDst, int256 _rateMultiplier) external;

  function initializeCollateralType(bytes32 _collateralType) external;
  function modifyCollateralBalance(bytes32 _collateralType, address _account, int256 _wad) external;
  function modifySAFECollateralization(
    bytes32 _collateralType,
    address _safe,
    address _collateralSource,
    address _debtDestination,
    int256 /* wad */ _deltaCollateral,
    int256 /* wad */ _deltaDebt
  ) external;

  function transferSAFECollateralAndDebt(
    bytes32 _collateralType,
    address _src,
    address _dst,
    int256 /* wad */ _deltaCollateral,
    int256 /* wad */ _deltaDebt
  ) external;
}

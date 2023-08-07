// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IFactoryChild {
  // --- Errors ---
  error NotFactoryDeployment();
  error CallerNotFactory();

  // --- Registry ---
  function factory() external view returns (address _factory);
}

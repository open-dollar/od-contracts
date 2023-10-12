// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {AnvilFork} from '@test/nft/anvil/AnvilFork.t.sol';
import {WSTETH, ARB, CBETH, RETH, MAGIC} from '@script/GoerliParams.s.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

// forge t --fork-url $URL --match-contract TransferOwnershipAnvil -vvvvv

/**
 * @dev keyword `test` changed to `X` to avoid being run general test
 * change `X_` to `test_` to run tests in this contract
 */

contract TransferOwnershipAnvil is AnvilFork {
  using SafeERC20 for IERC20;

  /**
   * @dev enfore correct setup
   */
  function X_setup() public {
    assertEq(totalVaults, vault721.totalSupply());
    checkProxyAddress();
    checkVaultIds();
  }

  /**
   * @dev unit tests
   */
  function X_unit_transferVault() public {
    uint256 vaultId = 1;
    address owner = vault721.ownerOf(vaultId);
    address proxy = vault721.getProxy(owner);
    uint256 initBal = vault721.balanceOf(owner);
    uint256[] memory safesBefore = safeManager.getSafes(proxy);
    uint256 safesBeforeL = safesBefore.length;
    emit log_named_uint('Safes length', safesBeforeL);

    for (uint256 i = 0; i < safesBeforeL; i++) {
      emit log_named_uint('Safe', safesBefore[i]);
    }

    address reciever = newUsers[0];

    vm.startPrank(owner);
    vault721.transferFrom(owner, reciever, vaultId);
    vm.stopPrank();

    uint256[] memory safesAfter = safeManager.getSafes(owner);
    uint256 safesAfterL = safesAfter.length;
    emit log_named_uint('Safes length', safesAfterL);

    // this fails, but it should pass
    assertEq(safesBeforeL - 1, safesAfterL);

    // reciever should own transfered safe
    assertEq(reciever, vault721.ownerOf(vaultId));

    // owner should still own other safes
    assertEq(owner, vault721.ownerOf(vaultId + 1));
    assertEq(owner, vault721.ownerOf(vaultId + 2));
    assertEq(owner, vault721.ownerOf(vaultId + 3));
    assertEq(owner, vault721.ownerOf(vaultId + 4));

    assertEq(initBal - 1, vault721.balanceOf(owner));
    assertEq(1, vault721.balanceOf(reciever));
  }

  function X_unit_transferVault_toZero_Fail() public {
    uint256 vaultId = 1;
    address owner = vault721.ownerOf(vaultId);
    uint256 initBal = vault721.balanceOf(owner);
    uint256[] memory safesBefore = safeManager.getSafes(owner);
    uint256 safesBeforeL = safesBefore.length;

    address reciever = address(0);

    vm.startPrank(owner);
    vm.expectRevert('ERC721: transfer to the zero address');
    vault721.transferFrom(owner, reciever, vaultId);
    vm.stopPrank();

    uint256[] memory safesAfter = safeManager.getSafes(owner);
    uint256 safesAfterL = safesAfter.length;

    assertEq(safesBeforeL, safesAfterL);
    assertEq(initBal, vault721.balanceOf(owner));

    // owner should still own all safes
    assertEq(owner, vault721.ownerOf(vaultId));
    assertEq(owner, vault721.ownerOf(vaultId + 1));
    assertEq(owner, vault721.ownerOf(vaultId + 2));
    assertEq(owner, vault721.ownerOf(vaultId + 3));
    assertEq(owner, vault721.ownerOf(vaultId + 4));
  }

  /**
   * @dev fuzz tests
   */
  function X_fuzz_transferVault(uint256 vaultId) public {
    vaultId = bound(vaultId, 1, totalVaults - 1);
    address owner = vault721.ownerOf(vaultId);
    address proxy = vault721.getProxy(owner);
    uint256 initBal = vault721.balanceOf(owner);
    uint256[] memory safesBefore = safeManager.getSafes(proxy);
    uint256 safesBeforeL = safesBefore.length;
    emit log_named_uint('Safes length', safesBeforeL);

    for (uint256 i = 0; i < safesBeforeL; i++) {
      emit log_named_uint('Safe', safesBefore[i]);
    }

    address reciever = newUsers[0];

    vm.startPrank(owner);
    vault721.transferFrom(owner, reciever, vaultId);
    vm.stopPrank();

    uint256[] memory safesAfter = safeManager.getSafes(owner);
    uint256 safesAfterL = safesAfter.length;
    emit log_named_uint('Safes length', safesAfterL);

    for (uint256 i = 0; i < safesAfterL; i++) {
      emit log_named_uint('Safe', safesAfter[i]);
    }

    // this fails, but it should pass
    assertEq(safesBeforeL - 1, safesAfterL);

    // reciever should own transfered safe
    assertEq(reciever, vault721.ownerOf(vaultId));

    assertEq(initBal - 1, vault721.balanceOf(owner));
    assertEq(1, vault721.balanceOf(reciever));
  }

  function X_fuzz_transferVault_toZero_Fail(uint256 vaultId) public {
    vaultId = bound(vaultId, 1, totalVaults - 1);
    address owner = vault721.ownerOf(vaultId);
    uint256 initBal = vault721.balanceOf(owner);
    uint256[] memory safesBefore = safeManager.getSafes(owner);
    uint256 safesBeforeL = safesBefore.length;

    address reciever = address(0);

    vm.startPrank(owner);
    vm.expectRevert('ERC721: transfer to the zero address');
    vault721.transferFrom(owner, reciever, vaultId);
    vm.stopPrank();

    uint256[] memory safesAfter = safeManager.getSafes(owner);
    uint256 safesAfterL = safesAfter.length;

    assertEq(safesBeforeL, safesAfterL);
    assertEq(initBal, vault721.balanceOf(owner));
  }
}

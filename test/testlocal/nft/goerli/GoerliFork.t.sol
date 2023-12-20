// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {SepoliaParams, WSTETH, ARB, CBETH, RETH, MAGIC} from '@script/SepoliaParams.s.sol';
import {SepoliaDeployment} from '@script/SepoliaDeployment.s.sol';
import {ODProxy} from '@contracts/proxies/ODProxy.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';
import {MintableERC20} from '@contracts/for-test/MintableERC20.sol';

contract GoerliFork is Test, SepoliaDeployment {
  uint256 private constant MINT_AMOUNT = 1_000_000 ether;

  /// @dev Uint256 representation of 1 RAY
  uint256 constant RAY = 10 ** 27;
  /// @dev Uint256 representation of 1 WAD
  uint256 constant WAD = 10 ** 18;

  uint256 public currSafeId = 1;

  bytes32 public cType = vm.envBytes32('CTYPE_SYM');
  address public cAddr = vm.envAddress('CTYPE_ADDR');

  address public alice = vm.envAddress('ARB_SEPOLIA_PUBLIC1'); // 0x23
  address public bob = vm.envAddress('ARB_SEPOLIA_PUBLIC2'); // 0x37
  address aliceProxy;

  // Tokens
  address public tokenA;
  address public tokenB;

  function setUp() public virtual {
    vm.label(alice, 'Alice');
    vm.label(bob, 'Bob');
    deployTestTokens();
  }

  // --- helper functions ---

  function deployOrFind(address owner) public returns (address) {
    address proxy = vault721.getProxy(owner);
    if (proxy == address(0)) {
      return address(vault721.build(owner));
    } else {
      return proxy;
    }
  }

  function openSafe(bytes32 _cType, address _usr) public returns (uint256 _safeId) {
    address _proxy = deployOrFind(_usr);
    bytes memory payload = abi.encodeWithSelector(basicActions.openSAFE.selector, address(safeManager), _cType, _proxy);
    bytes memory safeData = ODProxy(_proxy).execute(address(basicActions), payload);
    _safeId = abi.decode(safeData, (uint256));
  }

  function depositCollatAndGenDebt(
    bytes32 _cType,
    uint256 _safeId,
    uint256 _collatAmount,
    uint256 _deltaWad,
    address _proxy
  ) public {
    bytes memory payload = abi.encodeWithSelector(
      basicActions.lockTokenCollateralAndGenerateDebt.selector,
      address(safeManager),
      address(taxCollector),
      address(collateralJoin[_cType]),
      address(coinJoin),
      _safeId,
      _collatAmount,
      _deltaWad
    );
    ODProxy(_proxy).execute(address(basicActions), payload);
  }

  function deployTestTokens() public {
    MintableERC20 token0 = new MintableERC20('LST Test1', 'WSTETH', 18);
    MintableERC20 token1 = new MintableERC20('LST Test2', 'ARB', 18);
    token0.mint(alice, MINT_AMOUNT);
    token1.mint(bob, MINT_AMOUNT);
    tokenA = address(token0);
    tokenB = address(token1);
  }
}

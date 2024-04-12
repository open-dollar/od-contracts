// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

//solhint-disable

import 'forge-std/Script.sol';
import 'forge-std/console2.sol';

contract ForkManagement is Script {
  using stdJson for string;

  error UnrecognizedChainId();

  string public json;
  uint256 public privateKey;
  address public proposer;
  uint256 public chainId;
  string public network;
  string public path;

  function _loadPrivateKeys() internal {
    if (block.chainid == 421_614) {
      privateKey = vm.envUint('ARB_SEPOLIA_DEPLOYER_PK');
      proposer = vm.addr(privateKey);
    } else if (block.chainid == 42_161) {
      privateKey = vm.envUint('ARB_MAINNET_DEPLOYER_PK');
      proposer = vm.addr(privateKey);
    } else if (block.chainid == 31_337) {
      privateKey = vm.envUint('ANVIL_ONE');
      proposer = vm.addr(privateKey);
    } else {
      revert UnrecognizedChainId();
    }

    console2.log('\n');
    console2.log('Proposer address:', proposer);
    console2.log('Proposer balance:', proposer.balance);
  }

  function _loadJson(string memory _path) internal returns (string memory) {
    string memory root = vm.projectRoot();
    path = string(abi.encodePacked(root, _path));
    json = vm.readFile(path);
    return json;
  }

  function _checkNetworkParams() internal {
    network = json.readString(string(abi.encodePacked('.network')));
    chainId = json.readUint(string(abi.encodePacked('.chainid')));
    console2.log('Target environment:', network);
    console2.log('Network:', network);
    console2.log('ChainId:', chainId);
    if (block.chainid != chainId) revert('Wrong chainid');
  }
}

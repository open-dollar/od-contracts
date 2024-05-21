// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

//solhint-disable

import 'forge-std/Script.sol';
import {ForkManagement} from '@script/gov/helpers/ForkManagement.s.sol';
import 'forge-std/console2.sol';

contract Generator is ForkManagement {
  using stdJson for string;

  string public _version = 'version 0.1';

  function _loadBaseData(string memory json) internal virtual {
    // empty
  }

  function run(string memory _filePath) public {
    _loadJson(_filePath);
    _loadPrivateKeys();
    _loadBaseData(json);
    _network = json.readString(string(abi.encodePacked('.network')));
    if (json.readUint(string(abi.encodePacked('.chainid'))) == 421_614) {
      vm.createSelectFork(vm.rpcUrl('sepolia'));
    } else {
      vm.createSelectFork(vm.rpcUrl('mainnet'));
    }

    _generateProposal();
  }

  function _generateProposal() internal virtual {
    // empty
  }
}

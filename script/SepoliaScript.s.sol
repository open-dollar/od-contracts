// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import '@script/Contracts.s.sol';
import {Script, console} from 'forge-std/Script.sol';
import {Params, ParamChecker, WSTETH, ARB} from '@script/Params.s.sol';
import {Common} from '@script/Common.s.sol';
import {SepoliaDeployment} from '@script/SepoliaDeployment.s.sol';
import '@script/Registry.s.sol';

/**
 * @title  SepoliaScript
 * @notice This contract is used to deploy the system on Goerli
 * @dev    This contract imports deployed addresses from `SepoliaDeployment.s.sol`
 * @dev    Mainnet has no scripting implementation (shouldn't be used with EOAs)
 */
contract SepoliaScript is SepoliaDeployment, Common, Script {
  function setUp() public virtual {
    _governorPK = uint256(vm.envBytes32('GOERLI_GOVERNOR_PK'));
    chainId = 421_614;
  }

  /**
   * @notice This script is left as an example on how to use SepoliaScript contract
   * @dev    This script is executed with `yarn script:sepolia` command
   */
  function run() public {
    _getEnvironmentParams();

    address _governor = vm.addr(_governorPK);
    require(_governor == governor || _governor == delegate);
    vm.startBroadcast(_governor);

    // Script goes here

    vm.stopBroadcast();
  }
}

contract GoerliDelegate is SepoliaDeployment, Common, Script {
  function setUp() public virtual {
    _governorPK = uint256(vm.envBytes32('GOERLI_GOVERNOR_PK'));
    chainId = 421_614;
  }

  function run() public {
    _getEnvironmentParams();

    address _governor = vm.addr(_governorPK);
    require(_governor == governor);
    vm.startBroadcast(_governor);

    _delegateAllTo(delegate);

    vm.stopBroadcast();
  }
}

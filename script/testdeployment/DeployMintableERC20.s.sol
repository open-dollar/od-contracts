// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {Script} from 'forge-std/Script.sol';
import {MintableERC20} from '@contracts/for-test/MintableERC20.sol';
import {OracleForTestnet} from '@contracts/for-test/OracleForTestnet.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {SepoliaDeployment} from '@script/SepoliaDeployment.s.sol';
import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import 'forge-std/console2.sol';

// BROADCAST
// source .env && forge script DeployMintableERC20Sepolia --skip-simulation --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify --etherscan-api-key $ARB_ETHERSCAN_API_KEY

// SIMULATE
// source .env && forge script DeployMintableERC20Sepolia --with-gas-price 2000000000 -vvvvv --rpc-url $ARB_SEPOLIA_RPC

contract DeployMintableERC20Sepolia is SepoliaDeployment, Script {
  function run() public {
    vm.startBroadcast(vm.envUint('ARB_SEPOLIA_DEPLOYER_PK'));
    string memory symbol = 'pufETH';
    string memory collateralName = 'Puffer ETH';
    address newMintable = address(new MintableERC20(collateralName, symbol, 18));
    address newOracle = address(new OracleForTestnet(3500e18));
    address delayedOracle = address(delayedOracleFactory.deployDelayedOracle(IBaseOracle(newOracle), 60));
    MintableERC20(newMintable).mint(100_000 ether);
    console2.log('New Mintable: ', newMintable);
    console2.log('New Oracle: ', newOracle);
    console2.log('New Delayed Oracle: ', delayedOracle);
    console2.log('New Collateral Name: ', collateralName);
    console2.log('New Collateral Type: ', symbol);
    vm.stopBroadcast();
  }
}

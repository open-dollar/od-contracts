// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Script, console2 } from "forge-std/Script.sol";

import { GrailTokenV2 } from "@contracts/for-test/CamelotDex/GrailTokenV2.sol";
import { XGrailToken } from "@contracts/for-test/CamelotDex/XGrailToken.sol";

import { CamelotMaster } from "@contracts/for-test/CamelotDex/CamelotMaster.sol";
import { NFTPoolFactory } from "@contracts/for-test/CamelotDex/NFTPoolFactory.sol";

import { NFTPool } from "@contracts/for-test/CamelotDex/NFTPool.sol";

// forge script script/DeployCamelotDex.s.sol:DeployCamelotDex --rpc-url $ARB_SEPOLIA_RPC --broadcast --verify -vvvv
/**
 * @title DeployCamelotDex
 * @dev Deploy CamelotDex contracts to any network
 * @notice This deployment is to be used for testing purposes only
 */
contract DeployCamelotDex is Script {

	function setUp() public { }

	function run() public {
		uint256 deployerPrivateKey = vm.envUint("ARB_SEPOLIA_DEPLOYER_PK");
		address deployerAddress = vm.addr(deployerPrivateKey);
		uint256 _now = block.timestamp;
		vm.startBroadcast(deployerPrivateKey);
		console2.log("Deploying CamelotDex contracts...");
		console2.log("Deployer address: ", deployerAddress);


		GrailTokenV2 grailToken = new GrailTokenV2(
			100000000000000000000000, // as saw in arbitrum
			72500000000000000000000, // as saw in arbitrum
			153240740740741, // as saw in arbitrum
			deployerAddress
		);
		console2.log("GrailTokenV2 deployed at: ", address(grailToken));
		// add 10 minutes to the current time
		_now = _now + 600;
		grailToken.initializeEmissionStart(_now);
		console2.log("GrailTokenV2 emission started at: ", _now);

		XGrailToken xGrailToken = new XGrailToken(grailToken);
		console2.log("XGrailToken deployed at: ", address(xGrailToken));

		CamelotMaster camelotMaster = new CamelotMaster(grailToken,_now);

		NFTPoolFactory nftPoolFactory = new NFTPoolFactory(camelotMaster, grailToken, xGrailToken);
		console2.log("NFTPoolFactory deployed at: ", address(nftPoolFactory));

	}
}
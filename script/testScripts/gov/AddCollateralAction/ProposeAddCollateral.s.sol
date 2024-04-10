// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {JSONScript} from '@script/testScripts/gov/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {IGlobalSettlement} from '@contracts/settlement/GlobalSettlement.sol';
import {ICollateralJoinFactory} from '@interfaces/factories/ICollateralJoinFactory.sol';
import {ICollateralAuctionHouseFactory} from '@interfaces/factories/ICollateralAuctionHouseFactory.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import 'forge-std/StdJson.sol';
import 'forge-std/console2.sol';

/// @title ProposeAddCollateral Script
/// @author OpenDollar
/// @notice Script to propose adding a new collateral type to the system via ODGovernance
/// @dev This script is used to propose adding a new collateral type to the system
/// @dev The script will propose a deployment of new CollateralJoin and CollateralAuctionHouse contracts
/// @dev The script will output a JSON file with the proposal data to be used by the QueueProposal and ExecuteProposal scripts
/// @dev In the root, run: export FOUNDRY_PROFILE=governance && forge script --rpc-url <RPC_URL> script/testScripts/gov/AddCollateralAction/ProposeAddCollateral.s.sol
contract ProposeAddCollateral is JSONScript {
  using stdJson for string;

  address public governanceAddress;
  address public globalSettlementAddress;
  bytes32 public newCType;
  address public newCAddress;
  uint256 public minimumBid;
  uint256 public minDiscount;
  uint256 public maxDiscount;
  uint256 public perSecondDiscountUpdateRate;

  function _loadBaseData(string memory json) internal {
    governanceAddress = json.readAddress(string(abi.encodePacked('.ODGovernor')));
    globalSettlementAddress = json.readAddress(string(abi.encodePacked('.GlobalSettlement')));
    newCType = bytes32(abi.encodePacked(json.readString(string(abi.encodePacked('.NewCollateralType')))));
    newCAddress = json.readAddress(string(abi.encodePacked('.NewCollateralAddress')));
    minimumBid = json.readUint(string(abi.encodePacked('.MinimumBid')));
    minDiscount = json.readUint(string(abi.encodePacked('.MinimumDiscount')));
    maxDiscount = json.readUint(string(abi.encodePacked('.MaximumDiscount')));
    perSecondDiscountUpdateRate = json.readUint(string(abi.encodePacked('.PerSecondDiscountUpdateRate')));
  }

  function run(string memory json) public {
    _loadBaseData(json);
    ODGovernor gov = ODGovernor(payable(governanceAddress));
    IGlobalSettlement globalSettlement = IGlobalSettlement(globalSettlementAddress);

    string memory stringCAddress = vm.toString(newCAddress);
    string memory stringCType = vm.toString(newCType);

    // Get target contract addresses from GlobalSettlement:
    //  - CollateralJoinFactory
    //  - CollateralAuctionHouseFactory note why is this address also a target?
    address[] memory targets = new address[](1);
    {
      targets[0] = address(globalSettlement.collateralJoinFactory());
      // targets[1] = address(globalSettlement.collateralAuctionHouseFactory());
    }
    // No values needed
    uint256[] memory values = new uint256[](1);
    {
      values[0] = 0;
      // values[1] = 0;
    }
    // Get calldata for:
    //  - CollateralJoinFactory.deployCollateralJoin
    bytes[] memory calldatas = new bytes[](1);
    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahCParams = ICollateralAuctionHouse
      .CollateralAuctionHouseParams({
      minimumBid: minimumBid,
      minDiscount: minDiscount,
      maxDiscount: maxDiscount,
      perSecondDiscountUpdateRate: perSecondDiscountUpdateRate
    });
    calldatas[0] = abi.encodeWithSelector(ICollateralJoinFactory.deployCollateralJoin.selector, newCType, newCAddress);

    // Get the description and descriptionHash
    string memory description = 'Add collateral to the system';
    bytes32 descriptionHash = keccak256(bytes(description));

    vm.startBroadcast(vm.envUint('GOV_EXECUTOR_PK'));

    // Propose the action to add the collateral type
    uint256 proposalId = gov.propose(targets, values, calldatas, description);
    string memory stringProposalId = vm.toString(proposalId);

    // Verify the proposalId is expected
    assert(proposalId == gov.hashProposal(targets, values, calldatas, descriptionHash));

    {
      // Build the JSON output
      string memory objectKey = 'PROPOSE_ADD_COLLATERAL_KEY';
      vm.serializeString(objectKey, 'newCollateralAddress', stringCAddress);
      vm.serializeString(objectKey, 'newCollateralType', stringCType);
      string memory jsonOutput =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, description, descriptionHash);
      vm.writeJson(jsonOutput, string.concat('./gov-output/', stringProposalId, '-add-collateral-proposal.json'));
    }

    // Expected JSON output:
    // {
    //   "proposalId": uint256,
    //   "newCollateralAddress": string,
    //   "newCollateralType": bytes32,
    //   "targets": address[],
    //   "values": uint256[]
    //   "calldatas": bytes[],
    //   "description": string,
    //   "descriptionHash": bytes32,
    // }

    vm.stopBroadcast();
  }
}

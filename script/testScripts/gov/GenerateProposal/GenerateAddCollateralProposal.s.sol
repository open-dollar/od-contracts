// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {JSONScript} from '@script/testScripts/gov/helpers/JSONScript.s.sol';
import {ODGovernor} from '@contracts/gov/ODGovernor.sol';
import {GenerateProposal} from '../GenerateProposal.s.sol';
import {IGlobalSettlement} from '@contracts/settlement/GlobalSettlement.sol';
import {ICollateralJoinFactory} from '@interfaces/factories/ICollateralJoinFactory.sol';
import {ICollateralAuctionHouseFactory} from '@interfaces/factories/ICollateralAuctionHouseFactory.sol';
import {IModifiablePerCollateral} from '@interfaces/utils/IModifiablePerCollateral.sol';
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
contract GenerateAddCollateralProposal is GenerateProposal, JSONScript {
  using stdJson for string;

  string public objectKey = 'PROPOSE_ADD_COLLATERAL_KEY';
  address public governanceAddress;
  address public globalSettlementAddress;
  bytes32 public newCType;
  address public newCAddress;
  uint256 public minimumBid;
  uint256 public minDiscount;
  uint256 public maxDiscount;
  uint256 public perSecondDiscountUpdateRate;
  string public description;
  string public proposalType;

  function _loadBaseData(string memory json) internal override {
    proposalType = json.readString(string(abi.encodePacked('.proposalType')));
    governanceAddress = json.readAddress(string(abi.encodePacked('.odGovernor')));
    globalSettlementAddress = json.readAddress(string(abi.encodePacked('.globalSettlement')));
    newCType = bytes32(abi.encodePacked(json.readString(string(abi.encodePacked('.newCollateralType')))));
    newCAddress = json.readAddress(string(abi.encodePacked('.newCollateralAddress')));
    minimumBid = json.readUint(string(abi.encodePacked('.minimumBid')));
    minDiscount = json.readUint(string(abi.encodePacked('.minimumDiscount')));
    maxDiscount = json.readUint(string(abi.encodePacked('.maximumDiscount')));
    perSecondDiscountUpdateRate = json.readUint(string(abi.encodePacked('.perSecondDiscountUpdateRate')));
    description = json.readString(string(abi.encodePacked('.description')));
  }

  function _generateProposal() internal override {
    ODGovernor gov = ODGovernor(payable(governanceAddress));
    console2.log(gov.quorumDenominator());
    IGlobalSettlement globalSettlement = IGlobalSettlement(globalSettlementAddress);
    // Get target contract addresses from GlobalSettlement:
    //  - CollateralJoinFactory
    //  - CollateralAuctionHouseFactory note why is this address also a target?
    address[] memory targets = new address[](2);
    {
      targets[0] = address(globalSettlement.collateralJoinFactory());
      targets[1] = address(globalSettlement.collateralAuctionHouseFactory());
    }
    // No values needed
    uint256[] memory values = new uint256[](2);
    {
      values[0] = 0;
      values[1] = 0;
    }
    // Get calldata for:
    //  - CollateralJoinFactory.deployCollateralJoin
    bytes[] memory calldatas = new bytes[](2);
    ICollateralAuctionHouse.CollateralAuctionHouseParams memory _cahCParams = ICollateralAuctionHouse
      .CollateralAuctionHouseParams({
      minimumBid: minimumBid,
      minDiscount: minDiscount,
      maxDiscount: maxDiscount,
      perSecondDiscountUpdateRate: perSecondDiscountUpdateRate
    });
    calldatas[0] = abi.encodeWithSelector(ICollateralJoinFactory.deployCollateralJoin.selector, newCType, newCAddress);
    calldatas[1] =
      abi.encodeWithSelector(IModifiablePerCollateral.initializeCollateralType.selector, newCType, _cahCParams);
    // Get the descriptionHash
    bytes32 descriptionHash = keccak256(bytes(description));

    vm.startBroadcast(privateKey);

    // Propose the action to add the collateral type
    uint256 proposalId = gov.hashProposal(targets, values, calldatas, descriptionHash);
    string memory stringProposalId = vm.toString(proposalId / 10 ** 69);

    {
      // Build the JSON output
      string memory builtProp =
        _buildProposalParamsJSON(proposalId, objectKey, targets, values, calldatas, description, descriptionHash);
      vm.writeJson(
        builtProp, string.concat('./gov-output/', network, '/', stringProposalId, '-add-collateral-proposal.json')
      );
    }

    vm.stopBroadcast();
  }

  function _serializeCurrentJson(string memory _objectKey) internal override returns (string memory _serializedInput) {
    _serializedInput = vm.serializeJson(_objectKey, json);
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import 'forge-std/Test.sol';
import {AnvilDeployment} from '@testlocal/nft/anvil/deployment/AnvilDeployment.t.sol';

import {IDenominatedOracle} from '@interfaces/oracles/IDenominatedOracle.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';
import {OracleForTestnet} from '@contracts/for-test/OracleForTestnet.sol';

/**
 * @dev to run local tests on Anvil network:
 *
 * anvil
 * yarn deploy:anvil
 *
 * forge t --fork-url http://127.0.0.1:8545  --match-contract ContractToTest -vvvvv
 */
contract AnvilFork is AnvilDeployment, Test {
  // Anvil wallets w/ 10_000 ether
  address public constant ALICE = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266; // deployer
  address public constant BOB = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
  address public constant DAN = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
  address public constant ERICA = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;

  mapping(address proxy => mapping(bytes32 cType => uint256 id)) public vaultIds;

  address[2] public users;
  address[2] public newUsers;

  IDenominatedOracle[] public denominatedOracles;
  IDelayedOracle[] public delayedOracles;
  OracleForTestnet[] public oraclesForTest;

  function setUp() public virtual {
    users[0] = ALICE;
    users[1] = BOB;

    newUsers[0] = DAN;
    newUsers[1] = ERICA;

    denominatedOracles.push(IDenominatedOracle(DenominatedOracleChild_10_Address));
    denominatedOracles.push(IDenominatedOracle(DenominatedOracleChild_12_Address));
    denominatedOracles.push(IDenominatedOracle(DenominatedOracleChild_14_Address));

    delayedOracles.push(IDelayedOracle(DelayedOracleChild_15_Address));
    delayedOracles.push(IDelayedOracle(DelayedOracleChild_16_Address));
    delayedOracles.push(IDelayedOracle(DelayedOracleChild_17_Address));
    delayedOracles.push(IDelayedOracle(DelayedOracleChild_18_Address));

    oraclesForTest.push(OracleForTestnet(address(denominatedOracles[0].denominationPriceSource())));

    for (uint256 i; i < denominatedOracles.length; i++) {
      oraclesForTest.push(OracleForTestnet(address(denominatedOracles[i].priceSource())));
    }
  }
}

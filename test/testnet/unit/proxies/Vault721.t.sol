// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {HaiTest, stdStorage, StdStorage} from '@testnet/utils/HaiTest.t.sol';
import {Vault721, HashState} from '@contracts/proxies/Vault721.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';

contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address owner = label('owner');
  address user = address(0xdeadce11);
  // address userProxy;

  Vault721 vault721;
  NFTRenderer renderer;
  ODSafeManager safeManager;
  TimelockController timelockController;

  function setUp() public virtual {
    vm.startPrank(deployer);

    vault721 = new Vault721();
    label(address(vault721), 'Vault721');

    renderer = NFTRenderer(mockContract('nftRenderer'));
    safeManager = ODSafeManager(mockContract('SafeManager'));
    timelockController = TimelockController(payable(mockContract('timeLockController')));

    vm.stopPrank();
  }
}

contract Unit_Vault721_Initialize is Base {
  modifier safeManagerPath() {
    vm.startPrank(address(safeManager));
    _;
  }

  function testInitialize() public {
    vault721.initialize(address(timelockController));
  }

  function testInitSafeManager() public safeManagerPath {
    vault721.initializeManager();
  }

  function testInitNftRenderer() public safeManagerPath {
    vault721.initializeRenderer();
  }

  function testInitializeZeroFail() public {
    vm.expectRevert(IVault721.ZeroAddress.selector);
    vault721.initialize(address(0));
  }

  function testInitializeMultiInitFail() public {
    vault721.initialize(address(timelockController));
    vm.expectRevert(bytes('Initializable: contract is already initialized'));
    vault721.initialize(address(timelockController));
  }
}

contract Unit_Vault721_Build is Base {
  function test_Build_NoUser() public {
    vm.prank(owner);
    address builtProxy = vault721.build();
    address proxy = vault721.getProxy(owner);
    assertEq(proxy, builtProxy, 'incorrect proxy address');
  }

  function test_Build_User() public {
    address builtProxy = vault721.build(owner);
    address proxy = vault721.getProxy(owner);
    assertEq(proxy, builtProxy, 'incorrect proxy address');
  }

  function test_Build_Revert_ProxyAlreadyExists() public {
    vm.startPrank(owner);
    //build first vault
    vault721.build();

    vm.expectRevert(IVault721.ProxyAlreadyExist.selector);
    //build second vault to revert
    vault721.build();
  }
}

contract Unit_Vault721_Mint is Base {
  address userProxy;

  function setUp() public override {
    Base.setUp();
    vault721.initialize(address(timelockController));
    vm.prank(address(safeManager));
    vault721.initializeManager();

    userProxy = vault721.build(user);
  }

  function test_Mint() public {
    vm.prank(address(safeManager));
    vault721.mint(userProxy, 0);
  }

  function test_Mint_Revert_NonNativeProxy() public {
    vm.prank(address(safeManager));
    vm.expectRevert('V721: non-native proxy');
    vault721.mint(user, 0);
  }
}

contract Vault721_ViewFunctions is Base {
  address userProxy;

  function setUp() public override {
    Base.setUp();
    vault721.initialize(address(timelockController));
    vm.prank(address(renderer));
    vault721.initializeRenderer();
    vm.prank(address(safeManager));
    vault721.initializeManager();

    userProxy = vault721.build(user);
  }

  function test_GetProxy() public {
    address _userProxy = vault721.getProxy(user);
    assertEq(_userProxy, userProxy, 'incorrect proxy gotten');
  }

  function test_GetIsAllowlisted() public {
    vm.prank(address(timelockController));
    vault721.updateAllowlist(address(user), true);
    bool allowlisted = vault721.getIsAllowlisted(address(user));
    assertTrue(allowlisted, 'user not allowed');
  }

  function test_GetHashState() public {
    vm.mockCall(
      address(renderer),
      abi.encodeWithSelector(NFTRenderer.getStateHashBySafeId.selector),
      abi.encode(bytes32(keccak256('testHash')))
    );

    vm.prank(address(safeManager));
    vault721.updateVaultHashState(1);

    HashState memory hashState = vault721.getHashState(1);

    assertEq(hashState.lastBlockNumber, block.number, 'incorrect block number');
    assertEq(hashState.lastBlockTimestamp, block.timestamp, 'incorrect time stamp');
  }

  function test_ContractURI() public {
    string memory contractURI = vault721.contractURI();
    assertEq(
      contractURI,
      'data:application/json;utf8,{"name": "Open Dollar Vaults","description": "Open Dollar is a DeFi lending protocol that enables borrowing against liquid staking tokens while earning staking rewards and enabling liquidity via Non-Fungible Vaults (NFVs).","image": "https://app.opendollar.com/collectionImage.png","external_link": "https://opendollar.com"}',
      'incorrect returned string'
    );
  }

  function test_TokenURI() public {
    address _userProxy = vault721.build(address(1));

    vm.prank(address(safeManager));
    vault721.mint(_userProxy, 1);

    //mock call for test
    vm.mockCall(address(renderer), abi.encodeWithSelector(NFTRenderer.render.selector), abi.encode('testURI'));

    string memory tokenURI = vault721.tokenURI(1);

    assertEq(tokenURI, 'testURI', 'incorrect token uri');
  }
}

contract Unit_Vault721_UpdateVaultHashState is Base {
  address userProxy;

  function setUp() public override {
    Base.setUp();
    vault721.initialize(address(timelockController));
    vm.prank(address(renderer));
    vault721.initializeRenderer();
    vm.prank(address(safeManager));
    vault721.initializeManager();

    userProxy = vault721.build(user);
  }

  function test_UpdateHashState() public {
    vm.mockCall(
      address(renderer),
      abi.encodeWithSelector(NFTRenderer.getStateHashBySafeId.selector),
      abi.encode(bytes32(keccak256('testHash')))
    );

    vm.prank(address(safeManager));
    vault721.updateVaultHashState(1);

    HashState memory hashState = vault721.getHashState(1);

    assertEq(hashState.lastBlockNumber, block.number, 'incorrect block number');
    assertEq(hashState.lastBlockTimestamp, block.timestamp, 'incorrect time stamp');
    assertEq(hashState.lastHash, bytes32(keccak256('testHash')), 'incorrect hash');
  }

  function test_UpdateHashState_Revert_OnlySafeManager() public {
    vm.expectRevert(Vault721.NotSafeManager.selector);

    vm.prank(address(user));
    vault721.updateVaultHashState(1);
  }
}

contract Unit_Vault721_GovernanceFunctions is Base {
  struct Scenario {
    address nftRenderer;
    address oracleRelayer;
    address taxCollector;
    address collateralJoinFactory;
    address user;
    address rando;
  }

  function setUp() public override {
    Base.setUp();
    vault721.initialize(address(timelockController));
    vm.prank(address(renderer));
    vault721.initializeRenderer();
    vm.prank(address(safeManager));
    vault721.initializeManager();
  }

  modifier happyPath(Scenario memory _scenario) {
    vm.assume(_scenario.nftRenderer != address(0));
    vm.assume(_scenario.oracleRelayer != address(0));
    vm.assume(_scenario.taxCollector != address(0));
    vm.assume(_scenario.collateralJoinFactory != address(0));
    vm.assume(_scenario.user != address(0));
    address[4] memory contractAddresses =
      [address(renderer), address(vault721), address(timelockController), address(safeManager)];
    for (uint256 i; i < contractAddresses.length; i++) {
      vm.assume(_scenario.user != contractAddresses[i]);
      vm.assume(_scenario.rando != contractAddresses[i]);
    }
    _;
  }

  function _mintNft(Scenario memory _scenario) internal returns (address _userProxy) {
    _userProxy = vault721.build(_scenario.user);

    vm.prank(address(safeManager));
    vault721.mint(_userProxy, 1);
  }

  function test_UpdateNFTRenderer(Scenario memory _scenario) public happyPath(_scenario) {
    vm.prank(address(timelockController));
    vm.mockCall(
      address(_scenario.nftRenderer), abi.encodeWithSelector(NFTRenderer.setImplementation.selector), abi.encode()
    );
    vault721.updateNftRenderer(
      _scenario.nftRenderer, _scenario.oracleRelayer, _scenario.taxCollector, _scenario.collateralJoinFactory
    );
  }

  function test_UpdateNFTRenderer_Revert_OnlyGovernance() public {
    vm.mockCall(address(renderer), abi.encodeWithSelector(NFTRenderer.setImplementation.selector), abi.encode());
    vm.prank(address(user));
    vm.expectRevert(Vault721.NotGovernor.selector);
    vault721.updateNftRenderer(address(1), address(1), address(1), address(1));
  }

  function test_UpdateNFTRenderer_Revert_ZeroAddress(Scenario memory _scenario) public {
    vm.mockCall(address(renderer), abi.encodeWithSelector(NFTRenderer.setImplementation.selector), abi.encode());
    vm.prank(address(timelockController));
    vm.expectRevert(Vault721.ZeroAddress.selector);
    vault721.updateNftRenderer(
      address(0), _scenario.oracleRelayer, _scenario.taxCollector, _scenario.collateralJoinFactory
    );
  }

  function test_UpdateAllowList(Scenario memory _scenario) public happyPath(_scenario) {
    _mintNft(_scenario);
    vm.prank(address(timelockController));
    vault721.updateAllowlist(_scenario.user, true);

    vm.warp(block.timestamp + 100_000);

    vm.mockCall(
      address(renderer), abi.encodeWithSelector(NFTRenderer.getStateHashBySafeId.selector), abi.encode(bytes32(0))
    );

    vm.prank(_scenario.user);
    // transfer token to verify allowlist was updated since there's no view function
    vault721.transferFrom(_scenario.user, owner, 1);

    assertEq(vault721.balanceOf(owner), 1, 'transfer not succesful');
  }

  function test_UpdateTimeDelay(Scenario memory _scenario, uint256 timeDelay) public happyPath(_scenario) {
    _mintNft(_scenario);

    vm.assume(timeDelay > 0);
    vm.assume(notUnderOrOverflowAdd(timeDelay, int256(block.timestamp)));

    vm.prank(address(timelockController));
    vault721.updateTimeDelay(timeDelay);
    //update vault hash state so there's a time to check against
    vm.prank(address(safeManager));
    vm.mockCall(
      address(renderer),
      abi.encodeWithSelector(NFTRenderer.getStateHashBySafeId.selector),
      abi.encode(bytes32('test-hash'))
    );
    vault721.updateVaultHashState(1);

    vm.prank(_scenario.user);
    vault721.setApprovalForAll(_scenario.rando, true);

    vm.prank(_scenario.rando);
    // transfer token from rando to verify timeDelay was updated since there's no view function
    vm.expectRevert(Vault721.TimeDelayNotOver.selector);
    vm.mockCall(
      address(renderer),
      abi.encodeWithSelector(NFTRenderer.getStateHashBySafeId.selector),
      abi.encode(bytes32('test-hash'))
    );
    vault721.transferFrom(_scenario.user, owner, 1);

    vm.warp(block.timestamp + timeDelay);
    vm.prank(_scenario.user);
    vault721.setApprovalForAll(_scenario.rando, true);

    vm.prank(_scenario.rando);
    vm.mockCall(
      address(renderer),
      abi.encodeWithSelector(NFTRenderer.getStateHashBySafeId.selector),
      abi.encode(bytes32('test-hash'))
    );
    vault721.transferFrom(_scenario.user, owner, 1);

    assertEq(vault721.balanceOf(owner), 1, 'transfer not succesful');
  }

  function test_UpdateBlockDelay(Scenario memory _scenario, uint8 blockDelay) public happyPath(_scenario) {
    // hardcode previous hash into mock call for test
    bytes32 previousHashState = 0x0508bed9fd4f78f10478c995115fdf0b087b42d661e8c6f27710c035187b029b;
    _mintNft(_scenario);
    vm.assume(notUnderOrOverflowAdd(blockDelay, int256(block.number)));

    vm.prank(address(timelockController));
    vault721.updateBlockDelay(blockDelay);

    //add to allow list so that block delay will be checked
    vm.prank(address(timelockController));
    vault721.updateAllowlist(_scenario.user, true);

    //update hash state with hardcoded value.

    vm.mockCall(
      address(renderer),
      abi.encodeWithSelector(NFTRenderer.getStateHashBySafeId.selector),
      abi.encode(previousHashState)
    );

    vm.prank(address(safeManager));
    vault721.updateVaultHashState(1);

    // transfer token to verify blockDelay was updated since there's no view function

    //advance to correct block
    vm.roll(block.number + blockDelay + 1);

    vm.prank(_scenario.user);
    vm.mockCall(
      address(renderer),
      abi.encodeWithSelector(NFTRenderer.getStateHashBySafeId.selector),
      abi.encode(bytes32(previousHashState))
    );

    vault721.transferFrom(_scenario.user, owner, 1);

    assertEq(vault721.balanceOf(owner), 1, 'transfer not succesful');
  }

  function test_UpdateContractURI() public {
    vm.prank(address(timelockController));
    vault721.updateContractURI('testURI');
    assertEq(vault721.contractURI(), 'data:application/json;utf8,testURI', 'incorrect uri');
  }

  function test_SetSafeManager() public {
    vm.prank(address(timelockController));
    vault721.setSafeManager(address(1));
    assertEq(address(vault721.safeManager()), address(1), 'incorrect safe manager');
  }

  function test_SetNftRenderer() public {
    vm.prank(address(timelockController));
    vault721.setNftRenderer(address(1));
    assertEq(address(vault721.nftRenderer()), address(1), 'incorrect address set');
  }
}

contract Unit_Vault721_TransferFrom is Base {
  address userProxy;

  struct Scenario {
    address user1;
    address user2;
    uint256 tokenId;
    uint8 blockDelay;
    uint256 timeDelay;
  }

  function setUp() public override {
    Base.setUp();
    vault721.initialize(address(timelockController));
    vm.prank(address(renderer));
    vault721.initializeRenderer();
    vm.prank(address(safeManager));
    vault721.initializeManager();
  }

  modifier basicLimits(Scenario memory _scenario) {
    vm.assume(_scenario.user1 != address(0));
    vm.assume(_scenario.user2 != address(0));
    vm.assume(_scenario.tokenId != uint256(0));
    vm.assume(_scenario.blockDelay > 0);
    vm.assume(_scenario.timeDelay > 0);
    vm.assume(_scenario.timeDelay < 9_000_000_000);
    vm.assume(notUnderOrOverflowAdd(_scenario.blockDelay, int256(block.number)));
    vm.assume(notUnderOrOverflowAdd(_scenario.timeDelay, int256(block.timestamp)));
    address[5] memory contractAddresses =
      [address(vault721), address(renderer), address(safeManager), address(timelockController), address(userProxy)];
    for (uint256 i; i < contractAddresses.length; i++) {
      vm.assume(_scenario.user1 != contractAddresses[i]);
      vm.assume(_scenario.user2 != contractAddresses[i]);
    }
    vm.assume(_scenario.user1 != _scenario.user2);
    _;
  }

  function _mintNft(Scenario memory _scenario) internal returns (address _userProxy) {
    _userProxy = vault721.build(_scenario.user1);

    vm.prank(address(safeManager));
    vault721.mint(_userProxy, _scenario.tokenId);
  }

  function test_TransferFrom(Scenario memory _scenario) public basicLimits(_scenario) {
    userProxy = _mintNft(_scenario);
    vm.assume(_scenario.user1 != userProxy);
    vm.assume(_scenario.user2 != userProxy);
    vault721.build(_scenario.user2);
    vm.prank(_scenario.user1);
    vault721.setApprovalForAll(_scenario.user2, true);

    vm.prank(_scenario.user2);
    vm.mockCall(
      address(renderer), abi.encodeWithSelector(NFTRenderer.getStateHashBySafeId.selector), abi.encode(bytes32(0))
    );

    vault721.transferFrom(_scenario.user1, _scenario.user2, _scenario.tokenId);
  }

  function test_TransferFrom_Revert_BlockDelayNotReached(Scenario memory _scenario) public basicLimits(_scenario) {
    _mintNft(_scenario);
    bytes32 previousHashState = vault721.getHashState(_scenario.tokenId).lastHash;

    vm.prank(address(timelockController));
    vault721.updateBlockDelay(_scenario.blockDelay);

    //add to allow list so that block delay will be checked
    vm.prank(address(timelockController));
    vault721.updateAllowlist(_scenario.user1, true);

    //update hash state with hardcoded value.

    vm.mockCall(
      address(renderer),
      abi.encodeWithSelector(NFTRenderer.getStateHashBySafeId.selector),
      abi.encode(bytes32(previousHashState))
    );

    vm.prank(address(safeManager));

    vault721.updateVaultHashState(_scenario.tokenId);

    vm.prank(_scenario.user1);

    vm.expectRevert(Vault721.BlockDelayNotOver.selector);

    vm.mockCall(
      address(renderer),
      abi.encodeWithSelector(NFTRenderer.getStateHashBySafeId.selector),
      abi.encode(bytes32(previousHashState))
    );

    vault721.transferFrom(_scenario.user1, _scenario.user2, _scenario.tokenId);
    assertEq(vault721.balanceOf(_scenario.user1), 1, 'token transferred');
  }

  function test_TransferFrom_Revert_TimeDelayNotOver(Scenario memory _scenario) public basicLimits(_scenario) {
    _mintNft(_scenario);

    vm.prank(address(timelockController));
    vault721.updateTimeDelay(_scenario.timeDelay);

    //update vault hash state so there's a time to check against
    vm.prank(address(safeManager));
    vm.mockCall(
      address(renderer),
      abi.encodeWithSelector(NFTRenderer.getStateHashBySafeId.selector),
      abi.encode(bytes32('test-hash'))
    );

    vault721.updateVaultHashState(_scenario.tokenId);

    vm.prank(_scenario.user1);
    vault721.setApprovalForAll(_scenario.user2, true);

    vm.prank(_scenario.user2);
    vm.expectRevert(Vault721.TimeDelayNotOver.selector);

    vm.mockCall(
      address(renderer),
      abi.encodeWithSelector(NFTRenderer.getStateHashBySafeId.selector),
      abi.encode(bytes32('test-hash'))
    );
    vault721.transferFrom(_scenario.user1, _scenario.user2, _scenario.tokenId);

    assertEq(vault721.balanceOf(_scenario.user1), 1, 'transfer succesful');
  }
}

contract Unit_Vault721_ProxyDeployment is Base {

  function setUp() public override {
    Base.setUp();
    vault721.initialize(address(timelockController));
    vm.prank(address(renderer));
    vault721.initializeRenderer();
    vm.prank(address(safeManager));
    vault721.initializeManager();
  }

  function test_DeployProxy() public {
    vm.startPrank(owner);
    address proxy = vault721.build();
    assertEq(vault721.getProxy(owner), proxy, 'incorrect proxy address');
  }

  function test_DeployProxy_ForUser() public {
    address proxy = vault721.build(owner);
    assertEq(vault721.getProxy(owner), proxy, 'incorrect proxy address');
  }

  function test_DeployProxy_ProxyAlreadyExists() public {
    //build first vault
    vault721.build();

    vm.expectRevert(IVault721.ProxyAlreadyExist.selector);
    //build second vault to revert
    vault721.build();
  }

  function test_DeployProxy_MultiProxies() public {
    address[] memory users = new address[](10);

    for(uint256 i; i < users.length; i++) {
      users[i] = address(uint160(i + 100));
    }

    address payable[] memory proxies = vault721.build(users);
    assertEq(proxies.length, users.length, 'incorrect proxy length');
    for(uint256 i; i < users.length; i++) {
      assertEq(vault721.getProxy(users[i]), proxies[i], 'incorrect proxy address');
    }
  }

}

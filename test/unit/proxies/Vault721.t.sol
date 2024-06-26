// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ODTest, stdStorage, StdStorage} from '@test/utils/ODTest.t.sol';
import {Vault721} from '@contracts/proxies/Vault721.sol';
import {IVault721} from '@interfaces/proxies/IVault721.sol';
import {TestVault721} from '@contracts/for-test/TestVault721.sol';
import {SCWallet, Bad_SCWallet} from '@contracts/for-test/SCWallet.sol';
import {ODSafeManager} from '@contracts/proxies/ODSafeManager.sol';
import {SAFEEngine, ISAFEEngine} from '@contracts/SAFEEngine.sol';
import {NFTRenderer} from '@contracts/proxies/NFTRenderer.sol';
import {TimelockController} from '@openzeppelin/governance/TimelockController.sol';
import {IODSafeManager} from '@interfaces/proxies/IODSafeManager.sol';
import {Assertions} from '@libraries/Assertions.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';

struct RenderData {
  IODSafeManager.SAFEData safeData;
  ISAFEEngine.SAFE safeEngineData;
}

contract Base is ODTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address owner = label('owner');
  address user = address(0xdeadce11);
  bytes32 collateralTypeA = 'TypeA';
  // address userProxy;

  Vault721 vault721;
  NFTRenderer renderer;
  ODSafeManager safeManager;
  SAFEEngine safeEngine;
  TimelockController timelockController;

  function setUp() public virtual {
    vm.startPrank(deployer);

    vault721 = new Vault721();
    label(address(vault721), 'Vault721');

    renderer = NFTRenderer(mockContract('nftRenderer'));
    safeManager = ODSafeManager(mockContract('SafeManager'));
    safeEngine = SAFEEngine(mockContract('SAFEEngine'));
    timelockController = TimelockController(payable(mockContract('timeLockController')));
    vault721.addAuthorization(address(timelockController));
    vm.stopPrank();
  }

  modifier testNums(RenderData memory _data) {
    vm.assume(_data.safeData.safeHandler != address(0));
    vm.assume(_data.safeData.owner != address(0));
    _;
  }

  function _mockSafeCall(IODSafeManager.SAFEData memory returnSafe) internal {
    returnSafe.safeHandler = address(1);
    vm.mockCall(address(safeManager), abi.encodeWithSelector(IODSafeManager.safeData.selector), abi.encode(returnSafe));
  }

  function _mockUpdateNfvState(RenderData memory _data) internal testNums(_data) {
    vm.mockCall(
      address(safeManager), abi.encodeWithSelector(IODSafeManager.safeData.selector), abi.encode(_data.safeData)
    );
    vm.mockCall(
      address(safeManager), abi.encodeWithSelector(IODSafeManager.safeEngine.selector), abi.encode(address(safeEngine))
    );
    vm.mockCall(
      address(safeEngine), abi.encodeWithSelector(ISAFEEngine.safes.selector), abi.encode(_data.safeEngineData)
    );
  }
}

contract Unit_Vault721_Initialize is Base {
  modifier safeManagerPath() {
    vm.startPrank(address(safeManager));
    _;
  }

  function testInitialize() public {
    vault721.initialize(address(timelockController), 0, 0);
  }

  function testInitSafeManager() public safeManagerPath {
    vault721.initializeManager();
  }

  function testInitNftRenderer() public safeManagerPath {
    vault721.initializeRenderer();
  }

  function testInitializeZeroFail() public {
    vm.expectRevert(IVault721.ZeroAddress.selector);
    vault721.initialize(address(0), 0, 0);
  }

  function testInitializeMultiInitFail() public {
    vault721.initialize(address(timelockController), 0, 0);
    vm.expectRevert(bytes('Initializable: contract is already initialized'));
    vault721.initialize(address(timelockController), 0, 0);
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
    vault721.build();

    vm.expectRevert(IVault721.ProxyAlreadyExist.selector);
    vault721.build();
  }

  function test_Build_Revert_NotWallet() public {
    address newProxy = vault721.build(owner);

    vm.expectRevert(IVault721.NotWallet.selector);
    vm.prank(newProxy);
    vault721.build();
  }

  function test_Build_Revert_IsProxy() public {
    vm.startPrank(owner);
    address builtProxy = vault721.build();

    vm.expectRevert(IVault721.NotWallet.selector);
    vault721.build(builtProxy);
  }
}

contract Unit_Vault721_Mint is Base {
  address userProxy;

  function setUp() public override {
    Base.setUp();
    vault721.initialize(address(timelockController), 0, 0);
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
    vault721.initialize(address(timelockController), 0, 0);
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
    vault721.modifyParameters('updateAllowlist', abi.encode(address(user), true));
    bool allowlisted = vault721.getIsAllowlisted(address(user));
    assertTrue(allowlisted, 'user not allowed');
  }

  function test_ContractURI() public {
    string memory contractURI = vault721.contractURI();
    assertEq(
      contractURI,
      'data:application/json;utf8,{"name": "Open Dollar Vaults","description": "Open Dollar is a stablecoin protocol built on Arbitrum designed to help you earn yield and leverage your assets with safety and predictability.","image": "https://app.opendollar.com/collectionImage.png","external_link": "https://app.opendollar.com"}',
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

contract Unit_Vault721_UpdateNfvState is Base {
  address userProxy;

  function setUp() public override {
    Base.setUp();
    vault721.initialize(address(timelockController), 0, 0);
    vm.prank(address(renderer));
    vault721.initializeRenderer();
    vm.prank(address(safeManager));
    vault721.initializeManager();

    userProxy = vault721.build(user);
  }

  function test_UpdateNfvState(RenderData memory data) public {
    _mockSafeCall(data.safeData);
    _mockUpdateNfvState(data);

    vm.prank(address(safeManager));
    vault721.updateNfvState(1);

    IVault721.NFVState memory nfvState = vault721.getNfvState(1);

    assertEq(nfvState.lastBlockNumber, block.number, 'incorrect block number');
    assertEq(nfvState.lastBlockTimestamp, block.timestamp, 'incorrect time stamp');
  }

  function test_UpdateNfvState_Revert_OnlySafeManager() public {
    vm.expectRevert(IVault721.NotSafeManager.selector);
    vm.prank(address(user));
    vault721.updateNfvState(1);
  }

  function test_UpdateNfvState_Revert_ZeroAddress() public {
    vm.expectRevert(IVault721.ZeroAddress.selector);

    IODSafeManager.SAFEData memory returnSafe;
    vm.mockCall(address(safeManager), abi.encodeWithSelector(ODSafeManager.safeData.selector), abi.encode(returnSafe));

    vm.prank(address(safeManager));
    vault721.updateNfvState(1);
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

  Scenario internal _scenario;
  ISAFEEngine.SAFE internal testSafeEngineData =
    ISAFEEngine.SAFE({lockedCollateral: 100 ether, generatedDebt: 10 ether});
  IODSafeManager.SAFEData internal testSAFEData =
    IODSafeManager.SAFEData({nonce: 0, owner: address(0), safeHandler: address(420), collateralType: collateralTypeA});
  RenderData internal scenarioData = RenderData({safeData: testSAFEData, safeEngineData: testSafeEngineData});

  function setUp() public override {
    Base.setUp();
    vault721.initialize(address(timelockController), 0, 0);
    vm.prank(address(renderer));
    vault721.initializeRenderer();
    vm.prank(address(safeManager));
    vault721.initializeManager();
    _scenario.user = address(1);
    _scenario.rando = address(2);
    _scenario.nftRenderer = address(renderer);
    _scenario.oracleRelayer = address(3);
    _scenario.taxCollector = address(4);
    _scenario.collateralJoinFactory = address(5);
    testSAFEData.owner = _scenario.user;
  }

  function _mintNft() internal returns (address _userProxy) {
    _userProxy = vault721.build(_scenario.user);

    vm.prank(address(safeManager));
    vault721.mint(_userProxy, 1);
  }

  function test_ModifyParameters_UpdateNFTRenderer() public {
    bytes32 _param = 'updateNFTRenderer';
    vm.prank(address(timelockController));
    vm.mockCall(
      address(_scenario.nftRenderer), abi.encodeWithSelector(NFTRenderer.setImplementation.selector), abi.encode()
    );
    vault721.modifyParameters(
      _param,
      abi.encode(
        _scenario.nftRenderer, _scenario.oracleRelayer, _scenario.taxCollector, _scenario.collateralJoinFactory
      )
    );
  }

  function test_ModifyParameters_Revert_OnlyGovernance() public {
    vm.mockCall(address(renderer), abi.encodeWithSelector(NFTRenderer.setImplementation.selector), abi.encode());
    vm.prank(address(user));
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    vault721.modifyParameters('updateNFTRenderer', abi.encode(address(1), address(1), address(1), address(1)));
  }

  function test_ModifyParameters_UpdateNFTRenderer_Revert_ZeroAddress() public {
    vm.mockCall(address(renderer), abi.encodeWithSelector(NFTRenderer.setImplementation.selector), abi.encode());
    vm.prank(address(timelockController));
    vm.expectRevert(Assertions.NullAddress.selector);
    vault721.modifyParameters(
      'updateNFTRenderer',
      abi.encode(address(0), _scenario.oracleRelayer, _scenario.taxCollector, _scenario.collateralJoinFactory)
    );
  }

  function test_ModifyParameters_UpdateAllowlist() public {
    assertFalse(vault721.getIsAllowlisted(_scenario.user));
    vm.prank(address(timelockController));
    vault721.modifyParameters('updateAllowlist', abi.encode(_scenario.user, true));
    assertTrue(vault721.getIsAllowlisted(_scenario.user));
  }

  function test_ModifyParameters_UpdateTimeDelay() public {
    uint256 timeDelay = 123_456;
    assertEq(vault721.timeDelay(), 0, 'incorrect starting time delay');
    vm.prank(address(timelockController));
    vault721.modifyParameters('timeDelay', abi.encode(timeDelay));
    //update vault hash state so there's a time to check against

    assertEq(vault721.timeDelay(), timeDelay, 'incorrect ending time delay');
  }

  function test_ModifyParameters_UpdateBlockDelay(uint256 blockDelay) public {
    vm.assume(blockDelay > 0 && blockDelay < 1000);

    //add to allow list so that block delay will be checked
    vm.prank(address(timelockController));
    vault721.modifyParameters('updateAllowlist', abi.encode(_scenario.user, true));

    bytes32 _param = 'blockDelay';
    vm.prank(address(timelockController));
    vault721.modifyParameters(_param, abi.encode(blockDelay));

    assertEq(vault721.blockDelay(), blockDelay, 'blockDelay not updated');
  }

  function test_ModifyParameters_UpdateContractURI() public {
    vm.prank(address(timelockController));
    vault721.modifyParameters('contractURI', abi.encode('testURI'));
    assertEq(vault721.contractURI(), 'data:application/json;utf8,testURI', 'incorrect uri');
  }

  function test_ModifyParameters_SetSafeManager() public {
    vm.prank(address(timelockController));
    vault721.modifyParameters('safeManager', abi.encode(address(1)));
    assertEq(address(vault721.safeManager()), address(1), 'incorrect safe manager');
  }

  function test_ModifyParameters_SetNftRenderer() public {
    vm.prank(address(timelockController));
    vault721.modifyParameters('nftRenderer', abi.encode(address(1)));
    assertEq(address(vault721.nftRenderer()), address(1), 'incorrect address set');
  }

  function test_ModifyParameters_ModifyParameters_timelockController() public {
    address oldTimelock = vault721.timelockController();
    vm.prank(address(timelockController));
    vault721.modifyParameters('timelockController', abi.encode(address(1)));
    assertEq(vault721.timelockController(), address(1), 'incorrect timelock controller');
    address[] memory authorizedAccounts = vault721.authorizedAccounts();
    bool isAuth = false;
    for (uint256 i; i < authorizedAccounts.length; i++) {
      if (authorizedAccounts[i] == oldTimelock) {
        isAuth = true;
      }
    }
  }

  function test_ModifyParameters_timelockController_RevertNullAddress() public {
    vm.prank(address(timelockController));
    vm.expectRevert(Assertions.NullAddress.selector);
    vault721.modifyParameters('timelockController', abi.encode(address(0)));
    assertEq(vault721.timelockController(), address(timelockController), 'incorrect timelock controller');
  }

  function test_ModifyParameters_Revert_UnrecognizedParam() public {
    vm.expectRevert(IModifiable.UnrecognizedParam.selector);
    vm.prank(address(timelockController));
    vault721.modifyParameters('unrecognizedParam', abi.encode(0));
  }
}

contract Unit_TestVault721_TransferFrom_SafeTransferFrom_ProxyReceiver is Base {
  TestVault721 internal testVault721;
  address internal user1 = address(1);
  address internal user2 = address(2);
  address internal userProxy1;
  address internal userProxy2;

  ISAFEEngine.SAFE internal testSafeEngineData =
    ISAFEEngine.SAFE({lockedCollateral: 100 ether, generatedDebt: 10 ether});
  IODSafeManager.SAFEData internal testSAFEData =
    IODSafeManager.SAFEData({nonce: 0, owner: user1, safeHandler: address(420), collateralType: collateralTypeA});
  RenderData internal scenarioData = RenderData({safeData: testSAFEData, safeEngineData: testSafeEngineData});

  function setUp() public override {
    Base.setUp();
    testVault721 = new TestVault721();
    testVault721.initialize(address(timelockController), 0, 0);
    vm.prank(address(renderer));
    testVault721.initializeRenderer();
    vm.prank(address(safeManager));
    testVault721.initializeManager();
    userProxy1 = testVault721.build(user1);
    userProxy2 = testVault721.build(user2);
  }

  function test_TransferFrom() public {
    vm.startPrank(address(safeManager));
    testVault721.mint(userProxy1, 1);
    _mockUpdateNfvState(scenarioData);
    testVault721.updateNfvState(1);
    vm.stopPrank();

    vm.prank(user1);
    testVault721.setApprovalForAll(user2, true);

    vm.prank(user2);
    _mockUpdateNfvState(scenarioData);
    // user2 has no bytecode - assumed to be EOA
    testVault721.transferFrom(user1, user2, 1);

    assertEq(testVault721.ownerOf(1), user2, 'nfv not transfered');
  }

  function test_SafeTransferFrom() public {
    vm.startPrank(address(safeManager));
    testVault721.mint(userProxy1, 1);
    _mockUpdateNfvState(scenarioData);
    testVault721.updateNfvState(1);
    vm.stopPrank();

    vm.prank(user1);
    testVault721.setApprovalForAll(user2, true);

    vm.prank(user2);
    _mockUpdateNfvState(scenarioData);
    // user2 has no bytecode - assumed to be EOA
    testVault721.safeTransferFrom(user1, user2, 1);

    assertEq(testVault721.ownerOf(1), user2, 'nfv not transfered');
  }

  function test_TransferFrom_ToProxy_Revert() public {
    vm.startPrank(address(safeManager));
    testVault721.mint(userProxy1, 1);
    _mockUpdateNfvState(scenarioData);
    testVault721.updateNfvState(1);
    vm.stopPrank();
    vm.prank(user1);
    testVault721.setApprovalForAll(user2, true);

    vm.prank(user2);
    _mockUpdateNfvState(scenarioData);
    vm.expectRevert(IVault721.NotWallet.selector);
    testVault721.transferFrom(user1, userProxy2, 1);
  }

  function test_SafeTransferFrom_ToProxy_Revert() public {
    vm.startPrank(address(safeManager));
    testVault721.mint(userProxy1, 1);
    _mockUpdateNfvState(scenarioData);
    testVault721.updateNfvState(1);
    vm.stopPrank();
    vm.prank(user1);
    testVault721.setApprovalForAll(user2, true);

    vm.prank(user2);
    _mockUpdateNfvState(scenarioData);
    vm.expectRevert(IVault721.NotWallet.selector);
    testVault721.safeTransferFrom(user1, userProxy2, 1);
  }
}

contract Unit_Vault721_TransferFrom_SafeTransferFrom is Base {
  address internal user1 = address(1);
  address internal user2 = address(2);
  address internal userProxy1;
  address internal userProxy2;
  address internal scwallet;
  address internal badscwallet;
  uint256 internal tokenId = 1;

  ISAFEEngine.SAFE internal testSafeEngineData =
    ISAFEEngine.SAFE({lockedCollateral: 100 ether, generatedDebt: 10 ether});
  IODSafeManager.SAFEData internal testSAFEData =
    IODSafeManager.SAFEData({nonce: 0, owner: user1, safeHandler: address(420), collateralType: collateralTypeA});
  RenderData internal scenarioData = RenderData({safeData: testSAFEData, safeEngineData: testSafeEngineData});

  function setUp() public override {
    Base.setUp();
    scwallet = address(new SCWallet());
    badscwallet = address(new Bad_SCWallet());
    vault721.initialize(address(timelockController), 0, 0);
    vm.prank(address(renderer));
    vault721.initializeRenderer();
    vm.prank(address(safeManager));
    vault721.initializeManager();
    userProxy1 = vault721.build(user1);
    userProxy2 = vault721.build(user2);
  }

  function test_TransferFrom() public {
    vm.startPrank(address(safeManager));
    vault721.mint(userProxy1, tokenId);
    _mockUpdateNfvState(scenarioData);
    vault721.updateNfvState(tokenId);
    vm.stopPrank();

    vm.prank(user1);
    vault721.setApprovalForAll(user2, true);

    vm.prank(user2);
    _mockUpdateNfvState(scenarioData);
    // user2 has no bytecode - assumed to be EOA
    vault721.transferFrom(user1, user2, 1);

    assertEq(vault721.ownerOf(tokenId), user2, 'nfv not transfered');
  }

  function test_SafeTransferFrom() public {
    vm.startPrank(address(safeManager));
    vault721.mint(userProxy1, tokenId);
    _mockUpdateNfvState(scenarioData);
    vault721.updateNfvState(tokenId);
    vm.stopPrank();

    vm.prank(user1);
    vault721.setApprovalForAll(user2, true);

    vm.prank(user2);
    _mockUpdateNfvState(scenarioData);

    // scwallet has erc721Reveiver - no revert
    vault721.safeTransferFrom(user1, scwallet, tokenId);

    assertEq(vault721.ownerOf(tokenId), scwallet, 'nfv not transfered');
  }

  function test_TransferFrom_Revert_BlockDelayNotReached() public {
    uint256 blockDelay = 1234;
    //add to allow list so that block delay will be checked
    vm.prank(address(timelockController));
    vault721.modifyParameters('updateAllowlist', abi.encode(user1, true));

    vm.startPrank(address(safeManager));
    vault721.mint(userProxy1, tokenId);
    _mockUpdateNfvState(scenarioData);
    vault721.updateNfvState(tokenId);
    vm.stopPrank();

    vm.prank(address(timelockController));
    vault721.modifyParameters('blockDelay', abi.encode(blockDelay));

    //update hash state with hardcoded value.

    vm.prank(address(safeManager));
    _mockUpdateNfvState(scenarioData);
    vault721.updateNfvState(tokenId);

    vm.prank(user1);

    vm.expectRevert(IVault721.BlockDelayNotOver.selector);
    _mockUpdateNfvState(scenarioData);
    vault721.transferFrom(user1, user2, tokenId);
    assertEq(vault721.balanceOf(user1), 1, 'token transferred');
  }

  function test_TransferFrom_Revert_TimeDelayNotOver() public {
    uint256 timeDelay = 123_456;
    vm.startPrank(address(safeManager));
    vault721.mint(userProxy1, tokenId);
    _mockUpdateNfvState(scenarioData);
    vault721.updateNfvState(tokenId);
    vm.stopPrank();

    vm.prank(address(timelockController));
    vault721.modifyParameters('timeDelay', abi.encode(timeDelay));

    //update vault hash state so there's a time to check against

    vm.prank(address(safeManager));
    _mockUpdateNfvState(scenarioData);
    vault721.updateNfvState(tokenId);

    vm.prank(user1);
    vault721.setApprovalForAll(user2, true);

    vm.prank(user2);
    vm.expectRevert(IVault721.TimeDelayNotOver.selector);
    _mockUpdateNfvState(scenarioData);
    vault721.transferFrom(user1, user2, tokenId);

    assertEq(vault721.balanceOf(user1), 1, 'transfer succesful');
  }

  function test_SafeTransferFrom_NoReceiver_Revert() public {
    vm.startPrank(address(safeManager));
    vault721.mint(userProxy1, tokenId);
    _mockUpdateNfvState(scenarioData);
    vault721.updateNfvState(tokenId);
    vm.stopPrank();

    vm.prank(user1);
    vault721.setApprovalForAll(user2, true);

    _mockUpdateNfvState(scenarioData);

    vm.prank(user2);
    // badscwallet does not have erc721Reveiver - revert
    vm.expectRevert('ERC721: transfer to non ERC721Receiver implementer');
    vault721.safeTransferFrom(user1, badscwallet, tokenId);
  }

  function test_Unsafe_TransferFrom_NoReceiver() public {
    vm.startPrank(address(safeManager));
    vault721.mint(userProxy1, tokenId);
    _mockUpdateNfvState(scenarioData);
    vault721.updateNfvState(tokenId);
    vm.stopPrank();

    vm.prank(user1);
    vault721.setApprovalForAll(user2, true);
    _mockUpdateNfvState(scenarioData);

    vm.prank(user2);
    // badscwallet does not have erc721Reveiver - no revert becuase transferFrom does not check for erc721Reveiver
    vault721.transferFrom(user1, badscwallet, tokenId);
  }

  function test_TransferFrom_ToProxy_NoReceiver_Revert() public {
    vm.startPrank(address(safeManager));
    vault721.mint(userProxy1, tokenId);
    _mockUpdateNfvState(scenarioData);
    vault721.updateNfvState(tokenId);
    vm.stopPrank();

    vm.prank(user1);
    vault721.setApprovalForAll(user2, true);
    _mockUpdateNfvState(scenarioData);

    vm.prank(user2);

    // NotWallet check triggered before proxy can fail on Non-erc721Reveiver
    vm.expectRevert(IVault721.NotWallet.selector);
    vault721.transferFrom(user1, userProxy2, tokenId);
  }

  function test_safeTransferFrom_ToProxy_NoReceiver_Revert() public {
    vm.startPrank(address(safeManager));
    vault721.mint(userProxy1, tokenId);
    _mockUpdateNfvState(scenarioData);
    vault721.updateNfvState(tokenId);
    vm.stopPrank();

    vm.prank(user1);
    vault721.setApprovalForAll(user2, true);
    _mockUpdateNfvState(scenarioData);

    vm.prank(user2);
    // NotWallet check triggered before proxy can fail on Non-erc721Reveiver
    vm.expectRevert(IVault721.NotWallet.selector);
    vault721.transferFrom(user1, userProxy2, tokenId);
  }
}

contract Unit_Vault721_ProxyDeployment is Base {
  function setUp() public override {
    Base.setUp();
    vault721.initialize(address(timelockController), 0, 0);
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
    vault721.build();

    vm.expectRevert(IVault721.ProxyAlreadyExist.selector);
    vault721.build();
  }

  function test_DeployProxy_MultiProxies() public {
    address[] memory users = new address[](10);

    for (uint256 i; i < users.length; i++) {
      users[i] = address(uint160(i + 100));
    }

    address payable[] memory proxies = vault721.build(users);
    assertEq(proxies.length, users.length, 'incorrect proxy length');
    for (uint256 i; i < users.length; i++) {
      assertEq(vault721.getProxy(users[i]), proxies[i], 'incorrect proxy address');
    }
  }
}

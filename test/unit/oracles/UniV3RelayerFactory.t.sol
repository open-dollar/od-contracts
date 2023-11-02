// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {UniV3RelayerFactory} from '@contracts/factories/UniV3RelayerFactory.sol';
import {UniV3RelayerChild} from '@contracts/factories/UniV3RelayerChild.sol';
import {IUniswapV3Factory} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import {IUniswapV3Pool} from '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import {IERC20Metadata} from '@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IUniswapV3Factory mockUniV3Factory =
    IUniswapV3Factory(mockContract(0x1F98431c8aD98523631AE4a59f267346ea31F984, 'UniswapV3Factory'));
  IUniswapV3Pool mockUniV3Pool = IUniswapV3Pool(mockContract('UniswapV3Pool'));
  IERC20Metadata mockBaseToken = IERC20Metadata(mockContract('BaseToken'));
  IERC20Metadata mockQuoteToken = IERC20Metadata(mockContract('QuoteToken'));

  UniV3RelayerFactory uniV3RelayerFactory;
  UniV3RelayerChild uniV3RelayerChild = UniV3RelayerChild(
    label(address(0x0000000000000000000000007f85e9e000597158aed9320b5a5e11ab8cc7329a), 'UniV3RelayerChild')
  );

  function setUp() public virtual {
    vm.startPrank(deployer);

    uniV3RelayerFactory = new UniV3RelayerFactory();
    label(address(uniV3RelayerFactory), 'UniV3RelayerFactory');

    uniV3RelayerFactory.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockGetPool(address _baseToken, address _quoteToken, uint24 _feeTier, address _uniV3Pool) internal {
    vm.mockCall(
      address(mockUniV3Factory),
      abi.encodeCall(mockUniV3Factory.getPool, (_baseToken, _quoteToken, _feeTier)),
      abi.encode(_uniV3Pool)
    );
  }

  function _mockToken0(address _token0) internal {
    vm.mockCall(address(mockUniV3Pool), abi.encodeCall(mockUniV3Pool.token0, ()), abi.encode(_token0));
  }

  function _mockToken1(address _token1) internal {
    vm.mockCall(address(mockUniV3Pool), abi.encodeCall(mockUniV3Pool.token1, ()), abi.encode(_token1));
  }

  function _mockSymbol(string memory _symbol) internal {
    vm.mockCall(address(mockBaseToken), abi.encodeCall(mockBaseToken.symbol, ()), abi.encode(_symbol));
    vm.mockCall(address(mockQuoteToken), abi.encodeCall(mockQuoteToken.symbol, ()), abi.encode(_symbol));
  }

  function _mockDecimals(uint8 _decimals) internal {
    vm.mockCall(address(mockBaseToken), abi.encodeCall(mockBaseToken.decimals, ()), abi.encode(_decimals));
    vm.mockCall(address(mockQuoteToken), abi.encodeCall(mockQuoteToken.decimals, ()), abi.encode(_decimals));
  }
}

contract Unit_UniV3RelayerFactory_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new UniV3RelayerFactory();
  }
}

contract Unit_UniV3RelayerFactory_DeployUniV3Relayer is Base {
  event NewUniV3Relayer(
    address indexed _uniV3Relayer, address _baseToken, address _quoteToken, uint24 _feeTier, uint32 _quotePeriod
  );

  modifier happyPath(uint24 _feeTier, string memory _symbol, uint8 _decimals) {
    vm.startPrank(authorizedAccount);

    _assumeHappyPath(_decimals);
    _mockValues(_feeTier, _symbol, _decimals);
    _;
  }

  function _assumeHappyPath(uint8 _decimals) internal pure {
    vm.assume(_decimals <= 18);
  }

  function _mockValues(uint24 _feeTier, string memory _symbol, uint8 _decimals) internal {
    _mockGetPool(address(mockBaseToken), address(mockQuoteToken), _feeTier, address(mockUniV3Pool));
    _mockToken0(address(mockBaseToken));
    _mockToken1(address(mockQuoteToken));
    _mockSymbol(_symbol);
    _mockDecimals(_decimals);
  }

  function test_Revert_Unauthorized(uint24 _feeTier, uint32 _quotePeriod) public {
    vm.expectRevert(IAuthorizable.Unauthorized.selector);

    uniV3RelayerFactory.deployUniV3Relayer(address(mockBaseToken), address(mockQuoteToken), _feeTier, _quotePeriod);
  }

  function test_Deploy_UniV3RelayerChild(
    uint24 _feeTier,
    uint32 _quotePeriod,
    string memory _symbol,
    uint8 _decimals
  ) public happyPath(_feeTier, _symbol, _decimals) {
    uniV3RelayerFactory.deployUniV3Relayer(address(mockBaseToken), address(mockQuoteToken), _feeTier, _quotePeriod);

    assertEq(address(uniV3RelayerChild).code, type(UniV3RelayerChild).runtimeCode);

    // params
    assertEq(uniV3RelayerChild.baseToken(), address(mockBaseToken));
    assertEq(uniV3RelayerChild.quoteToken(), address(mockQuoteToken));
    assertEq(uniV3RelayerChild.quotePeriod(), _quotePeriod);
  }

  function test_Set_UniV3Relayers(
    uint24 _feeTier,
    uint32 _quotePeriod,
    string memory _symbol,
    uint8 _decimals
  ) public happyPath(_feeTier, _symbol, _decimals) {
    uniV3RelayerFactory.deployUniV3Relayer(address(mockBaseToken), address(mockQuoteToken), _feeTier, _quotePeriod);

    assertEq(uniV3RelayerFactory.uniV3RelayersList()[0], address(uniV3RelayerChild));
  }

  function test_Emit_NewUniV3Relayer(
    uint24 _feeTier,
    uint32 _quotePeriod,
    string memory _symbol,
    uint8 _decimals
  ) public happyPath(_feeTier, _symbol, _decimals) {
    vm.expectEmit();
    emit NewUniV3Relayer(
      address(uniV3RelayerChild), address(mockBaseToken), address(mockQuoteToken), _feeTier, _quotePeriod
    );

    uniV3RelayerFactory.deployUniV3Relayer(address(mockBaseToken), address(mockQuoteToken), _feeTier, _quotePeriod);
  }

  function test_Return_UniV3Relayer(
    uint24 _feeTier,
    uint32 _quotePeriod,
    string memory _symbol,
    uint8 _decimals
  ) public happyPath(_feeTier, _symbol, _decimals) {
    assertEq(
      address(
        uniV3RelayerFactory.deployUniV3Relayer(address(mockBaseToken), address(mockQuoteToken), _feeTier, _quotePeriod)
      ),
      address(uniV3RelayerChild)
    );
  }
}

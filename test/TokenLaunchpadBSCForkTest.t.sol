// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {WAGMIEToken} from "contracts/WAGMIEToken.sol";
import {IERC20, ITokenLaunchpad} from "contracts/interfaces/ITokenLaunchpad.sol";
import {TokenLaunchpadBSC} from "contracts/launchpad/clmm/TokenLaunchpadBSC.sol";
import {PancakeAdapter} from "contracts/launchpad/clmm/dexes/PancakeAdapter.sol";
import {MockERC20} from "contracts/mocks/MockERC20.sol";
import {Test} from "lib/forge-std/src/Test.sol";

contract TokenLaunchpadBscForkTest is Test {
  // BSC Mainnet addresses
  address constant PANCAKE_FACTORY = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
  address constant PANCAKE_ROUTER = 0x1b81D678ffb9C0263b24A97847620C99d213eB14;

  TokenLaunchpadBSC _launchpad;
  PancakeAdapter _adapter;
  MockERC20 _weth;
  WAGMIEToken _tokenImpl;
  address owner = 0xeD3Af36D7b9C5Bbd7ECFa7fb794eDa6E242016f5;

  string BSC_RPC_URL = vm.envString("BSC_RPC_URL");

  function setUp() public {
    uint256 bscFork = vm.createFork(BSC_RPC_URL);
    vm.selectFork(bscFork);

    // Deploy contracts
    _launchpad = new TokenLaunchpadBSC();
    _adapter = new PancakeAdapter();
    _weth = new MockERC20("Wrapped Ether", "WETH", 18);
    _tokenImpl = new WAGMIEToken();

    // Label contracts for better trace output
    vm.label(address(_launchpad), "launchpad");
    vm.label(address(_adapter), "pancakeAdapter");
    vm.label(address(_weth), "weth");
    vm.label(PANCAKE_FACTORY, "pancakeFactory");
    vm.label(PANCAKE_ROUTER, "pancakeRouter");

    // Initialize adapter
    _adapter.initialize(address(_launchpad), PANCAKE_FACTORY, PANCAKE_ROUTER, address(_weth), address(0));

    // Initialize launchpad
    _launchpad.initialize(address(_adapter), address(_tokenImpl), owner, address(_weth));
  }

  function test_Initialize() public view {
    assertEq(_adapter.launchpad(), address(_launchpad));
    assertEq(address(_adapter.poolFactory()), PANCAKE_FACTORY);
    assertEq(address(_adapter.swapRouter()), PANCAKE_ROUTER);
    assertEq(address(_adapter.WETH9()), address(_weth));
    assertEq(address(_adapter.ODOS()), address(0));

    assertEq(address(_launchpad.adapter()), address(_adapter));
    assertEq(_launchpad.owner(), owner);
    assertEq(address(_launchpad.weth()), address(_weth));
  }

  function test_create() public {
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      limitPerWallet: 1000,
      salt: bytes32(0),
      launchTick: -171_000,
      graduationTick: -170_800,
      upperMaxTick: 887_200
    });

    vm.deal(address(this), 100 ether);
    address tokenAddr = _launchpad.createAndBuy{value: 100 ether}(params, address(0), 0);

    assertTrue(tokenAddr != address(0), "Token address should not be zero");

    // Get the token contract
    WAGMIEToken token = WAGMIEToken(tokenAddr);

    assertEq(token.metadata(), "Test metadata", "Token metadata mismatch");
  }

  receive() external payable {}
  fallback() external payable {}
}

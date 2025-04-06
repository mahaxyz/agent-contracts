// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IFreeUniV3LPLocker, TokenLaunchpadTest} from "./TokenLaunchpadTest.sol";
import {IERC20, ITokenLaunchpad} from "contracts/interfaces/ITokenLaunchpad.sol";
import {TokenLaunchpadBSC} from "contracts/launchpad/clmm/TokenLaunchpadBSC.sol";
import {PancakeAdapter} from "contracts/launchpad/clmm/dexes/PancakeAdapter.sol";

contract TokenLaunchpadBscForkTest is TokenLaunchpadTest {
  // BSC Mainnet addresses
  address constant PANCAKE_FACTORY = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
  address constant PANCAKE_ROUTER = 0x1b81D678ffb9C0263b24A97847620C99d213eB14;
  address constant NFT_MANAGER = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
  address constant LOCKER = 0x25c9C4B56E820e0DEA438b145284F02D9Ca9Bd52;

  PancakeAdapter _adapter;

  string BSC_RPC_URL = vm.envString("BSC_RPC_URL");

  function setUp() public {
    uint256 bscFork = vm.createFork(BSC_RPC_URL);
    vm.selectFork(bscFork);

    _setUpBase();

    // Deploy contracts
    _launchpad = new TokenLaunchpadBSC();
    _adapter = new PancakeAdapter();

    // Label contracts for better trace output
    vm.label(address(_launchpad), "launchpad");
    vm.label(address(_adapter), "pancakeAdapter");
    vm.label(PANCAKE_FACTORY, "pancakeFactory");
    vm.label(PANCAKE_ROUTER, "pancakeRouter");

    // Initialize adapter
    _adapter.initialize(address(_launchpad), PANCAKE_FACTORY, PANCAKE_ROUTER, address(_weth), LOCKER, NFT_MANAGER);

    // Initialize launchpad
    _launchpad.initialize(address(_adapter), owner, address(_weth), address(_maha), 1000e18);
  }

  function test_create() public {
    bytes32 salt = findValidTokenHash("Test Token", "TEST", creator, _weth);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      salt: salt,
      launchTick: -171_000,
      graduationTick: -170_800,
      upperMaxTick: 887_200,
      isFeeDiscounted: false
    });

    vm.prank(creator);
    (address tokenAddr,,) = _launchpad.createAndBuy{value: 100 ether}(params, address(0), 0);

    assertTrue(tokenAddr != address(0), "Token address should not be zero");
  }
}

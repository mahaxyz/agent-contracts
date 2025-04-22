// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {IFreeUniV3LPLocker, TokenLaunchpadTest} from "./TokenLaunchpadTest.sol";
import {IERC20, ILaunchpool, ITokenLaunchpad} from "contracts/interfaces/ITokenLaunchpad.sol";

import {Swapper} from "contracts/launchpad/clmm/Swapper.sol";
import {TokenLaunchpadBSC} from "contracts/launchpad/clmm/TokenLaunchpadBSC.sol";
import {PancakeAdapter} from "contracts/launchpad/clmm/dexes/PancakeAdapter.sol";

import "forge-std/console.sol";

contract TokenLaunchpadBscForkTest is TokenLaunchpadTest {
  // BSC Mainnet addresses
  address constant PANCAKE_FACTORY = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
  address constant PANCAKE_ROUTER = 0x1b81D678ffb9C0263b24A97847620C99d213eB14;
  address constant NFT_MANAGER = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
  address constant LOCKER = 0x25c9C4B56E820e0DEA438b145284F02D9Ca9Bd52;

  PancakeAdapter _adapter;
  Swapper _swapper;

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
    vm.label(LOCKER, "locker");
    vm.label(NFT_MANAGER, "nftManager");
    vm.label(PANCAKE_ROUTER, "pancakeRouter");

    // Initialize adapter
    _adapter.initialize(address(_launchpad), PANCAKE_FACTORY, PANCAKE_ROUTER, address(_weth), LOCKER, NFT_MANAGER);

    _swapper = new Swapper(address(_weth), address(0), address(_launchpad));

    // Initialize launchpad
    _launchpad.initialize(owner, address(_weth), address(_maha), 1000e18);
    vm.startPrank(owner);
    ITokenLaunchpad.ValueParams memory params = ITokenLaunchpad.ValueParams({
      launchTick: -171_000,
      graduationTick: -170_800,
      upperMaxTick: 887_200,
      fee: 10_000,
      tickSpacing: 200,
      graduationLiquidity: 800_000_000 ether
    });
    _launchpad.setFeeSettings(address(0x123), 0, 1000e18);
    _launchpad.toggleAdapter(_adapter);
    _launchpad.setValueParams(_weth, params);
    vm.stopPrank();
  }

  function test_create() public {
    bytes32 salt = findValidTokenHash("Test Token", "TEST", creator, _weth);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      salt: salt,
      valueParams: ITokenLaunchpad.ValueParams({
        launchTick: -171_000,
        graduationTick: -170_800,
        upperMaxTick: 887_200,
        fee: 10_000,
        tickSpacing: 200,
        graduationLiquidity: 800_000_000 ether
      }),
      isPremium: false,
      launchPools: new ILaunchpool[](0),
      launchPoolAmounts: new uint256[](0),
      creatorAllocation: 0,
      adapter: _adapter
    });

    console.log("Creating token", address(_weth));

    vm.prank(creator);
    (address tokenAddr,,) = _launchpad.createAndBuy{value: 100 ether}(params, address(0), 0);

    assertTrue(tokenAddr != address(0), "Token address should not be zero");
  }

  function test_swap() public {
    bytes32 salt = findValidTokenHash("Test Token", "TEST", creator, _weth);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      salt: salt,
      valueParams: ITokenLaunchpad.ValueParams({
        launchTick: -171_000,
        graduationTick: -170_800,
        upperMaxTick: 887_200,
        fee: 10_000,
        tickSpacing: 200,
        graduationLiquidity: 800_000_000 ether
      }),
      isPremium: false,
      launchPools: new ILaunchpool[](0),
      launchPoolAmounts: new uint256[](0),
      creatorAllocation: 0,
      adapter: _adapter
    });

    vm.prank(creator);
    (address tokenAddr,,) = _launchpad.createAndBuy{value: 100 ether}(params, address(0), 0);

    assertTrue(tokenAddr != address(0), "Token address should not be zero");

    // Swap 100 WETH for the token
    _swapper.buyWithExactInputWithOdos{value: 100 ether}(
      IERC20(_weth), IERC20(_weth), IERC20(tokenAddr), 100 ether, 0, 0, "0x"
    );

    // Swap 1 token for the weth
    IERC20(tokenAddr).approve(address(_swapper), 1 ether);
    _swapper.sellWithExactInputWithOdos(IERC20(tokenAddr), IERC20(tokenAddr), IERC20(_weth), 1 ether, 0, 0, "0x");

    console.log("Token amount", IERC20(tokenAddr).balanceOf(address(_swapper)));
  }
}

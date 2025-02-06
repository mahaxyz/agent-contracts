// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {TxChecker} from "../contracts/TxChecker.sol";

import {FixedCurve} from "../contracts/curves/FixedCurve.sol";

import {IAgentLaunchpad} from "../contracts/interfaces/IAgentLaunchpad.sol";
import {IAgentToken} from "../contracts/interfaces/IAgentToken.sol";

import {AgentLaunchpad} from "../contracts/launchpad/AgentLaunchpad.sol";
import {AgentToken} from "../contracts/token/AgentToken.sol";

import {MockAerodromeFactory} from "contracts/mocks/MockAerodromeFactory.sol";
import {MockERC20, IERC20} from "../contracts/mocks/MockERC20.sol";
import "forge-std/Test.sol";

contract AgentLaunchpadTest is Test {
  AgentLaunchpad public launchpad;
  MockERC20 public maha;
  MockAerodromeFactory public aerodromeFactory;
  TxChecker public txChecker;
  FixedCurve public curve;

  address public owner = makeAddr("owner");
  address public creator = makeAddr("creator");
  address public investor = makeAddr("investor");
  address public feeDestination = makeAddr("feeDestination");
  address public governor = makeAddr("governor"); // todo write governor contract

  function setUp() public {
    launchpad = new AgentLaunchpad();
    maha = new MockERC20("Mock MAHA", "MAHA", 18);
    aerodromeFactory = new MockAerodromeFactory();
    txChecker = new TxChecker();
    curve = new FixedCurve();

    maha.mint(creator, 100_000_000 ether);
    maha.mint(investor, 100_000_000 ether);
  }

  function _initLaunchpad() internal {
    IAgentToken tokenImpl = IAgentToken(new AgentToken());
    launchpad.initialize(
      address(maha),
      address(aerodromeFactory),
      address(tokenImpl),
      owner
    );

    vm.startPrank(owner);
    launchpad.setSettings(
      100e18,
      100 days,
      1 days,
      1000 ether,
      governor,
      address(txChecker),
      feeDestination,
      0.1e18
    );
    launchpad.whitelist(address(txChecker), true);
    launchpad.whitelist(address(curve), true);
    launchpad.whitelist(address(maha), true);
    vm.stopPrank();
  }

  function test_ShouldInitAgentLaunchpadCorrectly() public {
    _initLaunchpad();
    assertEq(address(launchpad.owner()), owner);
    assertEq(address(launchpad.coreToken()), address(maha));
    assertEq(address(launchpad.aeroFactory()), address(aerodromeFactory));
    assertEq(launchpad.name(), "AI Agent Launchpad");
    assertEq(launchpad.symbol(), "AGENTS");
  }

  function test_fullLaunch() public {
    _initLaunchpad();

    vm.startPrank(creator);
    maha.approve(address(launchpad), 1000 ether);

    IAgentToken token = IAgentToken(
      launchpad.create(
        IAgentLaunchpad.CreateParams({
          bondingCurve: address(curve),
          fundManagers: new address[](0),
          duration: 2 days,
          goal: 10_000 ether,
          limitPerWallet: 100_000_000 ether,
          metadata: "{}",
          name: "testing",
          salt: keccak256("test"),
          symbol: "test",
          fundingToken: IERC20(maha)
        })
      )
    );
    vm.stopPrank();

    vm.label(address(token), "token");

    vm.startPrank(investor);
    maha.approve(address(launchpad), type(uint256).max);
    token.approve(address(launchpad), type(uint256).max);

    launchpad.presaleSwap(token, 25_000_000 ether, 0, true); // maha in, token out

    launchpad.presaleSwap(token, 24_000_000 ether, 0, false); // token in, maha out
    vm.stopPrank();
  }

  function test_ShouldBeAbleToCreateTokens() public {
    _initLaunchpad();

    vm.startPrank(creator);
    // Give approval as creation fee is deducted
    maha.approve(address(launchpad), 100 ether);

    IAgentLaunchpad.CreateParams memory params = IAgentLaunchpad.CreateParams({
      bondingCurve: address(curve),
      fundManagers: new address[](0),
      duration: 2 days,
      goal: 20_000 ether,
      limitPerWallet: 100_000_000 ether,
      metadata: "{}",
      name: "Launchpad Token Test ",
      salt: keccak256("launchpad test"),
      symbol: "LTT",
      fundingToken: IERC20(maha)
    });

    address token = launchpad.create(params);
    vm.stopPrank();
    // Should update the take properly after creation of token
    assertEq(maha.balanceOf(address(0xdead)), 100 ether);
    assertEq(
      address(launchpad.fundingTokens(IAgentToken(token))),
      address(maha)
    );
    assertEq(launchpad.fundingGoals(IAgentToken(token)), params.goal);
    assertEq(address(launchpad.tokens(0)), token);
    assertEq(launchpad.balanceOf(creator), 1);
    assertEq(launchpad.tokenToNftId(IAgentToken(token)), 1);
    assertEq(launchpad.getTotalTokens(), 1);
  }

  function test_ShouldAbleToGraduateTokens() public {
    _initLaunchpad();

    vm.startPrank(owner);
    launchpad.setSettings(
      100e18,
      100 days,
      1 days,
      0,
      governor,
      address(txChecker),
      feeDestination,
      0.1e18
    );
    vm.stopPrank();
    // Create the Tokens from creator
    vm.startPrank(creator);
    // Give approval as creation fee is deducted
    maha.approve(address(launchpad), 100 ether);

    IAgentLaunchpad.CreateParams memory params = IAgentLaunchpad.CreateParams({
      bondingCurve: address(curve),
      fundManagers: new address[](0),
      duration: 2 days,
      goal: 1000 ether, // Funding goal is 1000 ether
      limitPerWallet: 10000000000 ether,
      metadata: "{}",
      name: "AI Agent Launch Token ",
      salt: keccak256("AI agent launch token"),
      symbol: "AALT",
      fundingToken: IERC20(maha)
    });

    address agentToken = launchpad.create(params);
    vm.stopPrank();
    // Invertor buys the tokens
    vm.startPrank(investor);
    maha.approve(address(launchpad), type(uint256).max);
    launchpad.presaleSwap(IAgentToken(agentToken), 257_500_000 ether, 0, true);
    vm.stopPrank();
    address pool = aerodromeFactory.getPool(agentToken, address(maha), false);
    assertEq(launchpad.checkFundingGoalMet(IAgentToken(agentToken)), true);
    assertEq(aerodromeFactory.isPool_(pool), true); // Goal Reached Pool Created for Agent/Maha
    assertGt(IERC20(maha).balanceOf(pool), 0);
    assertGt(IERC20(agentToken).balanceOf(pool), 0);
  }

  function test_ShouldRevertIfInvalidInitParams() public {
    _initLaunchpad();

    IAgentLaunchpad.CreateParams memory params = IAgentLaunchpad.CreateParams({
      bondingCurve: address(curve),
      fundManagers: new address[](0),
      duration: 0 seconds,
      goal: 1000 ether,
      limitPerWallet: 100_000_000 ether,
      metadata: "{}",
      name: "testing",
      salt: keccak256("test"),
      symbol: "test",
      fundingToken: IERC20(maha)
    });

    // Test invalid duration (too short)
    params.duration = 10 seconds;
    vm.expectRevert("!duration");
    launchpad.create(params);

    // Test invalid duration (too long)
    params.duration = launchpad.maxDuration() + 1;
    vm.expectRevert("!duration");
    launchpad.create(params);

    // Test invalid funding goal (too low)
    params.duration = launchpad.minDuration(); // Reset to valid duration
    params.goal = launchpad.minFundingGoal() - 1;
    vm.expectRevert("!minFundingGoal");
    launchpad.create(params);

    // Test invalid bonding curve (not whitelisted)
    params.goal = launchpad.minFundingGoal(); // Reset to valid goal
    params.bondingCurve = address(0); // Invalid bonding curve
    vm.expectRevert("!bondingCurve");
    launchpad.create(params);
  }

  function test_ShouldRevertIfPresaleNotOver() public {
    _initLaunchpad();
    vm.startPrank(creator);
    maha.approve(address(launchpad), 1000 ether);

    IAgentToken token = IAgentToken(
      launchpad.create(
        IAgentLaunchpad.CreateParams({
          bondingCurve: address(curve),
          fundManagers: new address[](0),
          salt: keccak256("test"),
          metadata: "{}",
          name: "testing",
          symbol: "test",
          duration: 2 days,
          goal: 1000 ether,
          limitPerWallet: 100_000_000 ether,
          fundingToken: IERC20(maha)
        })
      )
    );
    vm.stopPrank();

    vm.startPrank(address(launchpad));
    // Force unlock before test
    token.unlock();
    vm.stopPrank();

    vm.expectRevert("presale is over");
    launchpad.graduate(IAgentToken(address(token)));
  }

  function test_ShouldRevertIfFundingGoalNotMet() public {
    _initLaunchpad();
    vm.startPrank(creator);
    maha.approve(address(launchpad), 1000 ether);

    IAgentToken token = IAgentToken(
      launchpad.create(
        IAgentLaunchpad.CreateParams({
          bondingCurve: address(curve),
          fundManagers: new address[](0),
          salt: keccak256("test"),
          metadata: "{}",
          name: "testing",
          symbol: "test",
          duration: 2 days,
          goal: 1000 ether,
          limitPerWallet: 100_000_000 ether,
          fundingToken: IERC20(maha)
        })
      )
    );
    vm.stopPrank();
    vm.expectRevert("!fundingGoal");
    launchpad.graduate(IAgentToken(address(token)));
  }

  function test_ShouldRevertIfMinTokenOutGreaterThanTokenOut() public {
    _initLaunchpad();
    vm.startPrank(creator);
    maha.approve(address(launchpad), 1000 ether);

    IAgentToken token = IAgentToken(
      launchpad.create(
        IAgentLaunchpad.CreateParams({
          bondingCurve: address(curve),
          fundManagers: new address[](0),
          duration: 2 days,
          goal: 10_000 ether,
          limitPerWallet: 100_000_000 ether,
          metadata: "{}",
          name: "testing",
          salt: keccak256("test"),
          symbol: "test",
          fundingToken: IERC20(maha)
        })
      )
    );
    vm.stopPrank();

    vm.label(address(token), "token");

    vm.startPrank(investor);
    maha.approve(address(launchpad), type(uint256).max);
    token.approve(address(launchpad), type(uint256).max);
    vm.expectRevert("!minAmountOut");
    launchpad.presaleSwap(token, 25_000_000 ether, 25_000_001 ether, true); // maha in, token out
    vm.stopPrank();

    vm.startPrank(investor);
    maha.approve(address(launchpad), type(uint256).max);
    token.approve(address(launchpad), type(uint256).max);
    launchpad.presaleSwap(token, 25_000_000 ether, 0 ether, true); // maha in, token out
    vm.expectRevert("!minAmountOut");
    launchpad.presaleSwap(token, 24_000_000 ether, 24_000_001 ether, false); // maha in, token out
    vm.stopPrank();
  }

  function test_ShouldRevertIfNonOwner() public {
    vm.expectRevert();
    vm.startPrank(investor);
    launchpad.whitelist(address(txChecker), true);
    vm.stopPrank();
  }

  function test_ShouldReturnTrueIfStartsWithDA0() public view {
    address da00AddrBytes = 0xDA00000000000000000000000000000000000000;
    bool result = launchpad.startsWithDA0(da00AddrBytes);
    assertTrue(result);
  }

  function test_ShouldReturnFalseIfStartsWithDA0() public {
    address alice = makeAddr("alice");
    bool result = launchpad.startsWithDA0(alice);
    assertFalse(result);
  }
}

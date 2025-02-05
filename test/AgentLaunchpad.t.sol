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
    launchpad.initialize(address(maha), address(aerodromeFactory), address(tokenImpl), owner);

    vm.startPrank(owner);
    launchpad.setSettings(100e18, 100 days, 1 days, 1000 ether, governor, address(txChecker), feeDestination, 0.1e18);
    launchpad.whitelist(address(txChecker), true);
    launchpad.whitelist(address(curve), true);
    launchpad.whitelist(address(maha), true);
    vm.stopPrank();
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

  function test_ShouldReturnCorrectLength() public {
    _initLaunchpad();
    vm.assertEq(launchpad.getTotalTokens(), 0);

    vm.startPrank(creator);
    maha.approve(address(launchpad), 1000 ether);

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
    );
    vm.stopPrank();
    vm.assertEq(launchpad.getTotalTokens(), 1);
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

  function test_ShouldRevertIfNonOwner() public {
    vm.expectRevert();
    vm.startPrank(investor);
    launchpad.whitelist(address(txChecker), true);
    vm.stopPrank();
  }
}

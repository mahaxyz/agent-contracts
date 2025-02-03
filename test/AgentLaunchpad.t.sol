// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {TxChecker} from "../contracts/TxChecker.sol";

import {FixedCurve} from "../contracts/curves/FixedCurve.sol";

import {IAgentLaunchpad} from "../contracts/interfaces/IAgentLaunchpad.sol";
import {IAgentToken} from "../contracts/interfaces/IAgentToken.sol";
import {AgentLaunchpad} from "../contracts/launchpad/AgentLaunchpad.sol";

import {MockAerodromePool} from "../contracts/mocks/MockAerodromePool.sol";
import {MockERC20} from "../contracts/mocks/MockERC20.sol";
import "forge-std/Test.sol";

contract AgentLaunchpadTest is Test {
  AgentLaunchpad public launchpad;
  MockERC20 public maha;
  MockAerodromePool public aerodromeFactory;
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
    aerodromeFactory = new MockAerodromePool();
    txChecker = new TxChecker();
    curve = new FixedCurve();

    maha.mint(creator, 10_000 ether);
    maha.mint(investor, 10_000 ether);
  }

  function _initLaunchpad() internal {
    launchpad.initialize(address(maha), address(aerodromeFactory), owner);

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
          fundingToken: maha,
          fundManagers: new address[](0),
          duration: 2 days,
          goal: 100_000 ether,
          limitPerWallet: 100_000_000 ether,
          metadata: "{}",
          name: "testing",
          salt: keccak256("test"),
          symbol: "test"
        })
      )
    );
    vm.stopPrank();

    vm.startPrank(investor);
    maha.approve(address(launchpad), 10_000 ether);
    token.approve(address(launchpad), 10_000 ether);
    launchpad.presaleSwap(token, 10_000 ether, 0, true);
    launchpad.presaleSwap(token, 1000 ether, 0, false);
    vm.stopPrank();
  }
}

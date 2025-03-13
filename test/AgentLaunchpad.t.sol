// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

// import {TxChecker} from "../contracts/TxChecker.sol";

// import {FixedCurve} from "../contracts/curves/FixedCurve.sol";

import {IAgentLaunchpad} from "../contracts/interfaces/IAgentLaunchpad.sol";
import {IAgentToken} from "../contracts/interfaces/IAgentToken.sol";
import {AgentToken} from "../contracts/token/AgentToken.sol";
import {MockAerodromePool} from "../contracts/mocks/MockAerodromePool.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {AgentLaunchpad} from "contracts/launchpad/AgentLaunchpad.sol";
import {LaunchpadHook} from "contracts/hooks/LaunchpadHook.sol";
import {MockERC20} from "contracts/mocks/MockERC20.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

contract AgentLaunchpadTest is Test {
  AgentLaunchpad public launchpad;
  MockERC20 public maha;
  MockAerodromePool public aerodromeFactory;
  PoolManager public poolManager;
  LaunchpadHook public launchpadHook;


  address public owner = makeAddr("owner");

  //   address public creator = makeAddr("creator");
  //   address public investor = makeAddr("investor");
  //   address public feeDestination = makeAddr("feeDestination");
  //   address public governor = makeAddr("governor"); // todo write governor contract

  //   function setUp() public {
  //     launchpad = new AgentLaunchpad();
  //     maha = new MockERC20("Mock MAHA", "MAHA", 18);
  //     aerodromeFactory = new MockAerodromePool();
  //     txChecker = new TxChecker();
  //     curve = new FixedCurve();

  //     maha.mint(creator, 100_000_000 ether);
  //     maha.mint(investor, 100_000_000 ether);
  //   }

  function setUp() public {
    address odosRouter = makeAddr("odosRouter");
    // Deploy the core token first
    maha = new MockERC20("Mock MAHA", "MAHA", 18);
    // Deploy the aerodrome factory
    aerodromeFactory = new MockAerodromePool();
    // Deploy the Agent Token Implementation for launchapad
    IAgentToken tokenImpl = IAgentToken(new AgentToken());
    // Deploy the Pool Manager
    poolManager = new PoolManager(owner);

    // Deploy the hook to an address with the correct flags
    address flags = address(
      uint160(
        Hooks.AFTER_INITIALIZE_FLAG |
          Hooks.BEFORE_SWAP_FLAG |
          Hooks.AFTER_SWAP_FLAG |
          Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
      ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
    );

    // Mine a salt that will produce a hook address with the correct flags
    bytes memory constructorArgs = abi.encode(poolManager);
    deployCodeTo("LaunchpadHook.sol:LaunchpadHook", constructorArgs, flags);
    //Deploy the Launchpad Hook Contract
    launchpadHook = LaunchpadHook(flags);

    // Deploy the launchpad
    launchpad = new AgentLaunchpad();

    // Initialize the launchpad
    launchpad.initialize(
      address(maha),
      address(odosRouter),
      address(aerodromeFactory),
      address(tokenImpl),
      owner,
      address(launchpadHook),
      address(poolManager)
    );
  }

  //   function _initLaunchpad() internal {
  //     IAgentToken tokenImpl = IAgentToken(new AgentToken());
  //     launchpad.initialize(address(maha), address(aerodromeFactory), address(tokenImpl), owner);

  //     vm.startPrank(owner);
  //     launchpad.setSettings(100e18, 100 days, 1 days, 1000 ether, governor, address(txChecker), feeDestination, 0.1e18);
  //     launchpad.whitelist(address(txChecker), true);
  //     launchpad.whitelist(address(curve), true);
  //     launchpad.whitelist(address(maha), true);
  //     vm.stopPrank();
  //   }

  function testInit() public {
    assertEq(launchpad.owner(), owner, "owner !");
    assertEq(address(launchpad.coreToken()), address(maha), "Core token !");
    assertEq(launchpad.odos(), makeAddr("odosRouter"), "Odos Router !");
    assertEq(
      address(launchpad.aeroFactory()),
      address(aerodromeFactory),
      "Aerodrome Factory !"
    );
    assertEq(address(launchpad.hook()), address(launchpadHook), "Hook !");
    assertEq(
      address(launchpad.poolManager()),
      address(poolManager),
      "Pool Manager !"
    );
  }

  //   function test_fullLaunch() public {
  //     _initLaunchpad();

  //     vm.startPrank(creator);
  //     maha.approve(address(launchpad), 1000 ether);

  //     IAgentToken token = IAgentToken(
  //       launchpad.create(
  //         IAgentLaunchpad.CreateParams({
  //           bondingCurve: address(curve),
  //           fundingToken: maha,
  //           fundManagers: new address[](0),
  //           duration: 2 days,
  //           goal: 10_000 ether,
  //           limitPerWallet: 100_000_000 ether,
  //           metadata: "{}",
  //           name: "testing",
  //           salt: keccak256("test"),
  //           symbol: "test"
  //         })
  //       )
  //     );
  //     vm.stopPrank();

  //     vm.label(address(token), "token");

  //     vm.startPrank(investor);
  //     maha.approve(address(launchpad), type(uint256).max);
  //     token.approve(address(launchpad), type(uint256).max);

  //     launchpad.presaleSwap(token, 25_000_000 ether, 0, true); // maha in, token out

  //     launchpad.presaleSwap(token, 24_000_000 ether, 0, false); // token in, maha out
  //     vm.stopPrank();
  //   }
}

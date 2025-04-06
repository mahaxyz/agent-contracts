// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {WAGMIEToken} from "contracts/WAGMIEToken.sol";
import {RamsesAdapter} from "contracts/launchpad/clmm/dexes/RamsesAdapter.sol";

import {TokenLaunchpadTest} from "./TokenLaunchpadTest.sol";
import {IERC20, ITokenLaunchpad, ITokenTemplate} from "contracts/interfaces/ITokenLaunchpad.sol";
import {TokenLaunchpadLinea} from "contracts/launchpad/clmm/TokenLaunchpadLinea.sol";
import {MockERC20} from "contracts/mocks/MockERC20.sol";

contract TokenLaunchpadLineaForkTest is TokenLaunchpadTest {
  RamsesAdapter _adapter;

  string LINEA_RPC_URL = vm.envString("LINEA_RPC_URL");

  function setUp() public {
    uint256 lineaFork = vm.createFork(LINEA_RPC_URL);
    vm.selectFork(lineaFork);

    _setUpBase();

    address _nftManager = address(0xAAA78E8C4241990B4ce159E105dA08129345946A);

    _launchpad = new TokenLaunchpadLinea();
    _adapter = new RamsesAdapter();

    vm.label(address(_launchpad), "launchpad");
    vm.label(address(_adapter), "nileAdapter");
    vm.label(address(_locker), "locker");
    vm.label(address(_nftManager), "nftManager");

    _adapter.initialize(
      address(_launchpad),
      address(0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42),
      address(0xAAAE99091Fbb28D400029052821653C1C752483B),
      address(_weth),
      address(_locker),
      address(_nftManager)
    );
    _launchpad.initialize(address(_adapter), address(_tokenImpl), owner, address(_weth), address(_maha), 1000e18);
  }

  function test_create_basic() public {
    bytes32 salt = findValidTokenHash("Test Token", "TEST", creator, _weth);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      salt: salt,
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000,
      isFeeDiscounted: false
    });

    vm.prank(creator);
    _launchpad.createAndBuy{value: 100 ether}(params, address(0), 0);
  }

  function test_create_not_eth() public {
    MockERC20 _token = new MockERC20("Best Token", "BEST", 18);
    _token.mint(creator, 1_000_000_000 ether);
    vm.label(address(_token), "bestToken");

    bytes32 salt = findValidTokenHash("Test Token", "TEST", creator, _token);

    vm.startPrank(creator);
    _token.approve(address(_launchpad), 1_000_000_000 ether);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_token)),
      salt: salt,
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000,
      isFeeDiscounted: false
    });
    _launchpad.createAndBuy{value: 0.1 ether}(params, address(0), 10 ether);
  }

  // function test_create_not_eth_with_buy(uint256 salt) public {
  //   MockERC20 _token = new MockERC20("Test Token", "TEST", 18);

  //   ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
  //     name: "Test Token",
  //     symbol: "TEST",
  //     metadata: "Test metadata",
  //     fundingToken: IERC20(address(_token)),
  //     limitPerWallet: 1_000_000_000 ether,
  //     salt: bytes32(salt),
  //     launchTick: -171_000,
  //     graduationTick: -170_000,
  //     upperMaxTick: 887_000
  //   });

  //   vm.assume(true);
  //   address token = _launchpad.createAndBuy{value: 0.1 ether}(params, address(0), 0);

  //   vm.assertEq(_adapter.graduated(token), false);
  // }

  function test_createAndBuy_and_not_graduated() public {
    bytes32 salt = findValidTokenHash("Test Token", "TEST", owner, _weth);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      salt: salt,
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000,
      isFeeDiscounted: false
    });

    vm.prank(owner);
    (address _token,,) = _launchpad.createAndBuy{value: 100 ether}(params, address(0), 10 ether);
    ITokenTemplate token = ITokenTemplate(_token);
    vm.assertApproxEqAbs(token.balanceOf(owner), 257_291_080 ether, 1 ether);
  }

  function test_createAndBuy_and_graduated() public {
    bytes32 salt = findValidTokenHash("Test Token", "TEST", owner, _weth);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      salt: salt,
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000,
      isFeeDiscounted: false
    });

    vm.prank(owner);
    _launchpad.createAndBuy{value: 100.1 ether}(params, address(0), 100 ether);
  }

  function test_claimFees() public {
    bytes32 salt = findValidTokenHash("Test Token", "TEST", owner, _weth);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      salt: salt,
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000,
      isFeeDiscounted: false
    });

    vm.startPrank(owner);
    (address token,,) = _launchpad.createAndBuy{value: 100.1 ether}(params, address(0), 1 ether);
    _launchpad.claimFees(ITokenTemplate(token));
    vm.stopPrank();
  }

  function test_createAndBuy_and_fees() public {
    bytes32 salt = findValidTokenHash("Test Token", "TEST", owner, _weth);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      salt: salt,
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000,
      isFeeDiscounted: false
    });

    vm.startPrank(owner);
    _launchpad.setFeeSettings(address(this), 1 ether, 1 ether);

    // should revert because the fee is not set
    vm.expectRevert();
    _launchpad.createAndBuy{value: 0 ether}(params, address(0), 1 ether);

    // should succeed because the fee is set
    _launchpad.createAndBuy{value: 100 ether}(params, address(0), 1 ether);
    vm.stopPrank();
  }
}

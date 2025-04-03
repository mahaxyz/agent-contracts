// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {WAGMIEToken} from "contracts/WAGMIEToken.sol";
import {UniswapV4Adapter} from "contracts/launchpad/clmm/dexes/UniswapV4Adapter.sol";
import {IERC20, ITokenLaunchpad, ITokenTemplate} from "contracts/interfaces/ITokenLaunchpad.sol";
import {TokenLaunchpadBasic} from "contracts/launchpad/clmm/TokenLaunchpadBasic.sol";
import {MockERC20} from "contracts/mocks/MockERC20.sol";
import {Test} from "lib/forge-std/src/Test.sol";

contract TokenLaunchpadUnichainForkTest is Test {
  TokenLaunchpadBasic _launchpad;
  MockERC20 _weth;
  UniswapV4Adapter _adapter;
  WAGMIEToken _tokenImpl;
  address constant UNICHAIN_POSITION_MANAGER = 0x4529A01c7A0410167c5740C487A8DE60232617bf;
  address constant UNICHAIN_UNIVERSAL_ROUTER = 0xEf740bf23aCaE26f6492B10de645D6B98dC8Eaf3;
  address constant UNICHAIN_POOL_MANAGER = 0x1F98400000000000000000000000000000000004;
  address constant UNICHAIN_PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

  string UNICHAIN_RPC_URL = vm.envString("UNICHAIN_RPC_URL");
  address owner = makeAddr("owner");
  address whale = makeAddr("whale");

  receive() external payable {}

  function setUp() public {
    uint256 unichainFork = vm.createFork(UNICHAIN_RPC_URL);
    vm.selectFork(unichainFork);

    _launchpad = new TokenLaunchpadBasic();
    _adapter = new UniswapV4Adapter();
    _weth = new MockERC20("Wrapped Ether", "WETH", 18);
    _tokenImpl = new WAGMIEToken();

    vm.label(address(_launchpad), "launchpad");
    vm.label(address(_adapter), "unichainAdapter");
    vm.label(address(_weth), "weth");

    vm.deal(owner, 1000 ether);
    vm.deal(whale, 1000 ether);
    vm.deal(address(this), 100 ether);

    _adapter.initialize(address(_launchpad), UNICHAIN_POSITION_MANAGER, UNICHAIN_UNIVERSAL_ROUTER, UNICHAIN_POOL_MANAGER, UNICHAIN_PERMIT2, address(_weth));

    _launchpad.initialize(address(_adapter), address(_tokenImpl), owner, address(_weth));
  }

  function test_create() public {
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      limitPerWallet: 1_000_000_000 ether,
      salt: bytes32(0),
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000
    });

    address token = _launchpad.createAndBuy{value: 100 ether}(params, address(0), 0);

    vm.assertEq(_adapter.graduated(token), false);
  }

  function test_createAndBuy_and_not_graduated() public {
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      limitPerWallet: 1_000_000_000 ether,
      salt: keccak256("test"),
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000
    });

    vm.prank(owner);
    address _token = _launchpad.createAndBuy{value: 100 ether}(params, address(0), 10 ether);
    ITokenTemplate token = ITokenTemplate(_token);
    vm.assertApproxEqAbs(token.balanceOf(owner), 255_952_913 ether, 1 ether);
    vm.assertEq(_adapter.graduated(_token), false);
  }

  function test_createAndBuy_and_graduated() public {
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      limitPerWallet: 1_000_000_000 ether,
      salt: keccak256("test"),
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000
    });

    vm.prank(owner);
    address _token = _launchpad.createAndBuy{value: 100.1 ether}(params, address(0), 100 ether);
    vm.assertEq(_adapter.graduated(_token), true);
  }

  function test_createAndBuy_and_graduated_and_limit_per_wallet() public {
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      limitPerWallet: 100 ether,
      salt: keccak256("test"),
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000
    });

    vm.prank(owner);
    address token = _launchpad.createAndBuy{value: 100.1 ether}(params, address(0), 0);

    vm.startPrank(whale);
    _weth.mint(whale, 10_000 ether);
    _weth.approve(address(_adapter), 10_000 ether);

    vm.expectRevert();
    _adapter.swapForExactInput(IERC20(address(_weth)), IERC20(token), 1 ether, 0);

    vm.expectRevert();
    _adapter.swapForExactInput(IERC20(address(_weth)), IERC20(token), 100 ether, 0);

    vm.expectRevert();
    _adapter.swapForExactInput(IERC20(address(_weth)), IERC20(token), 1000 ether, 0);

    // should succeed
    _adapter.swapForExactInput(IERC20(address(_weth)), IERC20(token), 1000, 0);

    vm.stopPrank();
  }

  function test_claimFees() public {
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      limitPerWallet: 1_000_000_000 ether,
      salt: keccak256("test"),
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000
    });

    vm.startPrank(owner);
    address token = _launchpad.createAndBuy{value: 100.1 ether}(params, address(0), 1 ether);
    _launchpad.claimFees(ITokenTemplate(token));
    vm.stopPrank();
  }

  function test_createAndBuy_and_fees() public {
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      limitPerWallet: 1_000_000_000 ether,
      salt: keccak256("test"),
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000
    });

    vm.prank(owner);
    _launchpad.setFeeSettings(address(0x123), 1 ether);

    // should revert because the fee is not set
    vm.expectRevert();
    _launchpad.createAndBuy{value: 0 ether}(params, address(0), 1 ether);

    // should succeed because the fee is set
    _launchpad.createAndBuy{value: 100 ether}(params, address(0), 1 ether);
  }
}

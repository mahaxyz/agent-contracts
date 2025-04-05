// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {WAGMIEToken} from "contracts/WAGMIEToken.sol";
import {RamsesAdapter} from "contracts/launchpad/clmm/dexes/RamsesAdapter.sol";
import {FreeUniV3LPLocker} from "contracts/locker/FreeUniV3LPLocker.sol";

import {IERC20, ITokenLaunchpad, ITokenTemplate} from "contracts/interfaces/ITokenLaunchpad.sol";
import {TokenLaunchpadLinea} from "contracts/launchpad/clmm/TokenLaunchpadLinea.sol";
import {MockERC20} from "contracts/mocks/MockERC20.sol";
import {Test} from "lib/forge-std/src/Test.sol";
import {console} from "lib/forge-std/src/console.sol";

contract TokenLaunchpadLineaForkTest is Test {
  TokenLaunchpadLinea _launchpad;
  MockERC20 _weth;
  MockERC20 _maha;
  RamsesAdapter _adapter;
  WAGMIEToken _tokenImpl;
  FreeUniV3LPLocker _locker;

  string LINEA_RPC_URL = vm.envString("LINEA_RPC_URL");
  address owner = makeAddr("owner");
  address whale = address(0x123);
  address creator = makeAddr("creator");

  receive() external payable {}

  function setUp() public {
    uint256 lineaFork = vm.createFork(LINEA_RPC_URL);
    vm.selectFork(lineaFork);

    address _nftManager = address(0xAAA78E8C4241990B4ce159E105dA08129345946A);

    _launchpad = new TokenLaunchpadLinea();
    _adapter = new RamsesAdapter();
    _weth = new MockERC20("Wrapped Ether", "WETH", 18);
    _maha = new MockERC20("Maha", "MAHA", 18);
    _tokenImpl = new WAGMIEToken();
    _locker = new FreeUniV3LPLocker(_nftManager);

    vm.label(address(_launchpad), "launchpad");
    vm.label(address(_adapter), "nileAdapter");
    vm.label(address(_weth), "weth");
    vm.label(address(_maha), "maha");
    vm.label(address(whale), "whale");
    // vm.label(address(creator), "creator");
    vm.label(address(_locker), "locker");
    vm.label(address(_tokenImpl), "tokenImpl");
    vm.label(address(_nftManager), "nftManager");
    vm.deal(owner, 1000 ether);
    vm.deal(whale, 1000 ether);
    vm.deal(creator, 1000 ether);

    vm.deal(address(this), 100 ether);

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

  function test_create_basic(uint256 salt) public {
    assumeValidTokenAddress("Test Token", "TEST", salt, creator, _weth);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      limitPerWallet: 1_000_000_000 ether,
      salt: keccak256(abi.encode(salt)),
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000,
      isFeeDiscounted: false
    });

    vm.prank(creator);
    (address token,,) = _launchpad.createAndBuy{value: 100 ether}(params, address(0), 0);

    vm.assertEq(_adapter.graduated(token), false);
  }

  function test_create_not_eth(uint256 salt) public {
    MockERC20 _token = new MockERC20("Best Token", "BEST", 18);
    vm.label(address(_token), "bestToken");
    address target = assumeValidTokenAddress("Test Token", "TEST", salt, creator, _token);
    _token.mint(creator, 1_000_000_000 ether);

    vm.startPrank(creator);
    _token.approve(address(_launchpad), 1_000_000_000 ether);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_token)),
      limitPerWallet: 1_000_000_000 ether,
      salt: keccak256(abi.encode(salt)),
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000,
      isFeeDiscounted: false
    });
    vm.assume(true);
    (address token,,) = _launchpad.createAndBuy{value: 0.1 ether}(params, target, 10 ether);

    vm.assertEq(_adapter.graduated(token), false);
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

  function test_createAndBuy_and_not_graduated(uint256 salt) public {
    assumeValidTokenAddress("Test Token", "TEST", salt, owner, _weth);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      limitPerWallet: 1_000_000_000 ether,
      salt: keccak256(abi.encode(salt)),
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000,
      isFeeDiscounted: false
    });

    vm.prank(owner);
    (address _token,,) = _launchpad.createAndBuy{value: 100 ether}(params, address(0), 10 ether);
    ITokenTemplate token = ITokenTemplate(_token);
    vm.assertApproxEqAbs(token.balanceOf(owner), 255_952_913 ether, 1 ether);
    vm.assertEq(_adapter.graduated(_token), false);
  }

  function test_createAndBuy_and_graduated(uint256 salt) public {
    assumeValidTokenAddress("Test Token", "TEST", salt, owner, _weth);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      limitPerWallet: 1_000_000_000 ether,
      salt: keccak256(abi.encode(salt)),
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000,
      isFeeDiscounted: false
    });

    vm.prank(owner);
    (address _token,,) = _launchpad.createAndBuy{value: 100.1 ether}(params, address(0), 100 ether);
    vm.assertEq(_adapter.graduated(_token), true);
  }

  function test_createAndBuy_and_graduated_and_limit_per_wallet(uint256 salt) public {
    assumeValidTokenAddress("Test Token", "TEST", salt, owner, _weth);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      limitPerWallet: 100 ether,
      salt: keccak256(abi.encode(salt)),
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000,
      isFeeDiscounted: false
    });

    vm.prank(owner);
    (address token,,) = _launchpad.createAndBuy{value: 100.1 ether}(params, address(0), 0);

    vm.startPrank(whale);
    _weth.mint(whale, 10_000 ether);
    _weth.approve(address(_adapter), 10_000 ether);

    vm.expectRevert();
    _adapter.swapWithExactInput(IERC20(address(_weth)), IERC20(token), 1 ether, 0);

    vm.expectRevert();
    _adapter.swapWithExactInput(IERC20(address(_weth)), IERC20(token), 100 ether, 0);

    vm.expectRevert();
    _adapter.swapWithExactInput(IERC20(address(_weth)), IERC20(token), 1000 ether, 0);

    // should succeed
    _adapter.swapWithExactInput(IERC20(address(_weth)), IERC20(token), 1000, 0);

    vm.stopPrank();
  }

  function test_claimFees(uint256 salt) public {
    assumeValidTokenAddress("Test Token", "TEST", salt, owner, _weth);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      limitPerWallet: 1_000_000_000 ether,
      salt: keccak256(abi.encode(salt)),
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

  function test_createAndBuy_and_fees(uint256 salt) public {
    assumeValidTokenAddress("Test Token", "TEST", salt, owner, _weth);
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      limitPerWallet: 1_000_000_000 ether,
      salt: keccak256(abi.encode(salt)),
      launchTick: -171_000,
      graduationTick: -170_000,
      upperMaxTick: 887_000,
      isFeeDiscounted: false
    });

    vm.prank(owner);
    _launchpad.setFeeSettings(address(0x123), 1 ether);

    // should revert because the fee is not set
    vm.expectRevert();
    _launchpad.createAndBuy{value: 0 ether}(params, address(0), 1 ether);

    // should succeed because the fee is set
    _launchpad.createAndBuy{value: 100 ether}(params, address(0), 1 ether);
  }

  function assumeValidTokenAddress(
    string memory _name,
    string memory _symbol,
    uint256 _saltId,
    address _creator,
    MockERC20 _quoteToken
  ) private view returns (address) {
    bytes32 salt = keccak256(abi.encode(_saltId));
    bytes32 saltUser = keccak256(abi.encode(salt, _creator, _name, _symbol));
    address target = Clones.predictDeterministicAddress(address(_tokenImpl), saltUser, address(_launchpad));
    console.log("target", target);
    console.log("quoteToken", address(_quoteToken));
    console.log("quoteToken", target < address(_quoteToken));
    vm.assume(target < address(_quoteToken));
    return target;
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {PancakeAdapter} from "contracts/launchpad/clmm/dexes/PancakeAdapter.sol";
import {IERC20, ITokenLaunchpad, ITokenTemplate} from "contracts/interfaces/ITokenLaunchpad.sol";
import {MockERC20} from "contracts/mocks/MockERC20.sol";
import {WAGMIEToken} from "contracts/WAGMIEToken.sol";
import {TokenLaunchpadBSC} from "contracts/launchpad/clmm/TokenLaunchpadBSC.sol";

contract TokenLaunchpadBscForkTest is Test {
    // BSC Mainnet addresses
    address constant PANCAKE_FACTORY =
        0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
    address constant PANCAKE_ROUTER =
        0x1b81D678ffb9C0263b24A97847620C99d213eB14;

    TokenLaunchpadBSC _launchpad;
    PancakeAdapter _adapter;
    MockERC20 _weth;
    WAGMIEToken _tokenImpl;
    address owner = makeAddr("owner");
    address whale = makeAddr("whale");

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

        vm.deal(owner, 1000 ether);
        vm.deal(whale, 1000 ether);
        vm.deal(address(this), 100 ether);

        // Initialize adapter
        _adapter.initialize(
            address(_launchpad),
            PANCAKE_FACTORY,
            PANCAKE_ROUTER,
            address(_weth)
        );

        // Initialize launchpad
        _launchpad.initialize(
            address(_adapter),
            address(_tokenImpl),
            owner,
            address(_weth)
        );
    }

    function test_Initialize() public {
        assertEq(_adapter.launchpad(), address(_launchpad));
        assertEq(address(_adapter.poolFactory()), PANCAKE_FACTORY);
        assertEq(address(_adapter.swapRouter()), PANCAKE_ROUTER);
        assertEq(_adapter.WETH9(), address(_weth));

        assertEq(address(_launchpad.adapter()), address(_adapter));
        assertEq(_launchpad.owner(), owner);
        assertEq(address(_launchpad.weth()), address(_weth));
    }

    function test_create() public {
        ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad
            .CreateParams({
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

        address tokenAddr = _launchpad.createAndBuy{value: 100 ether}(
            params,
            address(0),
            0
        );

        assertTrue(tokenAddr != address(0), "Token address should not be zero");

        // Get the token contract
        WAGMIEToken token = WAGMIEToken(tokenAddr);

        assertEq(token.metadata(), "Test metadata", "Token metadata mismatch");
    }

    function test_createAndBuy_and_not_graduated() public {
        ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad
            .CreateParams({
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
        address _token = _launchpad.createAndBuy{value: 100 ether}(
            params,
            address(0),
            10 ether
        );
        ITokenTemplate token = ITokenTemplate(_token);
        vm.assertApproxEqAbs(
            token.balanceOf(owner),
            258_509_800 ether,
            1 ether
        );
        vm.assertEq(_adapter.graduated(_token), false);
    }

    function test_createAndBuy_and_graduated_and_limit_per_wallet() public {
        ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad
            .CreateParams({
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
        address token = _launchpad.createAndBuy{value: 100.1 ether}(
            params,
            address(0),
            0
        );

        vm.startPrank(whale);
        _weth.mint(whale, 10_000 ether);
        _weth.approve(address(_adapter), 10_000 ether);

        vm.expectRevert();
        _adapter.swapForExactInput(
            IERC20(address(_weth)),
            IERC20(token),
            1 ether,
            0
        );

        vm.expectRevert();
        _adapter.swapForExactInput(
            IERC20(address(_weth)),
            IERC20(token),
            100 ether,
            0
        );

        vm.expectRevert();
        _adapter.swapForExactInput(
            IERC20(address(_weth)),
            IERC20(token),
            1000 ether,
            0
        );

        // should succeed
        _adapter.swapForExactInput(
            IERC20(address(_weth)),
            IERC20(token),
            1000,
            0
        );

        vm.stopPrank();
    }

    function test_claimFees() public {
        ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad
            .CreateParams({
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
        address token = _launchpad.createAndBuy{value: 100.1 ether}(
            params,
            address(0),
            1 ether
        );
        _launchpad.claimFees(ITokenTemplate(token));
        vm.stopPrank();
    }

    function test_createAndBuy_and_fees() public {
        ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad
            .CreateParams({
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
    receive() external payable {}
    
}

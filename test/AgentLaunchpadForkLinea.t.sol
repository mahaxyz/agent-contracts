// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {AgentToken} from "../contracts/token/AgentToken.sol";
import {RamsesAdapter} from "contracts/launchpad/clmm/dexes/RamsesAdapter.sol";

import {IAgentLaunchpad, IERC20} from "contracts/interfaces/IAgentLaunchpad.sol";
import {AgentLaunchpad} from "contracts/launchpad/clmm/AgentLaunchpad.sol";
import {MockERC20} from "contracts/mocks/MockERC20.sol";
import {Test} from "lib/forge-std/src/Test.sol";

contract AgentLaunchpadForkLineaTest is Test {
  AgentLaunchpad _launchpad;
  MockERC20 _weth;
  RamsesAdapter _adapter;
  AgentToken _tokenImpl;
  string LINEA_RPC_URL = vm.envString("LINEA_RPC_URL");

  address owner = makeAddr("owner");

  function setUp() public {
    uint256 lineaFork = vm.createFork(LINEA_RPC_URL);
    vm.selectFork(lineaFork);

    //     constructor(address _launchpad, address _clPoolFactory) {
    //   LAUNCHPAD = _launchpad;
    //   CL_POOL_FACTORY = IClPoolFactory(_clPoolFactory);
    //   me = address(this);
    // }

    _launchpad = new AgentLaunchpad();
    _adapter = new RamsesAdapter();
    _weth = new MockERC20("Wrapped Ether", "WETH", 18);
    _tokenImpl = new AgentToken();

    vm.label(address(_launchpad), "launchpad");
    vm.label(address(_adapter), "nileAdapter");
    vm.label(address(_weth), "weth");

    _adapter.initialize(address(_launchpad), address(0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42));
    _launchpad.initialize(address(_weth), address(_adapter), address(_tokenImpl), owner);
  }

  function test_create() public {
    IAgentLaunchpad.CreateParams memory params = IAgentLaunchpad.CreateParams({
      base: IAgentLaunchpad.CreateParamsBase({
        name: "Test Token",
        symbol: "TEST",
        metadata: "Test metadata",
        fundingToken: IERC20(address(_weth)),
        fee: 3000,
        limitPerWallet: 1000,
        salt: bytes32(0)
      }),
      liquidity: IAgentLaunchpad.CreateParamsLiquidity({
        lowerTick: 46_020, // Price of 1 ETH per token (aligned to tick spacing of 60)
        upperTick: 46_080, // Price of 2 ETH per token (aligned to tick spacing of 60)
        upperMaxTick: 887_220 // Price of 100 ETH per token (aligned to tick spacing of 60)
      })
    });

    _launchpad.create(params, address(0));
  }
}

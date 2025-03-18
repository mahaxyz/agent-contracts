// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {AgentToken} from "../contracts/token/AgentToken.sol";
import {RamsesAdapter} from "contracts/launchpad/clmm/dexes/RamsesAdapter.sol";

import {IERC20, ITokenLaunchpad} from "contracts/interfaces/ITokenLaunchpad.sol";
import {TokenLaunchpadLinea} from "contracts/launchpad/clmm/TokenLaunchpadLinea.sol";
import {MockERC20} from "contracts/mocks/MockERC20.sol";
import {Test} from "lib/forge-std/src/Test.sol";

contract TokenLaunchpadLineaForkTest is Test {
  TokenLaunchpadLinea _launchpad;
  MockERC20 _weth;
  RamsesAdapter _adapter;
  AgentToken _tokenImpl;

  string LINEA_RPC_URL = vm.envString("LINEA_RPC_URL");
  address owner = makeAddr("owner");

  function setUp() public {
    uint256 lineaFork = vm.createFork(LINEA_RPC_URL);
    vm.selectFork(lineaFork);

    _launchpad = new TokenLaunchpadLinea();
    _adapter = new RamsesAdapter();
    _weth = new MockERC20("Wrapped Ether", "WETH", 18);
    _tokenImpl = new AgentToken();

    vm.label(address(_launchpad), "launchpad");
    vm.label(address(_adapter), "nileAdapter");
    vm.label(address(_weth), "weth");

    _adapter.initialize(address(_launchpad), address(0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42));
    _launchpad.initialize(address(_adapter), address(_tokenImpl), owner);
  }

  function test_create() public {
    ITokenLaunchpad.CreateParams memory params = ITokenLaunchpad.CreateParams({
      name: "Test Token",
      symbol: "TEST",
      metadata: "Test metadata",
      fundingToken: IERC20(address(_weth)),
      fee: 3000,
      limitPerWallet: 1000,
      salt: bytes32(0),
      launchTick: 46_020,
      graduationTick: 46_080,
      upperMaxTick: 887_220
    });

    _launchpad.create(params, address(0));
  }
}

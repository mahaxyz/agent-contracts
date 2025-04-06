// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {WAGMIEToken} from "contracts/WAGMIEToken.sol";
import {IERC20, ITokenLaunchpad} from "contracts/interfaces/ITokenLaunchpad.sol";
import {TokenLaunchpad} from "contracts/launchpad/clmm/TokenLaunchpad.sol";

import {IFreeUniV3LPLocker} from "contracts/interfaces/IFreeUniV3LPLocker.sol";
import {MockERC20} from "contracts/mocks/MockERC20.sol";
import {Test} from "lib/forge-std/src/Test.sol";

contract TokenLaunchpadTest is Test {
  MockERC20 _weth;
  MockERC20 _maha;
  WAGMIEToken _tokenImpl;
  TokenLaunchpad _launchpad;
  address _locker;

  address owner = makeAddr("owner");
  address whale = makeAddr("whale");
  address creator = makeAddr("creator");

  function _setUpBase() internal {
    _weth = new MockERC20("Wrapped Ether", "WETH", 18);
    _maha = new MockERC20("Maha", "MAHA", 18);

    vm.label(address(_weth), "weth");
    vm.label(address(_maha), "maha");
    vm.deal(owner, 1000 ether);
    vm.deal(whale, 1000 ether);
    vm.deal(creator, 1000 ether);

    vm.deal(address(this), 100 ether);
  }

  function findValidTokenHash(string memory _name, string memory _symbol, address _creator, MockERC20 _quoteToken)
    internal
    view
    returns (bytes32)
  {
    for (uint256 i = 0; i < 100; i++) {
      bytes32 salt = keccak256(abi.encode(i));
      bytes32 saltUser = keccak256(abi.encode(salt, _creator, _name, _symbol));
      address target = Clones.predictDeterministicAddress(address(_tokenImpl), saltUser, address(_launchpad));
      if (target < address(_quoteToken)) return salt;
    }

    require(false, "No valid token address found");
    return bytes32(0);
  }

  receive() external payable {
    // do nothing; we're not using this
  }
}

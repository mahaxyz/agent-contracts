// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {WAGMIEToken} from "contracts/WAGMIEToken.sol";
import {IERC20, ITokenLaunchpad} from "contracts/interfaces/ITokenLaunchpad.sol";
import {TokenLaunchpad} from "contracts/launchpad/TokenLaunchpad.sol";

import {AirdropRewarder} from "contracts/airdrop/AirdropRewarder.sol";
import {IFreeUniV3LPLocker} from "contracts/interfaces/IFreeUniV3LPLocker.sol";
import {MockERC20} from "contracts/mocks/MockERC20.sol";
import {Test} from "lib/forge-std/src/Test.sol";

import "forge-std/console.sol";

contract TokenLaunchpadTest is Test {
  MockERC20 _weth;
  MockERC20 _maha;
  MockERC20 _stakingToken;

  TokenLaunchpad _launchpad;
  AirdropRewarder _airdropRewarder;
  address owner = makeAddr("owner");
  address whale = makeAddr("whale");
  address creator = makeAddr("creator");
  address feeDestination = makeAddr("feeDestination");

  function _setUpBase() internal {
    _weth = new MockERC20("Wrapped Ether", "WETH", 18);
    _maha = new MockERC20("Maha", "MAHA", 18);
    _stakingToken = new MockERC20("Staking Token", "STK", 18);

    // _launchpad = new TokenLaunchpad();

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
    // Get the runtime bytecode of WAGMIEToken
    bytes memory bytecode = type(WAGMIEToken).creationCode;

    // Maximum number of attempts to find a valid address
    uint256 maxAttempts = 100;

    for (uint256 i = 0; i < maxAttempts; i++) {
      bytes32 salt = keccak256(abi.encode(i));
      bytes32 saltUser = keccak256(abi.encode(salt, _creator, _name, _symbol));

      // Calculate CREATE2 address
      bytes memory creationCode = abi.encodePacked(bytecode, abi.encode(_name, _symbol));
      bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(_launchpad), saltUser, keccak256(creationCode)));
      address target = address(uint160(uint256(hash)));

      if (target < address(_quoteToken)) {
        console.log("Found valid salt after %d attempts", i + 1);
        return salt;
      }
    }

    revert(
      "No valid token address found after 100 attempts. Try increasing maxAttempts or using a different quote token."
    );
  }

  receive() external payable {
    // do nothing; we're not using this
  }
}

// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝    ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Telegram: https://t.me/mahaxyz
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {IStakeRewardsStrategy} from "contracts/interfaces/IStakeRewardsStrategy.sol";

contract MerkleRewardsStrategy is IStakeRewardsStrategy {
  address public immutable MERKLE_DISTRIBUTOR;
  address public immutable ODOS;

  constructor(address _merkleDistributor, address _odos) {
    MERKLE_DISTRIBUTOR = _merkleDistributor;
    ODOS = _odos;
  }

  function distributeRewards(
    address _token0,
    address _token1,
    uint256 _amount0,
    uint256 _amount1,
    RewardsConfigData calldata _data
  ) external override {
    IERC20(_token0).transferFrom(msg.sender, address(this), _amount0);
    IERC20(_token1).transferFrom(msg.sender, address(this), _amount1);

    // swap _amount0 for _token1
    (bool success,) = ODOS.call(_data.extraData);
    require(success, "ODOS call failed");

    // make the call to merkle distributor to make the campaign
    // MERKLE_DISTRIBUTOR.call(abi.encode(msg.sender, _token0, _token1, _amount0, _amount1, _data));
  }
}

// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {AgentTokenBase} from "./AgentTokenBase.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract AgentToken is AgentTokenBase {
  function initialize(InitParams memory p) public initializer {
    limitPerWallet = p.limitPerWallet;
    metadata = p.metadata;
    unlocked = false;

    __ERC20_init(p.name, p.symbol);

    _mint(msg.sender, 1_000_000_000 * 1e18); // 1 bn supply

    for (uint256 index = 0; index < p.whitelisted.length; index++) {
      whitelisted[p.whitelisted[index]] = true;
    }

    // todo add event
  }
}

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

import {AgentTokenBase, ICLMMAdapter} from "./AgentTokenBase.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract AgentToken is AgentTokenBase {
  function initialize(InitParams memory p) public initializer {
    limitPerWallet = p.limitPerWallet;
    metadata = p.metadata;
    unlocked = false;
    adapter = ICLMMAdapter(p.adapter);

    __ERC20_init(p.name, p.symbol);

    whitelisted[msg.sender] = true;
    whitelisted[address(adapter)] = true;
    whitelisted[address(0)] = true;
    _mint(msg.sender, 1_000_000_000 * 1e18); // 1 bn supply

    // todo add event
  }
}

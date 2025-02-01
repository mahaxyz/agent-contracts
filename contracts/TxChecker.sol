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

import {ITxChecker} from "./interfaces/ITxChecker.sol";

contract TxChecker is ITxChecker {
  function checkTransaction(
    address _to,
    uint256 _value,
    bytes memory _data,
    address _caller
  ) external view returns (bool) {
    require(_caller != address(this), "!txChecker");
    require(_to != address(this), "!txChecker");
    require(_value == 0, "!txChecker");
    require(_data.length >= 0, "!txChecker");
    return true;
  }
}

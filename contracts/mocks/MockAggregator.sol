// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://wagmie.com
// Telegram: https://t.me/mahaxyz
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockAggregator is Ownable {
  int256 public latestAnswer;

  constructor(int256 _answer) Ownable(msg.sender) {
    latestAnswer = _answer;
  }

  function setAnswer(int256 _answer) external onlyOwner {
    latestAnswer = _answer;
  }

  function decimals() external pure returns (uint8) {
    return 8;
  }
}

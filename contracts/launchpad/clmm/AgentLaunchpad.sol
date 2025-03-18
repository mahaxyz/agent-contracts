// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝    ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Twitter: https://twitter.com/mahaxyz_

pragma solidity ^0.8.0;

import {AgentLaunchpadLocker} from "./AgentLaunchpadLocker.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAgentToken} from "contracts/interfaces/IAgentToken.sol";
import {ICLMMAdapter} from "contracts/interfaces/ICLMMAdapter.sol";

contract AgentLaunchpad is AgentLaunchpadLocker {
  function initialize(address _coreToken, address _adapter, address _tokenImplementation, address _owner)
    external
    initializer
  {
    coreToken = IERC20(_coreToken);
    adapter = ICLMMAdapter(_adapter);
    tokenImplementation = _tokenImplementation;
    __Ownable_init(_owner);
    __ERC721_init("WAGMIE Launchpad", "WAGMIE");
  }

  function setSettings(uint256 _creationFee) external onlyOwner {
    creationFee = _creationFee;
  }

  function whitelist(address _address, bool _what) external onlyOwner {
    whitelisted[_address] = _what;
    // todo add event
  }

  function create(CreateParams memory p, address expected) external payable returns (address) {
    if (creationFee > 0) {
      require(msg.value >= creationFee, "!creationFee");
      payable(feeDestination).transfer(creationFee);
    }

    IAgentToken.InitParams memory params = IAgentToken.InitParams({
      name: p.base.name,
      symbol: p.base.symbol,
      metadata: p.base.metadata,
      limitPerWallet: p.base.limitPerWallet,
      adapter: address(adapter)
    });

    bytes32 salt = keccak256(abi.encode(p.base.salt, msg.sender, p.base.name, p.base.symbol));

    IAgentToken token = IAgentToken(Clones.cloneDeterministic(tokenImplementation, salt));
    require(expected == address(0) || address(token) == expected, "Invalid token address");

    token.initialize(params);
    tokens.push(token);
    tokenToNftId[token] = tokens.length;
    launchParams[token] = p;

    token.approve(address(adapter), type(uint256).max);

    adapter.addSingleSidedLiquidity(
      token, // IERC20 _tokenBase,
      p.base.fundingToken, // IERC20 _tokenQuote,
      p.base.fee, // uint24 _fee,
      p.liquidity.lowerTick, // int24 _tick0,
      p.liquidity.upperTick, // int24 _tick1,
      p.liquidity.upperMaxTick // int24 _tick2
    );

    _mint(msg.sender, tokenToNftId[token]);

    return address(token);
  }

  function getTotalTokens() external view returns (uint256) {
    return tokens.length;
  }
}

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

import {Pool, IPool} from "contracts/aerodrome/Pool.sol";

error SameAddress();
error ZeroAddress();

contract MockAerodromeFactory {
  mapping(address => mapping(address => mapping(bool => address)))
    public getPool_;
  address[] public allPools_;
  mapping(address => bool) public isPool_; // simplified check if its a pool, given that `stable` flag might not be
  address public voter;
  event PoolCreated(
    address indexed token0,
    address indexed token1,
    bool indexed stable,
    address pool,
    uint256
  );

  constructor() {
    voter = msg.sender;
  }

  function getPool(
    address tokenA,
    address tokenB,
    bool stable
  ) external view returns (address) {
    return getPool_[tokenA][tokenB][stable];
  }

  function createPool(
    address tokenA,
    address tokenB,
    bool stable
  ) public returns (address pool) {
    if (tokenA == tokenB) revert SameAddress();
    (address token0, address token1) = tokenA < tokenB
      ? (tokenA, tokenB)
      : (tokenB, tokenA);
    if (token0 == address(0)) revert ZeroAddress();
    // bytes32 salt = keccak256(abi.encodePacked(token0, token1, stable)); // salt includes stable as well, 3 parameters
    pool = address(new Pool());
    IPool(pool).initialize(token0, token1, stable);
    getPool_[token0][token1][stable] = pool;
    getPool_[token1][token0][stable] = pool; // populate mapping in the reverse direction
    allPools_.push(pool);
    isPool_[pool] = true;
    emit PoolCreated(token0, token1, stable, pool, allPools_.length);
  }
}

// SPDX-License-Identifier: BUSL-1.1

// ███╗   ███╗ █████╗ ██╗  ██╗ █████╗
// ████╗ ████║██╔══██╗██║  ██║██╔══██╗
// ██╔████╔██║███████║███████║███████║
// ██║╚██╔╝██║██╔══██║██╔══██║██╔══██║
// ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║
// ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝

// Website: https://maha.xyz
// Discord: https://discord.gg/mahadao
// Telegram: https://t.me/mahaxyz
// Twitter: https://twitter.com/mahaxyz

pragma solidity ^0.8.0;

import "./pool/IPancakePoolActions.sol";
import "./pool/IPancakePoolDerivedState.sol";

import "./pool/IPancakePoolEvents.sol";
import "./pool/IPancakePoolImmutables.sol";
import "./pool/IPancakePoolOwnerActions.sol";
import "./pool/IPancakePoolState.sol";

/// @title The interface for a PancakeSwap V3 Pool
/// @notice A PancakeSwap pool facilitates swapping and automated market making between any two assets that strictly
/// conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IPancakePool is
  IPancakePoolImmutables,
  IPancakePoolState,
  IPancakePoolDerivedState,
  IPancakePoolActions,
  IPancakePoolOwnerActions,
  IPancakePoolEvents
{}

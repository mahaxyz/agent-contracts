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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ILocker} from "./interfaces/ILocker.sol";

contract Locker is ILocker {
    mapping(address => mapping(address => TokenLock)) public tokenLocks;
    mapping(address => mapping(address => NFTLock)) public nftLocks;

    function lockTokens(address token, uint256 amount, uint256 duration) external {
        require(amount > 0, "Amount must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        require(tokenLocks[msg.sender][token].amount == 0, "lock exists");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        tokenLocks[msg.sender][token] = TokenLock({amount: amount, startTime: block.timestamp, duration: duration});
    }

    function releaseTokens(address token) external {
        TokenLock storage lock = tokenLocks[msg.sender][token];
        require(lock.amount > 0, "No tokens locked");

        uint256 elapsedTime = block.timestamp - lock.startTime;
        uint256 releasableAmount = (lock.amount * elapsedTime) / lock.duration;

        if (elapsedTime >= lock.duration) {
            releasableAmount = lock.amount;
        }

        require(releasableAmount > 0, "No tokens to release");

        lock.amount -= releasableAmount;
        IERC20(token).transfer(msg.sender, releasableAmount);

        if (lock.amount == 0) {
            delete tokenLocks[msg.sender][token];
        }
    }

    function lockNFT(address nft, uint256 tokenId, uint256 duration) external {
        require(duration > 0, "Duration must be greater than 0");
        require(nftLocks[msg.sender][nft].tokenId == 0, "lock exists");

        IERC721(nft).transferFrom(msg.sender, address(this), tokenId);

        nftLocks[msg.sender][nft] = NFTLock({tokenId: tokenId, releaseTime: block.timestamp + duration});
    }

    function releaseNFT(address nft) external {
        NFTLock storage lock = nftLocks[msg.sender][nft];
        require(lock.tokenId != 0, "No NFT locked");
        require(block.timestamp >= lock.releaseTime, "NFT is still locked");

        uint256 tokenId = lock.tokenId;
        delete nftLocks[msg.sender][nft];

        IERC721(nft).transferFrom(address(this), msg.sender, tokenId);
    }
}

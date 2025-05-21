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

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Upgradeable, ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import {IAchievementNFT} from "./interfaces/IAchievementNFT.sol";

/**
 * @title AchievementNFT
 * @dev An NFT contract that mints achievement tokens when users complete milestones
 */
contract AchievementNFT is IAchievementNFT, OwnableUpgradeable, ERC721EnumerableUpgradeable {
    uint256 public nextTokenId = 1;

    // Minter role for authorized addresses (backend)
    mapping(address => bool) public minters;

    // Token ID to achievement mapping
    mapping(uint256 => Achievement) private _achievements;

    modifier onlyMinter() {
        require(minters[msg.sender], "AchievementNFT: caller is not a minter");
        _;
    }

    //@inheritdoc IAchievementNFT
    function initialize(
        string memory name_,
        string memory symbol_,
        address backend
    ) external initializer {
        __Ownable_init(msg.sender);
        __ERC721_init(name_, symbol_);
        __ERC721Enumerable_init();
        minters[backend] = true;
    }

    //@inheritdoc IAchievementNFT
    function addMinter(address minter) external onlyOwner {
        require(minter != address(0), "AchievementNFT: minter is the zero address");
        require(!minters[minter], "AchievementNFT: account is already a minter");
        
        minters[minter] = true;
        emit MinterAdded(minter);
    }

    //@inheritdoc IAchievementNFT
    function removeMinter(address minter) external onlyOwner {
        require(minters[minter], "AchievementNFT: account is not a minter");
        
        minters[minter] = false;
        emit MinterRemoved(minter);
    }

    //@inheritdoc IAchievementNFT
    function mintAchievement(
        address to,
        Achievement memory achievement
    ) external onlyMinter returns (uint256) {
        return _mintSingleAchievement(to, achievement);
    }

    //@inheritdoc IAchievementNFT
    function batchMintAchievements(
        address[] memory recipients,
        Achievement[] memory achievements
    ) external onlyMinter returns (uint256[] memory) {
        require(
            recipients.length == achievements.length,
            "AchievementNFT: array length mismatch"
        );
        
        uint256[] memory tokenIds = new uint256[](recipients.length);
        
        for (uint256 i = 0; i < recipients.length; i++) {
            tokenIds[i] = _mintSingleAchievement(
                recipients[i],
                achievements[i]
            );
        }
        
        return tokenIds;
    }

    //@inheritdoc IAchievementNFT
    function getAchievement(uint256 tokenId) external view returns (Achievement memory) {
        require(tokenId < nextTokenId, "AchievementNFT: achievement query for nonexistent token");
        return _achievements[tokenId];
    }

    //@inheritdoc IAchievementNFT
    function getAchievementsByOwner(address owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](balance);
        
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        
        return tokenIds;
    }

    function _mintSingleAchievement(
        address to,
        Achievement memory achievement
    ) internal returns (uint256) {
        require(to != address(0), "AchievementNFT: mint to the zero address");
        
        uint256 tokenId = nextTokenId++;
        
        _safeMint(to, tokenId);
        
        _achievements[tokenId] = achievement;
        
        emit AchievementMinted(to, tokenId, achievement.achievementType);
        
        return tokenId;
    }

} 
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

import {IAchievementNFT} from "./interfaces/IAchievementNFT.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title AchievementNFT
 * @dev An NFT contract that mints achievement tokens when users complete milestones
 */
contract AchievementNFT is IAchievementNFT, Ownable, ERC721Enumerable {
  using Strings for string;
  using Strings for uint256;

  uint256 public nextTokenId = 1;
  mapping(address => bool) public minters;
  mapping(uint256 => Achievement) public achievements;
  string public baseURI;

  constructor(string memory name_, string memory symbol_, string memory baseURI_)
    Ownable(msg.sender)
    ERC721(name_, symbol_)
  {
    baseURI = baseURI_;
  }

  /// @inheritdoc IAchievementNFT
  function toggleMinter(address minter) external onlyOwner {
    require(minter != address(0), "AchievementNFT: minter is the zero address");
    require(!minters[minter], "AchievementNFT: account is already a minter");

    minters[minter] = !minters[minter];
    emit MinterToggled(minter, minters[minter]);
  }

  /// @inheritdoc IAchievementNFT
  function mint(Achievement memory achievement, bytes memory signature) external returns (uint256) {
    bytes32 messageHash = keccak256(abi.encode(msg.sender, achievement));
    (address signer, ECDSA.RecoverError err,) = ECDSA.tryRecover(messageHash, signature);
    require(err == ECDSA.RecoverError.NoError && minters[signer], "AchievementNFT: invalid signature");

    uint256 tokenId = nextTokenId++;

    _safeMint(msg.sender, tokenId);
    achievements[tokenId] = achievement;

    emit AchievementMinted(
      msg.sender,
      tokenId,
      achievement.token,
      achievement.campaignId,
      achievement.score,
      achievement.title,
      achievement.description
    );

    return tokenId;
  }

  function _update(address to, uint256 tokenId, address auth) internal virtual override returns (address) {
    super._update(to, tokenId, auth);
    // disable transfers for any user
    require(auth == address(0), "AchievementNFT: transfers are disabled");
    return address(0);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }
}

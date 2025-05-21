// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

/**
 * @title IAchievementNFT
 * @dev Interface for the AchievementNFT contract
 */
interface IAchievementNFT {
  /**
   * @dev Achievement data structure
   */
  struct Achievement {
    string name;
    string description;
    uint256 achievementType;
  }

  /**
   * @dev Emitted when a new minter is added
   */
  event MinterAdded(address indexed minter);

  /**
   * @dev Emitted when a minter is removed
   */
  event MinterRemoved(address indexed minter);

  /**
   * @dev Emitted when an achievement is minted
   */
  event AchievementMinted(address indexed user, uint256 indexed tokenId, uint256 achievementType);

  /**
   * @dev Initializes the contract
   * @param name_ Name of the NFT collection
   * @param symbol_ Symbol of the NFT collection
   * @param backend Address of the contract backend
   */
  function initialize(string memory name_, string memory symbol_, address backend) external;

  /**
   * @dev Adds a new minter address
   * @param minter The address to add as a minter
   */
  function addMinter(address minter) external;

  /**
   * @dev Removes a minter address
   * @param minter The address to remove as a minter
   */
  function removeMinter(address minter) external;

  /**
   * @dev Mints a new achievement NFT to the specified user address
   * @param to The recipient address
   * @param achievement The achievement details
   * @return The minted token ID
   */
  function mintAchievement(address to, Achievement memory achievement) external returns (uint256);

  /**
   * @dev Batch mint achievement NFTs to multiple users
   * @param recipients Array of recipient addresses
   * @param achievements Array of achievement details
   * @return Array of minted token IDs
   */
  function batchMintAchievements(address[] memory recipients, Achievement[] memory achievements)
    external
    returns (uint256[] memory);

  /**
   * @dev Gets the achievement details for a token ID
   * @param tokenId The token ID
   * @return The achievement details
   */
  function getAchievement(uint256 tokenId) external view returns (Achievement memory);

  /**
   * @dev Gets all achievements owned by a user
   * @param owner The owner address
   * @return Array of token IDs owned by the user
   */
  function getAchievementsByOwner(address owner) external view returns (uint256[] memory);
}

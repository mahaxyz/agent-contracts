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

import {IAeroPool} from "./IAeroPool.sol";
import {IAeroPoolFactory} from "./IAeroPoolFactory.sol";
import {IAgentToken} from "./IAgentToken.sol";
import {IBondingCurve} from "./IBondingCurve.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAgentLaunchpad {
  event TokenCreated(
    address indexed token,
    address indexed creator,
    string name,
    string symbol,
    uint256 limitPerWallet,
    uint256 goal,
    uint256 duration,
    string metadata,
    address bondingCurve,
    bytes32 salt
  );

  struct CreateParams {
    address bondingCurve;
    bytes32 salt;
    string metadata;
    string name;
    string symbol;
    uint256 goal;
    uint256 tokensToSell;
    uint256 limitPerWallet;
    IERC20 fundingToken;
  }

  struct LiquidityLock {
    IAeroPool liquidityToken;
    uint256 amount;
  }

  event LiquidityLocked(address indexed token, address indexed pool, uint256 amount);
  event TokensPurchased(
    address indexed token,
    address indexed quoteToken,
    address indexed buyer,
    address destination,
    uint256 assetsIn,
    uint256 tokensOut,
    uint256 price
  );
  event TokensSold(
    address indexed token,
    address indexed quoteToken,
    address indexed seller,
    address destination,
    uint256 assetsOut,
    uint256 tokensIn,
    uint256 price
  );
  event SettingsUpdated(
    uint256 creationFee,
    uint256 maxDuration,
    uint256 minDuration,
    uint256 minFundingGoal,
    address governor,
    address checker,
    address feeDestination,
    uint256 feeCutE18
  );
  event TokenGraduated(address indexed token, uint256 assetsRaised);

  /// @notice Returns the token at the specified index
  /// @param index The index of the token
  /// @return token The token at the specified index
  function tokens(uint256 index) external view returns (IERC20 token);

  /// @notice Checks if an account is whitelisted
  /// @param account The account to check
  /// @return whitelisted True if the account is whitelisted, false otherwise
  function whitelisted(address account) external view returns (bool whitelisted);

  /// @notice Returns the creation fee
  /// @return fee The creation fee
  function creationFee() external view returns (uint256 fee);

  /// @notice Returns the maximum duration
  /// @return duration The maximum duration
  function maxDuration() external view returns (uint256 duration);

  /// @notice Returns the minimum duration
  /// @return duration The minimum duration
  function minDuration() external view returns (uint256 duration);

  /// @notice Returns the minimum funding goal
  /// @return goal The minimum funding goal
  function minFundingGoal() external view returns (uint256 goal);

  /// @notice Returns the address of the governor
  /// @return what The address of the governor
  function governor() external view returns (address what);

  /// @notice Returns the address of the checker
  /// @return what The address of the checker
  function checker() external view returns (address what);

  /// @notice Returns the address of the fee destination
  /// @return what The address of the fee destination
  function feeDestination() external view returns (address what);

  /// @notice Returns the fee cut in E18 format
  /// @return fee The fee cut in E18 format
  function feeCutE18() external view returns (uint256 fee);

  /// @notice Returns the AeroPoolFactory instance
  /// @return factory The AeroPoolFactory instance
  function aeroFactory() external view returns (IAeroPoolFactory factory);

  /// @notice Returns the core token
  /// @return token The core token
  function coreToken() external view returns (IERC20 token);

  /// @notice Returns the bonding curve for a given token
  /// @param token The token to get the bonding curve for
  /// @return curve The bonding curve for the given token
  function curves(IAgentToken token) external view returns (IBondingCurve curve);

  /// @notice Returns the funding goal for a given token
  /// @param token The token to get the funding goal for
  /// @return goal The funding goal for the given token
  function fundingGoals(IAgentToken token) external view returns (uint256 goal);

  /// @notice Returns the funding progress for a given token
  /// @param token The token to get the funding progress for
  /// @return progress The funding progress for the given token
  function fundingProgress(IAgentToken token) external view returns (uint256 progress);

  /// @notice Claims the fees for a given token
  /// @param token The token to claim the fees for
  function claimFees(address token) external;

  /// @notice Performs a presale swap
  /// @param token The token to swap
  /// @param amountIn The amount of tokens to swap in
  /// @param minAmountOut The minimum amount of tokens to receive
  /// @param buy True if buying, false if selling
  function presaleSwap(IAgentToken token, address destination, uint256 amountIn, uint256 minAmountOut, bool buy)
    external;

  function presaleSwapWithOdos(
    IAgentToken token,
    address destination,
    uint256 tokensToBuyOrSell,
    uint256 minAmountOut,
    bool buy,
    IERC20 inputToken,
    uint256 inputAmount,
    bytes memory data
  ) external payable;

  /// @notice Graduates a given token
  /// @param token The token to graduate
  function graduate(IAgentToken token) external;

  /// @notice Checks if the funding goal is met for a given token
  /// @param token The token to check the funding goal for
  /// @return True if the funding goal is met, false otherwise
  function checkFundingGoalMet(IAgentToken token) external view returns (bool);

  /// @notice Initializes the contract with the given parameters
  /// @param _fundingToken The funding token
  /// @param _aeroFactory The AeroPoolFactory instance
  /// @param _owner The owner of the contract
  function initialize(
    address _fundingToken,
    address _odos,
    address _aeroFactory,
    address _tokenImplementation,
    address _owner
  ) external;

  /// @notice Sets the settings for the contract
  /// @param _creationFee The creation fee
  /// @param _maxDuration The maximum duration
  /// @param _minDuration The minimum duration
  /// @param _minFundingGoal The minimum funding goal
  /// @param _governor The address of the governor
  /// @param _checker The address of the checker
  /// @param _feeDestination The address of the fee destination
  /// @param _feeCutE18 The fee cut in E18 format
  function setSettings(
    uint256 _creationFee,
    uint256 _maxDuration,
    uint256 _minDuration,
    uint256 _minFundingGoal,
    address _governor,
    address _checker,
    address _feeDestination,
    uint256 _feeCutE18
  ) external;

  /// @notice Whitelists or removes an address from the whitelist
  /// @param _address The address to whitelist or remove from the whitelist
  /// @param _what True to whitelist, false to remove from the whitelist
  function whitelist(address _address, bool _what) external;

  /// @notice Creates a new entity with the given parameters
  /// @param p The parameters for creation
  function create(CreateParams memory p) external returns (address);

  /// @notice Returns the total number of tokens
  /// @return total The total number of tokens
  function getTotalTokens() external view returns (uint256 total);
}

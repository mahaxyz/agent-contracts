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

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ITokenLaunchpad Interface
/// @notice Interface for the TokenLaunchpad contract that handles token launches
interface ITokenLaunchpad {
  /// @notice Parameters required to create a new token launch
  /// @param name The name of the token
  /// @param symbol The symbol of the token
  /// @param metadata IPFS hash or other metadata about the token
  /// @param fundingToken The token used for funding the launch
  /// @param salt Random value to ensure unique deployment address
  /// @param launchTick The tick at which the token launches
  /// @param graduationTick The tick that must be reached for graduation
  /// @param upperMaxTick The maximum tick allowed
  /// @param isFeeDiscounted Whether the fee is discounted
  struct CreateParams {
    string name;
    string symbol;
    string metadata;
    IERC20 fundingToken;
    bytes32 salt;
    int24 launchTick;
    int24 graduationTick;
    int24 upperMaxTick;
    bool isFeeDiscounted;
  }

  /// @notice Emitted when fee settings are updated
  /// @param feeDestination The address where fees will be sent
  /// @param fee The new fee amount
  event FeeUpdated(address indexed feeDestination, uint256 fee);

  /// @notice Emitted when a token is launched
  /// @param token The token that was launched
  /// @param pool The address of the pool for the token
  /// @param params The parameters used to launch the token
  event TokenLaunched(IERC20 indexed token, address indexed pool, CreateParams params);

  /// @notice Emitted when referral settings are updated
  /// @param referralDestination The address where referrals will be sent
  /// @param referralFee The new referral fee amount
  event ReferralUpdated(address indexed referralDestination, uint256 referralFee);

  /// @notice Emitted when a token is launched
  /// @param token The token that was launched
  /// @param fundingToken The token used for funding the launch
  /// @param launchTick The tick at which the token launches
  /// @param graduationTick The tick that must be reached for graduation
  /// @param upperMaxTick The maximum tick allowed
  event TokenLaunchParams(
    IERC20 token,
    IERC20 fundingToken,
    int24 launchTick,
    int24 graduationTick,
    int24 upperMaxTick,
    string name,
    string symbol,
    string metadata
  );

  /// @notice Initializes the launchpad contract
  /// @param _adapter The DEX adapter contract address
  /// @param _owner The owner address
  /// @param _weth The WETH9 contract address
  /// @param _feeDiscountToken The token used for fee discount
  /// @param _feeDiscountAmount The amount of fee discount
  function initialize(
    address _adapter,
    address _owner,
    address _weth,
    address _feeDiscountToken,
    uint256 _feeDiscountAmount
  ) external;

  /// @notice Updates the referral settings
  /// @param _referralDestination The address to receive referrals
  /// @param _referralFee The new referral fee amount
  function setReferralSettings(address _referralDestination, uint256 _referralFee) external;

  /// @notice Updates the fee settings
  /// @param _feeDestination The address to receive fees
  /// @param _fee The new fee amount
  /// @param _feeDiscountAmount The amount of fee discount
  function setFeeSettings(address _feeDestination, uint256 _fee, uint256 _feeDiscountAmount) external;

  /// @notice Creates a new token launch
  /// @param p The parameters for the token launch
  /// @param expected The expected address where token will be deployed
  /// @return token The address of the newly created token
  /// @return received The amount of tokens received if the user chooses to buy at launch
  /// @return swapped The amount of tokens swapped if the user chooses to swap at launch
  function createAndBuy(CreateParams memory p, address expected, uint256 amount)
    external
    payable
    returns (address token, uint256 received, uint256 swapped);

  /// @notice Gets the total number of tokens launched
  /// @return totalTokens The total count of launched tokens
  function getTotalTokens() external view returns (uint256 totalTokens);

  /// @notice Claims accumulated fees for a specific token
  /// @param _token The token to claim fees for
  function claimFees(IERC20 _token) external;
}

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

import {ITokenTemplate} from "./ITokenTemplate.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ITokenLaunchpad Interface
/// @notice Interface for the TokenLaunchpad contract that handles token launches
interface ITokenLaunchpad {
  /// @notice Parameters required to create a new token launch
  /// @param name The name of the token
  /// @param symbol The symbol of the token
  /// @param metadata IPFS hash or other metadata about the token
  /// @param fundingToken The token used for funding the launch
  /// @param fee The fee tier for the liquidity pool (e.g. 3000 = 0.3%)
  /// @param limitPerWallet Maximum amount a single wallet can participate
  /// @param salt Random value to ensure unique deployment address
  /// @param launchTick The tick at which the token launches
  /// @param graduationTick The tick that must be reached for graduation
  /// @param upperMaxTick The maximum tick allowed
  struct CreateParams {
    string name;
    string symbol;
    string metadata;
    IERC20 fundingToken;
    uint256 limitPerWallet;
    bytes32 salt;
    int24 launchTick;
    int24 graduationTick;
    int24 upperMaxTick;
  }

  /// @notice Emitted when fee settings are updated
  /// @param feeDestination The address where fees will be sent
  /// @param fee The new fee amount
  event FeeUpdated(address indexed feeDestination, uint256 fee);

  /// @notice Emitted when a token is launched
  /// @param token The token that was launched
  /// @param pool The address of the pool for the token
  /// @param params The parameters used to launch the token
  event TokenLaunched(ITokenTemplate indexed token, address indexed pool, ITokenTemplate.InitParams params);

  /// @notice Emitted when referral settings are updated
  /// @param referralDestination The address where referrals will be sent
  /// @param referralFee The new referral fee amount
  event ReferralUpdated(address indexed referralDestination, uint256 referralFee);

  /// @notice Initializes the launchpad contract
  /// @param _adapter The DEX adapter contract address
  /// @param _tokenImplementation The implementation contract for new tokens
  /// @param _owner The owner address
  /// @param _weth The WETH9 contract address
  /// @param _odos The ODOS contract address
  function initialize(address _adapter, address _tokenImplementation, address _owner, address _weth, address _odos)
    external;

  /// @notice Updates the referral settings
  /// @param _referralDestination The address to receive referrals
  /// @param _referralFee The new referral fee amount
  function setReferralSettings(address _referralDestination, uint256 _referralFee) external;

  /// @notice Updates the fee settings
  /// @param _feeDestination The address to receive fees
  /// @param _fee The new fee amount
  function setFeeSettings(address _feeDestination, uint256 _fee) external;

  /// @notice Creates a new token launch
  /// @param p The parameters for the token launch
  /// @param expected The expected address where token will be deployed
  /// @return token The address of the newly created token
  function createAndBuy(CreateParams memory p, address expected, uint256 amount)
    external
    payable
    returns (address token);

  /// @notice Gets the total number of tokens launched
  /// @return totalTokens The total count of launched tokens
  function getTotalTokens() external view returns (uint256 totalTokens);

  /// @notice Claims accumulated fees for a specific token
  /// @param _token The token to claim fees for
  function claimFees(ITokenTemplate _token) external;

  /// @notice Buys a token with exact output using ODOS
  /// @param _odosTokenIn The ODOS token to receive
  /// @param _tokenIn The token to buy
  /// @param _tokenOut The token to receive
  /// @param _odosTokenInAmount The amount of ODOS tokens to receive
  /// @param _minOdosTokenOut The minimum amount of ODOS tokens to receive
  /// @param _minAmountOut The minimum amount of tokens to receive
  function buyWithExactOutputWithOdos(
    IERC20 _odosTokenIn,
    IERC20 _tokenIn,
    IERC20 _tokenOut,
    uint256 _odosTokenInAmount,
    uint256 _minOdosTokenOut,
    uint256 _minAmountOut,
    bytes memory _odosData
  ) external payable returns (uint256 amountOut);

  /// @notice Sells a token with exact output using ODOS
  /// @param _tokenIn The token to sell
  /// @param _odosTokenOut The ODOS token to receive
  /// @param _tokenOut The token to receive
  /// @param _tokenInAmount The amount of tokens to sell
  /// @param _minOdosTokenIn The minimum amount of ODOS tokens to receive
  /// @param _minAmountOut The minimum amount of tokens to receive
  function sellWithExactOutputWithOdos(
    IERC20 _tokenIn,
    IERC20 _odosTokenOut,
    IERC20 _tokenOut,
    uint256 _tokenInAmount,
    uint256 _minOdosTokenIn,
    uint256 _minAmountOut,
    bytes memory _odosData
  ) external payable returns (uint256 amountOut);
}

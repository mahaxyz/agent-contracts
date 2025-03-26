import { parseEther } from "ethers";
import hre from "hardhat";

async function main() {
  const weth = await hre.ethers.getContractAt(
    "IWETH9",
    "0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f"
  );

  const token = await hre.ethers.getContractAt(
    "IERC20",
    "0xcb1d3d3832138ef4bb6cccd0953adb811f21672d"
  );

  const swapRouter = await hre.ethers.getContractAt(
    "IRamsesSwapRouter",
    "0xAAAE99091Fbb28D400029052821653C1C752483B"
  );

  const [me] = await hre.ethers.getSigners();

  // estimate amount of tokens to buy
  const amountOfEthToSpend = parseEther("0.0001"); // 1 ETH
  const deadline = Math.floor(Date.now() / 1000) + 3600;
  const slippagePercent = 1; // 1% slippage
  const tokenIn = weth;
  const tokenOut = token;

  // step 1 check approvals
  if (tokenIn !== weth.target) {
    // if it is not WETH, we need to approve the swap router
    const allowance = await tokenIn.allowance(me.address, swapRouter.target);
    if (allowance < amountOfEthToSpend) {
      const tx = await tokenIn.approve(swapRouter.target, amountOfEthToSpend);
      await tx.wait();
    }
  }

  // step 2 estimate amount of tokens to buy to calculate the amount of tokens to
  // receieve to show in the UI and to calculate the slippage
  const amountOut = await swapRouter.exactInputSingle.staticCall(
    {
      tokenIn: weth.target,
      tokenOut: token.target,
      fee: 20000,
      recipient: me.address,
      deadline,
      amountIn: amountOfEthToSpend,
      amountOutMinimum: 0,
      sqrtPriceLimitX96: 0,
    },
    { value: amountOfEthToSpend } // add this for ETH
  );

  console.log("amount expected", amountOut); // show this value in the UI

  const amountWithSlippage =
    (amountOut * (100n - BigInt(slippagePercent))) / 10000n;

  console.log("amount with slippage", amountWithSlippage);

  // execute the swap with slippage
  const tx = await swapRouter.exactInputSingle(
    {
      tokenIn: weth.target,
      tokenOut: token.target,
      fee: 20000,
      recipient: me.address,
      deadline,
      amountIn: amountOfEthToSpend,
      amountOutMinimum: amountWithSlippage,
      sqrtPriceLimitX96: 0,
    },
    { value: amountOfEthToSpend } // add this for ETH
  );

  await tx.wait();

  console.log("tx hash", tx.hash);
}

main().catch(console.error);

import { HardhatRuntimeEnvironment } from "hardhat/types";
import dotenv from "dotenv"
import {mainWallet, makeContract, sendTx, setupHRE} from "../../utils/contract";
import hre from "hardhat";
import {utils} from "ethers";
import {BlogChallenge} from "../../typechain-types";

dotenv.config();

export async function participate(
  hre: HardhatRuntimeEnvironment,
  challengeAddress: string,
  shareBps: number = 5000 // 默认50%份额
) {
  setupHRE(hre);

  // 获取挑战合约
  const challenge = await hre.ethers.getContractAt(
    "BlogChallenge",
    challengeAddress
  ) as BlogChallenge;

  // 获取代币合约
  const tokenAddress = await challenge.penaltyToken();
  const token = await hre.ethers.getContractAt("BaseERC20", tokenAddress);

  // 计算参与成本
  const cost = await challenge.participateCost(shareBps);
  console.log("Participation cost:", utils.formatEther(cost), "tokens");

  // 授权代币
  const approveTx = await sendTx(token.approve(challengeAddress, cost));
  await approveTx.wait();
  console.log("Token approved");

  // 参与挑战
  const tx = await sendTx(challenge.participate(shareBps));
  const receipt = await tx.wait();
  
  console.log("Successfully participated in challenge");
  console.log("Transaction hash:", receipt.hash);
  
  // 获取当前持有的挑战代币数量
  const balance = await challenge.balanceOf(await mainWallet());
  console.log("Your challenge token balance:", utils.formatEther(balance));
}

// 如果直接运行这个脚本
if (require.main === module) {
  // 从命令行参数获取挑战地址和份额
  const challengeAddress = process.argv[2];
  const shareBps = parseInt(process.argv[3] || "5000");

  if (!challengeAddress) {
    console.error("Please provide challenge address as argument");
    process.exit(1);
  }

  participate(hre, challengeAddress, shareBps).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

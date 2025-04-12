import { HardhatRuntimeEnvironment } from "hardhat/types";
import dotenv from "dotenv"
import {mainWallet, makeContract, sendTx, setupHRE} from "../../utils/contract";
import hre from "hardhat";
import {BlogChallenge} from "../../typechain-types";

dotenv.config();

export async function submitBlog(
  hre: HardhatRuntimeEnvironment,
  challengeAddress: string,
  title: string,
  description: string,
  url: string
) {
  setupHRE(hre);

  // 获取挑战合约
  const challenge = await hre.ethers.getContractAt(
    "BlogChallenge",
    challengeAddress
  ) as BlogChallenge;

  // 检查是否是挑战者
  const challenger = await challenge.challenger();
  const wallet = await mainWallet();
  
  if (challenger.toString().toLowerCase() !== wallet.address.toString().toLowerCase()) {
    throw new Error("Only challenger can submit blogs");
  }

  // 获取当前周期
  const currentCycle = await challenge.currentCycle();
  console.log("Current cycle:", currentCycle.toString());

  // 提交博客
  const tx = await sendTx(challenge.submitBlog(title, description, url));
  const receipt = await tx.wait();

  console.log("Blog submitted successfully");
  console.log("Transaction hash:", receipt.hash);

  // 获取当前周期的完成状态
  const isCompleted = await challenge.isCycleSucceed(currentCycle);
  console.log("Current cycle completed:", isCompleted);
}

// 如果直接运行这个脚本
if (require.main === module) {
  // 从命令行参数获取参数
  const challengeAddress = process.argv[2];
  const title = process.argv[3];
  const description = process.argv[4];
  const url = process.argv[5];

  if (!challengeAddress || !title || !description || !url) {
    console.error("Please provide all required arguments: challengeAddress, title, description, url");
    process.exit(1);
  }

  submitBlog(hre, challengeAddress, title, description, url).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

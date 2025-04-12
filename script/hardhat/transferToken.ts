import { HardhatRuntimeEnvironment } from "hardhat/types";
import dotenv from "dotenv"
import {getContract, mainWallet, makeContract, sendTx, setupHRE} from "../../utils/contract";
import hre from "hardhat";
import {BlogChallenge} from "../../typechain-types";
import { parseEther } from "ethers/lib/utils";

dotenv.config();

export async function submitBlog(
  hre: HardhatRuntimeEnvironment,
  challengeAddress: string,
  toAddress: string,
  amountInEther: string
) {
  setupHRE(hre);

  // const toAddress = ""
  const amount = parseEther(amountInEther);

  // 获取挑战合约
  const challenge = await getContract(
    "BlogChallenge", "BlogChallenge", challengeAddress
  );

  // 检查是否是挑战者
  const challenger = await challenge.challenger();
  const wallet = await mainWallet();

  if (challenger.toString().toLowerCase() !== wallet.address.toString().toLowerCase()) {
    throw new Error("Only challenger can trnasfer tokens");
  }

  // 转移代币
  const tx = await sendTx(challenge.transferTokens(toAddress, amount));
  const receipt = await tx.wait();

  console.log("Token transferred successfully");
  console.log("Transaction hash:", receipt.hash);
}

// 如果直接运行这个脚本
if (require.main === module) {
  // 从命令行参数获取参数
  const challengeAddress = "0x3A4D30B9df90CB4Ac72537059Fc40e0219fA4c48";
  const toAddress = "0x3eCec3D31715f8Fa88D2359359ceaE07142C7487"
  const amountInEther = "100";

  if (!challengeAddress || !toAddress || !amountInEther) {
    console.error("Please provide all required arguments: challengeAddress, toAddress, amountInEther");
    process.exit(1);
  }

  submitBlog(hre, challengeAddress, toAddress, amountInEther).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

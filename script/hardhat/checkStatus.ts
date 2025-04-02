import { HardhatRuntimeEnvironment } from "hardhat/types";
import dotenv from "dotenv"
import {mainWallet, makeContract, setupHRE} from "../../utils/contract";
import hre from "hardhat";
import {utils} from "ethers";
import {BlogChallenge} from "../../typechain-types";

dotenv.config();

export async function checkStatus(
  hre: HardhatRuntimeEnvironment,
  challengeAddress: string
) {
  setupHRE(hre);

  // 获取挑战合约
  const challenge = await hre.ethers.getContractAt(
    "BlogChallenge",
    challengeAddress
  ) as BlogChallenge;

  // 获取基本信息
  const challenger = await challenge.challenger();
  const startTime = await challenge.startTime();
  const cycleDuration = await challenge.cycle();
  const cycleCnt = await challenge.numberOfCycles();
  const currentCycle = await challenge.currentCycle();
  const lastUpdatedCycle = await challenge.lastUpdatedCycle();
  const depositAmount = await challenge.depositAmount();
  const ended = !(await challenge.started());

  console.log("Challenge Status:");
  console.log("----------------");
  console.log("Challenger:", challenger);
  console.log("Start Time:", new Date(Number(startTime) * 1000).toLocaleString());
  console.log("Cycle Duration:", Number(cycleDuration) / 3600, "hours");
  console.log("Total Cycles:", cycleCnt.toString());
  console.log("Current Cycle:", currentCycle.toString());
  console.log("Last Updated Cycle:", lastUpdatedCycle.toString());
  console.log("Deposit Amount:", utils.formatEther(depositAmount), "tokens");
  console.log("Challenge Ended:", ended);

  // 获取参与者信息
  console.log("\nParticipants:");
  console.log("------------");
  let i = 0;
  while (true) {
    try {
      const participant = await challenge.participants(i);
      const balance = await challenge.balanceOf(participant);
      const totalSupply = await challenge.totalSupply();
      const share = Number(balance) * 100 / Number(totalSupply);
      console.log(participant + ":");
      console.log("  Balance:", utils.formatEther(balance), "tokens");
      console.log("  Share:", share.toFixed(2), "%");
      i++;
    } catch (e) {
      break;
    }
  }

  // 如果挑战已经结束，显示结果
  if (ended) {
    const success = await challenge.checkSuccess();
    console.log("\nChallenge Result:", success ? "SUCCESS" : "FAILED");
  } else {
    // 显示已完成的周期
    console.log("\nCompleted Cycles:");
    console.log("----------------");
    for (let i = 0; i <= Number(currentCycle); i++) {
      const completed = await challenge.isCycleSucceed(i);
      if (!completed) continue;
      let j = 0;
      while (true) {
        try {
          const blog = await challenge.blogSubmissions(i, j);
          console.log(`Cycle ${i}, Submission ${j}:`);
          console.log("  Title:", blog.title);
          console.log("  Description:", blog.description);
          console.log("  URL:", blog.url);
          j++;
        } catch (e) {
          break;
        }
      }
    }
  }
}

// 如果直接运行这个脚本
if (require.main === module) {
  // 从命令行参数获取挑战地址
  const challengeAddress = process.argv[2];

  if (!challengeAddress) {
    console.error("Please provide challenge address as argument");
    process.exit(1);
  }

  checkStatus(hre, challengeAddress).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

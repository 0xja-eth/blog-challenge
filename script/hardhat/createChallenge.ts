import { HardhatRuntimeEnvironment } from "hardhat/types";
import dotenv from "dotenv"
import {mainWallet, makeContract, sendTx, setupHRE} from "../../utils/contract";
import hre from "hardhat";
import {utils} from "ethers";

dotenv.config();

export async function createChallenge(hre: HardhatRuntimeEnvironment) {
  setupHRE(hre);

  // 获取工厂合约
  const [factory] = await makeContract("ChallengeFactory");
  const [token] = await makeContract("BaseERC20");

  // 设置挑战参数
  const startTime = Math.floor(Date.now() / 1000) + 3600; // 1小时后开始
  const cycleDuration = 24 * 3600; // 24小时一个周期
  const cycleCnt = 12; // 12个周期
  const penaltyAmount = utils.parseEther("30"); // 30个代币
  const maxParticipants = 3; // 最多3个参与者

  // 创建挑战
  const tx = await sendTx(factory.createChallenge(
    startTime,
    cycleDuration,
    cycleCnt,
    token.address,
    penaltyAmount,
    maxParticipants
  ));

  // 等待交易确认
  const receipt = await tx.wait();
  
  // 从事件中获取新创建的挑战地址
  const challengeCreatedEvent = receipt.events?.find(
    (e: any) => e.event === "ChallengeCreated"
  );

  if (challengeCreatedEvent) {
    const challengeAddress = challengeCreatedEvent.args.challenge;
    console.log("New challenge created at:", challengeAddress);
    return challengeAddress;
  }
}

// 如果直接运行这个脚本
if (require.main === module) {
  createChallenge(hre).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

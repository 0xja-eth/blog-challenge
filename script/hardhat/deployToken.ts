import { HardhatRuntimeEnvironment } from "hardhat/types";
import dotenv from "dotenv"
import {mainWallet, makeContract, sendTx, setupHRE} from "../../utils/contract";
import hre from "hardhat";
import {utils} from "ethers";

dotenv.config();

export async function deployToken(hre: HardhatRuntimeEnvironment) {
  setupHRE(hre);

  // 部署代币合约
  const [token] = await makeContract("TestToken");
  console.log("Test Token deployed to:", token.address);

  // 获取部署者的代币余额
  const deployer = mainWallet();
  const balance = await token.balanceOf(deployer.address);
  console.log("Deployer balance:", utils.formatEther(balance), "TEST");

  return token.address;
}

// 如果直接运行这个脚本
if (require.main === module) {
  deployToken(hre).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

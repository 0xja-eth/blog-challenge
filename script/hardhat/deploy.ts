import { HardhatRuntimeEnvironment } from "hardhat/types";
import dotenv from "dotenv"
import {mainWallet, makeContract, sendTx, setupHRE} from "../../utils/contract";
import hre from "hardhat";
import {ethers} from "ethers";

dotenv.config();

export async function deploy(hre: HardhatRuntimeEnvironment) {
  setupHRE(hre);

  const [factory] = await makeContract("ChallengeFactory");

  const admin = await factory.owner();

  console.log("Admin:", admin);
}

deploy(hre).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

import { HardhatRuntimeEnvironment } from "hardhat/types";
import dotenv from "dotenv"
import {mainWallet, makeContract, sendTx, setupHRE} from "../../utils/contract";
import hre from "hardhat";
import {ethers} from "ethers";

dotenv.config();

export async function deploy(hre: HardhatRuntimeEnvironment) {
  setupHRE(hre);

  const bytecode = "";

  const [factory] = await makeContract("ChallengeFactory");

  const admin = await factory.owner();
  console.log("Admin:", admin);

  const challengeCode = await factory.challengeCode()
  console.log("challengeCode:", challengeCode);

  if (bytecode && bytecode != challengeCode) {
    await sendTx(factory.updateChallengeImplementation(bytecode), "Update challengeCode")
  }
}

deploy(hre).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

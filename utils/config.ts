
import fs from "fs";
import path from "path";
import dotenv from "dotenv";

export function setup() {
  const appDirectory = fs.realpathSync(process.cwd());
  const resolveApp = (relativePath) => path.resolve(appDirectory, relativePath);
  const pathsDotenv = resolveApp(".env");

  const rootEnvChain = process.env.CHAIN

  dotenv.config({ path: `${pathsDotenv}` })

  const envChain = rootEnvChain || process.env.CHAIN
  const chainDotenv = resolveApp(`env/${envChain}.env`);

  dotenv.config({ path: `${chainDotenv}` })
}

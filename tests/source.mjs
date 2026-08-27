import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
export const source = ["Core.lua", "Settings.lua", "ResourceDing.toc"]
  .map((file) => fs.readFileSync(path.join(root, file), "utf8"))
  .join("\n");

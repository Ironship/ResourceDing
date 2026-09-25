import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
// One manifest per game, so both are read: a check that passes only because it
// never looked at the Classic manifest would miss the half that ships to
// Classic players.
export const source = [
  "Core.lua",
  "Dots.lua",
  "Settings.lua",
  "ResourceDing_Mainline.toc",
  "ResourceDing_Vanilla.toc",
]
  .map((file) => fs.readFileSync(path.join(root, file), "utf8"))
  .join("\n");

// Characterization tests: pin what SETTLE01 does today, byte for byte, so a
// modernized port (java-port/) can be proven equivalent. The golden files were
// produced by running the real program (scripts/regen-golden.sh); they are not
// hand-written expectations.
import { test, before } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const root = path.resolve(import.meta.dirname, "..");
const inputs = fs.readdirSync(path.join(root, "data/input")).filter((f) => f.endsWith(".dat")).sort();
const hasCobc = spawnSync("sh", ["-c", "command -v cobc"]).status === 0;
const outDir = fs.mkdtempSync(path.join(os.tmpdir(), "settle01-"));

before(() => {
  if (!hasCobc) return;
  const build = spawnSync("scripts/build.sh", { cwd: root, encoding: "utf8" });
  assert.equal(build.status, 0, `scripts/build.sh failed:\n${build.stdout}${build.stderr}`);
});

test("GnuCOBOL is installed (cobc on PATH)", () => {
  assert.ok(hasCobc, "cobc not found. Install GnuCOBOL: brew install gnucobol (macOS) or sudo apt-get install -y gnucobol (Ubuntu).");
});

test("every input has a golden output", () => {
  for (const input of inputs) {
    assert.ok(fs.existsSync(path.join(root, "data/golden", input.replace(/\.dat$/, ".out"))), `missing data/golden for ${input}`);
  }
});

for (const input of inputs) {
  const name = input.replace(/\.dat$/, "");
  test(`SETTLE01 on ${input} matches data/golden/${name}.out byte for byte`, { skip: !hasCobc && "cobc not installed" }, () => {
    const golden = fs.readFileSync(path.join(root, "data/golden", `${name}.out`));
    const actualPath = path.join(outDir, `${name}.out`);
    const run = spawnSync("scripts/run.sh", [path.join(root, "data/input", input), actualPath], { cwd: root, encoding: "utf8" });

    const expectedRc = Number(/RETURN CODE (\d+)/.exec(golden.toString("latin1"))?.[1]);
    assert.equal(run.status, expectedRc, `exit status (stderr: ${run.stderr})`);
    const actual = fs.readFileSync(actualPath);
    assert.ok(
      actual.equals(golden),
      `output differs from golden\n--- expected\n${golden.toString("latin1")}--- actual\n${actual.toString("latin1")}`,
    );
  });
}

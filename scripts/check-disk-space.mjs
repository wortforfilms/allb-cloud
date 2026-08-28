import { statfsSync } from "node:fs";

const minimumGiB = Number.parseFloat(process.argv[2] ?? "6");
if (!Number.isFinite(minimumGiB) || minimumGiB <= 0) {
  throw new Error("Minimum free space must be a positive GiB value");
}

const stats = statfsSync(process.cwd());
const availableBytes = Number(stats.bavail) * Number(stats.bsize);
const availableGiB = availableBytes / 1024 ** 3;

console.log(
  `Disk preflight: ${availableGiB.toFixed(2)} GiB available; ${minimumGiB.toFixed(2)} GiB required`,
);
if (availableGiB < minimumGiB) {
  console.error(
    "Insufficient disk capacity. Remove reproducible build output or select a runner with more space.",
  );
  process.exit(1);
}

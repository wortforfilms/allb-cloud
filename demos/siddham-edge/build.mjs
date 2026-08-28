import fs from "node:fs";
const html=fs.readFileSync("index.html","utf8");
const css=fs.readFileSync("styles.css","utf8");
const data=fs.readFileSync("data.js","utf8");
const app=fs.readFileSync("app.js","utf8");
const bundled=html
  .replace('<link rel="stylesheet" href="styles.css">',`<style>${css}</style>`)
  .replace('<script src="data.js"></script>',`<script>${data}</script>`)
  .replace('<script src="app.js"></script>',`<script>${app}</script>`);
fs.writeFileSync("siddham-edge-full.html",bundled);
console.log(`Built siddham-edge-full.html (${bundled.length} bytes)`);

const lenses = [
  { id:"silicon", number:"01", name:"Silicon", tagline:"Deterministic acceleration", status:"IMPLEMENTED RTL", tone:"present", owner:"hardware/ · c_src/", summary:"The Siddham NPU lens covers compute, DMA, MMIO, SPI, FPGA wrappers, simulation benches, and the native hardware abstraction layer.", capabilities:["INT8-oriented compute core","AXI-stream DMA and memory interfaces","iCE40 and ECP5 wrappers","Rust-to-C++ native HAL"], evidence:["Integrated RTL testbenches are present","Runtime capability fallback exists","Hardware paths have canonical ownership"], boundary:"Physical silicon, production timing, safety certification, and benchmark guarantees are not established." },
  { id:"runtime", number:"02", name:"Runtime", tagline:"Portable sovereign execution", status:"VERIFIED LOCAL", tone:"verified", owner:"src/ · data/ · pkg/", summary:"The MAATAA runtime lens combines Rust, WebAssembly, Brahmi tokenization, bounded Paninian evaluation, compiled Sutra lookup, and signed Z0-VESP envelopes.", capabilities:["Native Rust execution","WebAssembly browser and Edge target","Brahmi tokenization","Paninian rule evaluation"], evidence:["Typed runtime contract tests pass","TypeScript contracts compile","WASM consumer tests pass after rebuild"], boundary:"A passing local build does not prove production availability, remote acceptance, or workload-wide semantic correctness." },
  { id:"authority", number:"03", name:"Authority", tagline:"Decide, deny, execute, and prove", status:"LOCAL SLICE VERIFIED", tone:"verified", owner:"apps/siddham-authority-desktop/", summary:"The Authority lens owns local policy decisions, invokes supported MAATAA operations only after a permit, and records linked authorization and execution evidence in trusted Rust code.", capabilities:["Explicit default deny","Typed assurance and effects","Authority-gated MAATAA execution","Linked immutable execution evidence"], evidence:["Authorization and execution share a request identity","Tampered execution evidence is detected","Unimplemented protected actions fail closed"], boundary:"Real identity assurance, approval workflow, key protection, remote execution, and non-runtime protected handlers remain incomplete." },
  { id:"edge", number:"04", name:"Edge", tagline:"Explicit remote execution", status:"STAGING BUNDLE", tone:"present", owner:"services/ · sdk/ · python/", summary:"The Edge lens exposes the runtime through a Cloudflare Worker and supported TypeScript and Python clients while keeping the target URL explicit and fail-closed.", capabilities:["Worker API endpoints","TypeScript and Python clients","Explicit environment selection","Signed outbound protocol"], evidence:["Staging bundle dry-run passes","No production URL is assumed","Staging certification evidence is documented"], boundary:"Dry-run proves bundle construction. Transmission does not prove receipt, and staging does not prove production readiness." },
  { id:"verification", number:"05", name:"Verification", tagline:"Claims follow evidence", status:"CI ALIGNED", tone:"verified", owner:"tests/ · .github/ · docs/", summary:"The Verification lens connects software tests, RTL simulation, cross-platform desktop checks, build order, authority maps, and release truth boundaries.", capabilities:["Root runtime and SDK checks","RTL simulation gates","Desktop Linux/macOS/Windows matrix","WASM-before-consumer build order"], evidence:["Root and desktop CI share the actual layout","Generated outputs are excluded from authority","Maturity boundaries are documented"], boundary:"CI success is necessary evidence, not independent certification or production approval." }
];

const tabs = document.querySelector(".lens-tabs");
const detail = document.querySelector(".lens-detail");

function renderLens(id) {
  const lens = lenses.find(item => item.id === id) || lenses[0];
  tabs.querySelectorAll("button").forEach(button => {
    const selected = button.dataset.lens === lens.id;
    button.classList.toggle("active", selected);
    button.setAttribute("aria-selected", String(selected));
  });
  detail.innerHTML = `
    <div class="lens-index"><span>${lens.number}</span><small>${lens.tagline}</small></div>
    <div class="lens-copy"><div class="lens-meta"><span class="state ${lens.tone}">${lens.status}</span><code>${lens.owner}</code></div><h3>${lens.name} lens</h3><p>${lens.summary}</p><strong>Current boundary</strong><p class="boundary-copy">${lens.boundary}</p></div>
    <div class="lens-columns"><section><h4>Implemented capability</h4><ul>${lens.capabilities.map(item=>`<li>${item}</li>`).join("")}</ul></section><section><h4>Available evidence</h4><ul>${lens.evidence.map(item=>`<li>${item}</li>`).join("")}</ul></section></div>`;
  history.replaceState(null, "", `#${lens.id}`);
}

tabs.innerHTML = lenses.map(lens => `<button role="tab" aria-selected="false" data-lens="${lens.id}"><span>${lens.number}</span><b>${lens.name}</b><small>${lens.tagline}</small></button>`).join("");
tabs.addEventListener("click", event => { const button = event.target.closest("button[data-lens]"); if (button) renderLens(button.dataset.lens); });
renderLens(location.hash.slice(1));

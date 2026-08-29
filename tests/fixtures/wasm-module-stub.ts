// Worker route tests do not execute the runtime. The real WASM payload is
// rebuilt and checked before consumer tests in the canonical build sequence.
export default {} as WebAssembly.Module;

import { invoke } from "@tauri-apps/api/core";
import type { EvidenceEvent, GovernedOperationResult, OperationRequest, RuntimeCapability } from "./types";

const desktop = () => "__TAURI_INTERNALS__" in window;

export async function executeGoverned(request: OperationRequest): Promise<GovernedOperationResult> {
  if (!desktop()) throw new Error("Governed execution requires the Siddham desktop runtime.");
  return invoke<GovernedOperationResult>("execute_governed", { request });
}

export async function loadEvidence(): Promise<EvidenceEvent[]> {
  if (!desktop()) return [];
  return invoke<EvidenceEvent[]>("list_evidence");
}

export async function loadRuntimeCapabilities(): Promise<RuntimeCapability[]> {
  if (!desktop()) return [];
  return invoke<RuntimeCapability[]>("runtime_capabilities");
}

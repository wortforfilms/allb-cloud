import { invoke } from "@tauri-apps/api/core";
import type { EvidenceEvent, GovernedOperationResult, OperationRequest, RuntimeCapability } from "./types";

export interface IdentityContext {
  sessionId: string; principalId: string; principalName: string; deviceId: string;
  workspaceId: string; workspaceName: string; organizationId: string; role: string;
  assurance: string; expiresAt: string;
}
export interface ApprovalView { id:string; requestId:string; requestHash:string; workspaceId:string; action:string; resource:string; requestedBy:string; status:string; requiredQuorum:number; approvals:number; expiresAt:string; createdAt:string; }
export interface HandlerMetadata { id:string; action:string; available:boolean; approvalRequired:boolean; target:string; maxInputBytes:number; deadlineMillis:number; detail:string; }

const desktop = () => "__TAURI_INTERNALS__" in window;

export async function executeGoverned(sessionId: string, request: OperationRequest, approvalId?:string): Promise<GovernedOperationResult> {
  if (!desktop()) throw new Error("Governed execution requires the Siddham desktop runtime.");
  return invoke<GovernedOperationResult>("execute_governed", { sessionId, approvalId:approvalId||null, request });
}

export async function loadIdentityContext(): Promise<IdentityContext | null> {
  if (!desktop()) return null;
  return invoke<IdentityContext>("identity_context");
}
export async function loadApprovals():Promise<ApprovalView[]>{if(!desktop())return[];return invoke<ApprovalView[]>("list_approvals");}
export async function submitApprovalDecision(sessionId:string,approvalId:string,decision:"approve"|"reject",comment:string):Promise<ApprovalView>{if(!desktop())throw new Error("Approval decisions require the Siddham desktop runtime.");return invoke<ApprovalView>("submit_approval_decision",{sessionId,approvalId,decision,comment});}
export async function cancelApproval(approvalId:string):Promise<ApprovalView>{if(!desktop())throw new Error("Approval cancellation requires the Siddham desktop runtime.");return invoke<ApprovalView>("cancel_approval",{approvalId});}
export async function loadHandlerRegistry():Promise<HandlerMetadata[]>{if(!desktop())return[];return invoke<HandlerMetadata[]>("handler_registry");}
export async function cancelExecution(requestId:string):Promise<boolean>{if(!desktop())throw new Error("Cancellation requires the Siddham desktop runtime.");return invoke<boolean>("cancel_execution",{requestId});}

export async function loadEvidence(): Promise<EvidenceEvent[]> {
  if (!desktop()) return [];
  return invoke<EvidenceEvent[]>("list_evidence");
}

export async function loadRuntimeCapabilities(): Promise<RuntimeCapability[]> {
  if (!desktop()) return [];
  return invoke<RuntimeCapability[]>("runtime_capabilities");
}

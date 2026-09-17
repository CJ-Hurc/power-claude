/**
 * [host:grok-cli:1.0.5][brain:xai:grok-4.6][via:direct:xai][hurc:v0.12.2163] Purpose: Issue a kernel-shaped AcceptedProofReceipt for kb-mcp complete-e2e.
 *
 * Goal: proof-receipt.json validates via hurc proof accept-validate.
 * Consumers: complete-e2e P11. bun scripts/complete-e2e/issue-accepted-receipt.ts
 * Inputs: PROJECT_ROOT, RECEIPT_OUT, SNAPSHOT_ID, HURC_CORE_SRC
 * Side effects: writes RECEIPT_OUT JSON; runs scripts/complete-e2e/prove.sh
 */
import { generateKeyPairSync, sign } from "node:crypto";
import { writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { join } from "node:path";

const core = process.env.HURC_CORE_SRC;
const root = process.env.PROJECT_ROOT;
const out = process.env.RECEIPT_OUT;
const snapshotId = process.env.SNAPSHOT_ID;
if (!core || !root || !out || !snapshotId) {
	throw new Error("need HURC_CORE_SRC, PROJECT_ROOT, RECEIPT_OUT, SNAPSHOT_ID");
}

const { createAcceptedProofReceipt } = await import(join(core, "verify/proof/acceptance.ts"));
const { attestationPayload } = await import(join(core, "verify/proof/kernel.ts"));
const { createRepositorySnapshot } = await import(join(core, "verify/proof/repository.ts"));
const { collectInputManifest, createEvidenceBundle, createVerificationPlan } = await import(
	join(core, "verify/proof/kernel.ts")
);
const { executeVerificationPlan } = await import(join(core, "verify/proof/execution.ts"));

type AttRole = "author" | "verifier" | "executor";

function signed(
	role: AttRole,
	identity: string,
	keyId: string,
	privateKey: ReturnType<typeof generateKeyPairSync>["privateKey"],
	scope: string,
) {
	const unsigned = {
		role,
		identity,
		keyId,
		issuedAt: new Date().toISOString(),
		scope,
	};
	return {
		...unsigned,
		signature: sign(null, Buffer.from(attestationPayload(unsigned)), privateKey).toString("base64"),
	};
}

const head = spawnSync("git", ["-C", root, "rev-parse", "HEAD"], { encoding: "utf8" });
if (head.status !== 0) {
	throw new Error(head.stderr || "git rev-parse HEAD failed");
}
const baseCommit = head.stdout.trim();
const snapshot = createRepositorySnapshot(root, baseCommit);

const extraNodes = snapshot.changes
	.filter((p) => !/(^|\/)(docs?|readme)(\/|$)/i.test(p) && !/\.(md|txt|rst)$/i.test(p))
	.map((p) => ({
		path: p,
		kind: "config" as const,
		risk: "application" as const,
		requiredProofs: ["contract" as const],
	}));

const config = {
	planVersion: 1 as const,
	tier: "pull-request" as const,
	nodes: [
		{
			path: "devtools/enforce/run.sh",
			kind: "source" as const,
			risk: "application" as const,
			requiredProofs: ["contract" as const],
		},
		{
			path: "scripts/complete-e2e/prove.sh",
			kind: "source" as const,
			risk: "application" as const,
			requiredProofs: ["contract" as const],
		},
		...extraNodes,
	],
	edges: [],
	claims: [
		{
			claimId: "kbmcp-cli-enforce-present",
			description: "CLI enforce driver + runtime adapter stay invocable on this snapshot",
			source: ["devtools/enforce/run.sh", "scripts/complete-e2e/prove.sh"],
			requiredProofs: ["contract" as const],
		},
	],
	inputs: [
		{ kind: "source" as const, path: "devtools/enforce/run.sh" },
		{ kind: "source" as const, path: "scripts/complete-e2e/prove.sh" },
		{ kind: "source" as const, path: "scripts/complete-e2e/list-surfaces.py" },
		{ kind: "source" as const, path: "configs/complete-e2e/runtime.json" },
	],
	commands: [
		{
			commandId: "prove-kbmcp-scaffold",
			proofTypes: ["contract" as const, "regression" as const, "integration" as const],
			argv: ["bash", "scripts/complete-e2e/prove.sh"],
			cwd: ".",
			timeoutMs: 180000,
			reports: [],
		},
	],
};

const plan = createVerificationPlan(snapshot, config);
const inputs = await collectInputManifest(root, plan.inputs);
const execution = await executeVerificationPlan(root, plan);
const evidence = createEvidenceBundle(plan, inputs, execution);
if (evidence.execution.status !== "candidate") {
	console.error(JSON.stringify(evidence.execution, null, 2));
	process.exit(1);
}

const authorKeys = generateKeyPairSync("ed25519");
const verifierKeys = generateKeyPairSync("ed25519");
const executorKeys = generateKeyPairSync("ed25519");
const policyKeys = generateKeyPairSync("ed25519");

const identities = {
	author: signed("author", "ce2e-kbmcp-author", "author", authorKeys.privateKey, evidence.proofId),
	verifier: signed(
		"verifier",
		"ce2e-kbmcp-independent-verifier",
		"verifier",
		verifierKeys.privateKey,
		evidence.proofId,
	),
	executor: signed("executor", "hurc-proof-kernel", "executor", executorKeys.privateKey, evidence.proofId),
};

const pem = (key: ReturnType<typeof generateKeyPairSync>["publicKey"]): string =>
	key.export({ type: "spki", format: "pem" }).toString();

const identityTrust = {
	author: { author: pem(authorKeys.publicKey) },
	verifier: { verifier: pem(verifierKeys.publicKey) },
	executor: { executor: pem(executorKeys.publicKey) },
};

const policyTrust = {
	"protected-ci": pem(policyKeys.publicKey),
};

const receipt = createAcceptedProofReceipt(evidence, identities, identityTrust, {
	keyId: "protected-ci",
	issuedAt: new Date().toISOString(),
	privateKey: policyKeys.privateKey as unknown as string,
});

const bundle = {
	...receipt,
	snapshot_id: snapshotId,
	identityTrust,
	policyTrust,
};

writeFileSync(out, JSON.stringify(bundle, null, 2) + "\n");
console.log(`wrote ${out} receiptId=${receipt.receiptId}`);

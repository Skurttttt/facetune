/**
 * PDMK-6 — the plan-driven orchestrator against the LOCAL Supabase stack.
 *
 * Runs the real Supabase ports — PostgREST queries, the lease filter, service
 * role grants, the attempt and lineage triggers, the finalize function, the
 * usage engine, and Storage — with only the two AI calls replaced. Never
 * points at a remote project: it refuses any URL that is not loopback.
 *
 *   LOCAL_SUPABASE_URL=http://127.0.0.1:54321 \
 *   LOCAL_SUPABASE_ANON_KEY=... LOCAL_SUPABASE_SERVICE_ROLE_KEY=... \
 *   deno test --allow-env --allow-net --allow-read \
 *     supabase/tests/controlled/pdmk6_orchestrator_local_test.ts
 */
import { assert, assertEquals } from "jsr:@std/assert@1";
import { createClient } from "npm:@supabase/supabase-js@2";

import type { CanonicalPlan } from "../../functions/_shared/kit_makeup_plan.ts";
import {
  LEASE_MS,
  type PlanPreviewPorts,
  runPlanPreview,
} from "../../functions/generate-kit-makeup-preview/plan_preview.ts";
import { supabasePlanPreviewPorts } from "../../functions/generate-kit-makeup-preview/plan_preview_supabase.ts";
import type { ValidationResult } from "../../functions/generate-kit-makeup-preview/validator.ts";

const url = Deno.env.get("LOCAL_SUPABASE_URL") ?? "";
const anonKey = Deno.env.get("LOCAL_SUPABASE_ANON_KEY") ?? "";
const serviceKey = Deno.env.get("LOCAL_SUPABASE_SERVICE_ROLE_KEY") ?? "";
const configured = /^http:\/\/(127\.0\.0\.1|localhost):\d+$/.test(url) &&
  anonKey.length > 0 && serviceKey.length > 0;

// A 1x1 PNG, so Storage receives a real image.
const PNG = Uint8Array.from(
  atob(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
  ),
  (c) => c.charCodeAt(0),
);

function verdict(outcome: "accepted" | "retryable_mismatch"): ValidationResult {
  return {
    outcome,
    validator_version: "kit_preview_validator_v1",
    planned_present_categories: ["lips"],
    unexpected_present_categories: outcome === "accepted" ? [] : ["foundation"],
    missing_required_categories: [],
    uncertain_categories: [],
    mismatch_reasons: outcome === "accepted"
      ? []
      : [{ code: "unplanned_makeup_present", category: "foundation" }],
    failure_code: null,
    evidence: { identity: "preserved", categories: {} },
  };
}

Deno.test({
  name: "PDMK-6 orchestrator on the local stack",
  ignore: !configured,
  sanitizeOps: false,
  sanitizeResources: false,
  async fn(t) {
    const service = createClient(url, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const email = `pdmk6-${crypto.randomUUID()}@example.invalid`;
    const password = crypto.randomUUID();
    const created = await service.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });
    assert(created.data.user, created.error?.message);
    const userId = created.data.user.id;
    const uploaded: string[] = [];
    try {
      const anon = createClient(url, anonKey, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      const session = await anon.auth.signInWithPassword({ email, password });
      assert(session.data.session, session.error?.message);
      const user = createClient(url, anonKey, {
        global: {
          headers: {
            Authorization: `Bearer ${session.data.session.access_token}`,
          },
        },
        auth: { persistSession: false, autoRefreshToken: false },
      });

      const activation = await service.rpc(
        "activate_verified_google_play_subscription",
        {
          p_user_id: userId,
          p_provider_product_id: "facetune_plus",
          p_purchase_reference: [...crypto.getRandomValues(new Uint8Array(32))]
            .map((b) => b.toString(16).padStart(2, "0")).join(""),
          p_subscription_state: "SUBSCRIPTION_STATE_ACTIVE",
          p_subscription_start: new Date(Date.now() - 86_400_000)
            .toISOString(),
          p_period_end: new Date(Date.now() + 29 * 86_400_000).toISOString(),
          p_auto_renew: true,
          p_linked_purchase_reference: null,
          p_test_purchase: true,
        },
      );
      assertEquals(activation.error, null);

      const analysisId = crypto.randomUUID();
      const analysis = await user.from("analyses").insert({
        id: analysisId,
        user_id: userId,
        original_image_path:
          `${userId}/analyses/${analysisId}/original/selfie.jpg`,
      }).select("id").single();
      assertEquals(analysis.error, null);

      const recommendationId = crypto.randomUUID();
      const planId = crypto.randomUUID();
      const planDigest = "a".repeat(64);
      const plan = {
        plan_id: planId,
        plan_version: "kit_makeup_plan_v1",
        analysis_id: analysisId,
        style_code: "soft_glam",
        source_mode: "my_makeup_kit",
      } as unknown as CanonicalPlan;
      const recommendation = await service.from("kit_makeup_recommendations")
        .insert({
          id: recommendationId,
          user_id: userId,
          analysis_id: analysisId,
          makeup_style: "soft_glam",
          recommendation_json: { selections: [] },
          product_snapshot_json: [],
          model_name: "model",
          prompt_version: "kit_makeup_recommendation_v3",
          plan_id: planId,
          plan_version: "kit_makeup_plan_v1",
          plan_json: plan,
          plan_digest: planDigest,
          plan_request_id: crypto.randomUUID(),
        }).select("id").single();
      assertEquals(recommendation.error, null);

      function ports(verdicts: ValidationResult[]): PlanPreviewPorts {
        const real = supabasePlanPreviewPorts({
          userClient: user,
          serviceClient: service,
          userId,
          kitRecommendationId: recommendationId,
          plan,
          planDigest,
          snapshot: [],
          apiKey: () => "unused",
          usageSink: {},
        });
        let n = 0;
        return {
          ...real,
          generate: () => {
            n++;
            // Distinct bytes per attempt; the first bytes stay a valid PNG.
            const bytes = new Uint8Array([...PNG, n]);
            return Promise.resolve({ bytes, mimeType: "image/png" });
          },
          validate: () => Promise.resolve(verdicts.shift()!),
          // No AI call of any kind leaves this test.
          assessReadiness: () =>
            Promise.resolve(
              {
                status: "ready",
                readiness_version: "kit_tutorial_readiness_v1",
                manifest_prompt_version: "tutorial_manifest_v4_1",
                manifest_schema_version: "tutorial_manifest_schema_v1",
                included_categories: ["lips"],
                unbacked_present_categories: [],
                missing_required_categories: [],
                failure_code: null,
              } as const,
            ),
          upload: async (path, bytes, mime) => {
            uploaded.push(path);
            await real.upload(path, bytes, mime);
          },
        };
      }
      const run = (operationId: string, verdicts: ValidationResult[]) =>
        runPlanPreview({
          operationId,
          kitRecommendationId: recommendationId,
          plan,
          prepare: () =>
            Promise.resolve({
              bytes: new Uint8Array([1]),
              mimeType: "image/jpeg",
            }),
        }, ports(verdicts));

      await t.step(
        "mismatch, then accepted: one charge, one preview",
        async () => {
          const op = crypto.randomUUID();
          const reply = await run(op, [
            verdict("retryable_mismatch"),
            verdict("accepted"),
          ]);
          assertEquals(reply.kind, "accepted");

          const generation = await service.from("kit_preview_generations")
            .select("id,status,terminal_outcome").eq("operation_id", op)
            .single();
          assertEquals(generation.data?.status, "accepted");
          const attempts = await service.from("kit_preview_attempts")
            .select("attempt_number,outcome,repair_codes,mismatch_categories")
            .eq("generation_id", generation.data!.id).order("attempt_number");
          assertEquals(attempts.data, [
            {
              attempt_number: 1,
              outcome: "retryable_mismatch",
              repair_codes: [],
              mismatch_categories: ["foundation"],
            },
            {
              attempt_number: 2,
              outcome: "accepted",
              repair_codes: ["forbid_foundation"],
              mismatch_categories: [],
            },
          ]);
          const preview = await user.from("kit_generated_images")
            .select(
              "id,plan_id,operation_id,prompt_version,content_sha256,storage_path",
            )
            .eq("kit_recommendation_id", recommendationId);
          assertEquals(preview.data?.length, 1);
          assertEquals(preview.data![0].plan_id, planId);
          assertEquals(
            preview.data![0].prompt_version,
            "kit_makeup_preview_v2",
          );
          assert(preview.data![0].storage_path.endsWith("/preview_0001.png"));
          const ledger = await user.from("usage_ledger")
            .select("status,canonical_kit_generated_image_id")
            .eq("operation_id", op).single();
          assertEquals(ledger.data, {
            status: "committed",
            canonical_kit_generated_image_id: preview.data![0].id,
          });

          const replay = await run(op, []);
          assertEquals(replay.kind, "accepted");
          if (replay.kind === "accepted") assertEquals(replay.replayed, true);
          const after = await service.from("kit_preview_attempts")
            .select("id").eq("generation_id", generation.data!.id);
          assertEquals(after.data?.length, 2, "a replay adds no attempt");
        },
      );

      await t.step(
        "every attempt fails: released, nothing persisted",
        async () => {
          const op = crypto.randomUUID();
          const reply = await run(op, [
            verdict("retryable_mismatch"),
            verdict("retryable_mismatch"),
            verdict("retryable_mismatch"),
          ]);
          assertEquals(reply.kind, "failed");
          const generation = await service.from("kit_preview_generations")
            .select("status,terminal_outcome").eq("operation_id", op).single();
          assertEquals(generation.data, {
            status: "failed",
            terminal_outcome: "retry_exhausted",
          });
          const ledger = await user.from("usage_ledger").select("status")
            .eq("operation_id", op).single();
          assertEquals(ledger.data?.status, "released");
          const previews = await user.from("kit_generated_images").select("id")
            .eq("operation_id", op);
          assertEquals(previews.data?.length, 0);
        },
      );

      await t.step("the lease is taken only when free or expired", async () => {
        const op = crypto.randomUUID();
        const reserved = await user.rpc("reserve_ai_look", {
          p_operation_id: op,
        });
        assertEquals(reserved.data?.ok, true);
        const real = ports([]);
        const now = Date.now();
        const generation = await real.insertGeneration({
          operationId: op,
          maxAttempts: 3,
          leaseExpiresAt: new Date(now + LEASE_MS).toISOString(),
        });
        assert(generation);
        assertEquals(
          await real.insertGeneration({
            operationId: op,
            maxAttempts: 3,
            leaseExpiresAt: new Date(now + LEASE_MS).toISOString(),
          }),
          null,
          "a second insert for one operation loses",
        );

        const busy = await run(op, []);
        assertEquals(busy.kind, "in_progress");

        const at = new Date(now).toISOString();
        assertEquals(
          await real.takeLease(
            generation.id,
            new Date(now + 1).toISOString(),
            at,
          ),
          false,
          "a live lease is not taken",
        );
        const later = new Date(now + LEASE_MS + 1_000).toISOString();
        assertEquals(
          await real.takeLease(generation.id, later, later),
          true,
          "an expired lease is taken",
        );
        await real.yieldLease(generation.id);
        assertEquals(
          await real.takeLease(generation.id, later, at),
          true,
          "a yielded lease is free",
        );
      });
    } finally {
      if (uploaded.length > 0) {
        await service.storage.from("face-images").remove(uploaded);
      }
      await service.auth.admin.deleteUser(userId);
    }
  },
});

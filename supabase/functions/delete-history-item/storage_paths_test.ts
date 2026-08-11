import {
  assertEquals,
  assertThrows,
} from "jsr:@std/assert@1";

import {
  assertOwnedHistoryPaths,
  historyPrefix,
  isOwnedHistoryPath,
} from "./storage_paths.ts";

Deno.test("history paths stay inside the exact owner and analysis prefix", () => {
  const prefix = historyPrefix("user-1", "analysis-1");
  assertEquals(prefix, "user-1/analyses/analysis-1");
  assertEquals(
    isOwnedHistoryPath(
      "user-1/analyses/analysis-1/original/photo.jpg",
      prefix,
    ),
    true,
  );
  assertEquals(
    isOwnedHistoryPath(
      "user-1/analyses/analysis-10/original/photo.jpg",
      prefix,
    ),
    false,
  );
});

Deno.test("history deletion rejects a path outside the session", () => {
  assertThrows(
    () =>
      assertOwnedHistoryPaths(
        ["user-1/analyses/other/generated/preview.jpg"],
        historyPrefix("user-1", "analysis-1"),
      ),
    Error,
    "unsafe_history_path",
  );
});

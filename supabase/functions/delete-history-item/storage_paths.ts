export function historyPrefix(userId: string, analysisId: string): string {
  return `${userId}/analyses/${analysisId}`;
}

export function isOwnedHistoryPath(path: string, prefix: string): boolean {
  if (!path.startsWith(`${prefix}/`) || path.includes("//")) return false;
  // A prefix match alone still accepts traversal segments that resolve outside
  // the session folder, so reject them explicitly.
  return !path.split("/").some((segment) => segment === "." || segment === "..");
}

export function assertOwnedHistoryPaths(
  paths: string[],
  prefix: string,
): void {
  if (paths.some((path) => !isOwnedHistoryPath(path, prefix))) {
    throw new Error("unsafe_history_path");
  }
}

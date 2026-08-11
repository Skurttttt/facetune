export function historyPrefix(userId: string, analysisId: string): string {
  return `${userId}/analyses/${analysisId}`;
}

export function isOwnedHistoryPath(path: string, prefix: string): boolean {
  return path.startsWith(`${prefix}/`) && !path.includes("//");
}

export function assertOwnedHistoryPaths(
  paths: string[],
  prefix: string,
): void {
  if (paths.some((path) => !isOwnedHistoryPath(path, prefix))) {
    throw new Error("unsafe_history_path");
  }
}

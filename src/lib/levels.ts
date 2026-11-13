/**
 * Level curve: level n starts at 100·(n−1)² XP.
 * L1 = 0, L2 = 100, L3 = 400, L4 = 900, L5 = 1600 …
 */
export const xpForLevel = (level: number) => 100 * (level - 1) ** 2;

export const levelForXp = (xp: number) => Math.floor(Math.sqrt(Math.max(0, xp) / 100)) + 1;

export function levelProgress(xp: number) {
  const level = levelForXp(xp);
  const start = xpForLevel(level);
  const next = xpForLevel(level + 1);
  return { level, xp, levelStartXp: start, nextLevelXp: next, progress: (xp - start) / (next - start) };
}

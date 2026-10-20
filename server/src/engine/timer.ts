export type PhaseWindow = Readonly<{
  phase: string;
  startTime: number;
  endTime: number;
}>;

export function phaseWindow(
  phase: string,
  now: number,
  durationMs: number,
): PhaseWindow {
  if (
    !phase ||
    !Number.isSafeInteger(now) ||
    now < 0 ||
    !Number.isSafeInteger(durationMs) ||
    durationMs < 1 ||
    !Number.isSafeInteger(now + durationMs)
  )
    throw new Error("Invalid phase window");
  return { phase, startTime: now, endTime: now + durationMs };
}

export function assertBeforeDeadline(window: PhaseWindow, serverNow: number) {
  if (
    !Number.isSafeInteger(serverNow) ||
    serverNow < window.startTime ||
    serverNow >= window.endTime
  ) {
    throw new Error("Action outside phase window");
  }
}

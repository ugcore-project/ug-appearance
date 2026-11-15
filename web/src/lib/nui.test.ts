/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { browserLog, flushLive, sendChange, sendRotate, sendSave, sendZoom, SEND_INTERVAL_MS } from "@/lib/nui";
import { NuiCallback, type Appearance } from "@/types/protocol";

const look = (model: string) => ({ model }) as Appearance;

beforeEach(() => {
  vi.useFakeTimers();
  flushLive();
  browserLog.length = 0;
});

afterEach(() => {
  flushLive();
  vi.useRealTimers();
});

describe("live queue", () => {
  it("sends at most one message per interval", () => {
    sendChange(look("a"));
    sendRotate(10);
    sendZoom(1);
    expect(browserLog).toHaveLength(1);

    vi.advanceTimersByTime(SEND_INTERVAL_MS);
    expect(browserLog).toHaveLength(2);

    vi.advanceTimersByTime(SEND_INTERVAL_MS);
    expect(browserLog.map((entry) => entry.callback).sort()).toEqual([NuiCallback.Change, NuiCallback.Rotate, NuiCallback.Zoom].sort());
  });

  it("keeps only the newest edit and adds up deltas", () => {
    sendChange(look("a"));
    sendChange(look("b"));
    sendChange(look("c"));
    sendRotate(10);
    sendRotate(15);
    vi.advanceTimersByTime(SEND_INTERVAL_MS * 4);

    // Kinds take turns, so the order between kinds depends on the previous send.
    expect(browserLog.filter((entry) => entry.callback === NuiCallback.Change).map((entry) => entry.data)).toEqual([
      { appearance: look("a") },
      { appearance: look("c") },
    ]);
    expect(browserLog.filter((entry) => entry.callback === NuiCallback.Rotate).map((entry) => entry.data)).toEqual([{ delta: 25 }]);
  });

  it("clamps deltas", () => {
    sendRotate(1000);
    sendZoom(-100);
    flushLive();

    expect(browserLog).toEqual(
      expect.arrayContaining([
        { callback: NuiCallback.Rotate, data: { delta: 180 } },
        { callback: NuiCallback.Zoom, data: { delta: -5 } },
      ]),
    );
    expect(browserLog).toHaveLength(2);
  });

  it("flushes pending edits before saving", async () => {
    sendChange(look("a"));
    sendChange(look("b"));
    await sendSave();

    expect(browserLog.map((entry) => entry.callback)).toEqual([NuiCallback.Change, NuiCallback.Change, NuiCallback.Save]);
    expect(browserLog[2]?.data).toEqual({});
  });
});

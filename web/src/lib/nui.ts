/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// The only file that calls `fetch`. NUI callbacks are POSTs to `https://<resource>/<callback>`.
// Live intents (edits, turning, zoom) go through one queue: at most one post every SEND_INTERVAL_MS, the newest value
// of each kind, so the page stays inside Lua's budget of 30 callbacks per second whatever the pointer does.

import { NuiCallback, type Appearance, type Camera, type Light } from "@/types/protocol";

declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}

export const SEND_INTERVAL_MS = 50;

/** True in a normal browser (`npm run dev`), where no NUI callback endpoint exists. */
export function isEnvBrowser(): boolean {
  return typeof window.GetParentResourceName !== "function";
}

function resourceName(): string {
  return window.GetParentResourceName?.() ?? "ug-appearance";
}

/** Sent requests in a browser, for the dev preview and tests. */
export const browserLog: { callback: string; data: unknown }[] = [];

export async function postNui(callback: NuiCallback, data: unknown): Promise<boolean> {
  if (isEnvBrowser()) {
    browserLog.push({ callback, data });

    return true;
  }

  try {
    const response = await fetch(`https://${resourceName()}/${callback}`, {
      method: "POST",
      headers: { "Content-Type": "application/json; charset=UTF-8" },
      body: JSON.stringify(data),
    });
    const reply = (await response.json()) as { ok?: unknown };

    return reply.ok === true;
  } catch {
    return false;
  }
}

type Live = "change" | "rotate" | "zoom";

const pending: { change?: Appearance; rotate?: number; zoom?: number } = {};
const order: Live[] = ["change", "rotate", "zoom"];
let next = 0;
let timer: ReturnType<typeof setInterval> | null = null;

const clamp = (value: number, limit: number) => Math.max(-limit, Math.min(limit, value));

function flushOne(): void {
  for (let step = 0; step < order.length; step++) {
    const kind = order[(next + step) % order.length] as Live;

    if (pending[kind] === undefined) {
      continue;
    }

    next = (next + step + 1) % order.length;

    if (kind === "change" && pending.change) {
      void postNui(NuiCallback.Change, { appearance: pending.change });
      delete pending.change;
    } else if (kind === "rotate" && pending.rotate !== undefined) {
      void postNui(NuiCallback.Rotate, { delta: clamp(pending.rotate, 180) });
      delete pending.rotate;
    } else if (pending.zoom !== undefined) {
      void postNui(NuiCallback.Zoom, { delta: clamp(pending.zoom, 5) });
      delete pending.zoom;
    }

    return;
  }

  if (timer !== null) {
    clearInterval(timer);
    timer = null;
  }
}

function schedule(): void {
  if (timer === null) {
    flushOne();
    timer = setInterval(flushOne, SEND_INTERVAL_MS);
  }
}

/** The edited appearance. Only the newest one is sent. */
export function sendChange(appearance: Appearance): void {
  pending.change = appearance;
  schedule();
}

/** Turns the ped by degrees. Deltas add up between sends. */
export function sendRotate(delta: number): void {
  pending.rotate = (pending.rotate ?? 0) + delta;
  schedule();
}

/** Moves the camera by meters, negative is closer. Deltas add up between sends. */
export function sendZoom(delta: number): void {
  pending.zoom = (pending.zoom ?? 0) + delta;
  schedule();
}

/** Sends whatever waits, at once. Saving and closing use it. */
export function flushLive(): void {
  while (pending.change !== undefined || pending.rotate !== undefined || pending.zoom !== undefined) {
    flushOne();
  }

  if (timer !== null) {
    clearInterval(timer);
    timer = null;
  }
}

export const sendReady = () => postNui(NuiCallback.Ready, {});
export const sendCamera = (preset: Camera) => postNui(NuiCallback.Camera, { preset });
export const sendPose = (id: string) => postNui(NuiCallback.Pose, { id });
export const sendLight = (light: Light) => postNui(NuiCallback.Light, { light });
export const sendCompare = (active: boolean) => postNui(NuiCallback.Compare, { active });
export const sendOutfitSave = (name: string) => postNui(NuiCallback.OutfitSave, { name });
export const sendOutfitWear = (id: number) => postNui(NuiCallback.OutfitWear, { id });
export const sendOutfitDelete = (id: number) => postNui(NuiCallback.OutfitDelete, { id });
export const sendOutfitReplace = (id: number) => postNui(NuiCallback.OutfitReplace, { id });
export const sendOutfitRename = (id: number, name: string) => postNui(NuiCallback.OutfitRename, { id, name });
export const sendUniformWear = (index: number) => postNui(NuiCallback.UniformWear, { index });

/** Saves, or pays and saves. Lua sends the edit itself, never a total from the page. */
export function sendSave(): Promise<boolean> {
  flushLive();

  return postNui(NuiCallback.Save, {});
}

export function sendCancel(): Promise<boolean> {
  flushLive();

  return postNui(NuiCallback.Cancel, {});
}

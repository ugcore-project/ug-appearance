/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { create } from "zustand";
import { applyTheme } from "@/lib/theme";
import { cameraFor } from "@/lib/appearance";
import { sendCamera, sendChange } from "@/lib/nui";
import {
  Camera,
  Feature,
  Light,
  NuiAction,
  Place,
  Side,
  type Controls,
  type Features,
  type PanelLayout,
  type PageSettings,
  type ActionResult,
  type Appearance,
  type Bill,
  type Catalog,
  type Category,
  type NuiMessage,
  type OpenPayload,
  type Outfit,
  type PageConfig,
} from "@/types/protocol";

export const HISTORY_LIMIT = 50;

interface EditorState {
  config: PageSettings;
  session: OpenPayload | null;
  catalog: Catalog | null;
  saved: Appearance | null;
  /** The edit the player sees, sent to Lua on every change. */
  appearance: Appearance | null;
  past: Appearance[];
  future: Appearance[];
  bill: Bill;
  category: Category | null;
  /** The slot inside the category: a component, a prop or an overlay. */
  slot: string | null;
  camera: Camera;
  light: Light;
  outfits: Outfit[];
  result: ActionResult | null;
  busy: boolean;
  /** The outfits tab is open instead of a category. */
  showOutfits: boolean;
}

/** English labels until Lua sends the configured language. Lua sends every key of locales/<code>.json `page`. */
export const DEFAULT_LABELS: Record<string, string> = {
  title: "Appearance",
  save: "Save",
  pay: "Pay",
  cancel: "Cancel",
  total: "Total",
  free: "Free",
  changes: "Changes",
  noChanges: "No changes yet",
  undo: "Undo",
  redo: "Redo",
  randomize: "Randomize",
  compare: "Hold to compare",
  search: "Search",
  favorites: "Favorites",
  none: "None",
  drawable: "Style",
  texture: "Variant",
  color: "Color",
  highlight: "Highlight",
  opacity: "Opacity",
  hint: "Drag to turn · Scroll to zoom · Q/E to rotate",
  leaveTitle: "Leave without saving?",
  leaveHint: "Your changes will be lost.",
  leave: "Leave",
  stay: "Keep editing",
};

const EMPTY_BILL: Bill = { total: 0, lines: [] };

export const DEFAULT_LAYOUT: PanelLayout = {
  side: Side.Left,
  width: 22,
  opacity: 0.7,
  blur: true,
  toolbar: Place.Top,
  hint: true,
  animations: true,
  resultDuration: 3500,
};

export const DEFAULT_CONTROLS: Controls = { dragSpeed: 0.4, zoomSpeed: 0.002, keyRotate: 15, rotateStep: 45 };

const record = (value: unknown): Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value) ? (value as Record<string, unknown>) : {};

const numberIn = (value: unknown, min: number, max: number, fallback: number) =>
  typeof value === "number" && Number.isFinite(value) ? Math.min(Math.max(value, min), max) : fallback;

const booleanOr = (value: unknown, fallback: boolean) => (typeof value === "boolean" ? value : fallback);

function oneOf<T extends string>(value: unknown, list: readonly T[], fallback: T): T {
  return list.includes(value as T) ? (value as T) : fallback;
}

/** The owner layout, field by field. Lua checked it; anything off falls back to the default. */
export function readLayout(value: unknown): PanelLayout {
  const raw = record(value);
  const base = DEFAULT_LAYOUT;

  return {
    side: oneOf(raw.side, Object.values(Side), base.side),
    width: numberIn(raw.width, 16, 40, base.width),
    opacity: numberIn(raw.opacity, 0, 1, base.opacity),
    blur: booleanOr(raw.blur, base.blur),
    toolbar: oneOf(raw.toolbar, Object.values(Place), base.toolbar),
    hint: booleanOr(raw.hint, base.hint),
    animations: booleanOr(raw.animations, base.animations),
    resultDuration: numberIn(raw.resultDuration, 500, 60000, base.resultDuration),
  };
}

/** Every tool is on unless the owner set it to false. */
export function readFeatures(value: unknown): Features {
  const raw = record(value);

  return Object.fromEntries(Object.values(Feature).map((feature) => [feature, raw[feature] !== false])) as Features;
}

export function readControls(value: unknown): Controls {
  const raw = record(value);
  const base = DEFAULT_CONTROLS;

  return {
    dragSpeed: numberIn(raw.dragSpeed, 0.01, 5, base.dragSpeed),
    zoomSpeed: numberIn(raw.zoomSpeed, 0.0001, 0.1, base.zoomSpeed),
    keyRotate: numberIn(raw.keyRotate, 0, 180, base.keyRotate),
    rotateStep: numberIn(raw.rotateStep, 1, 180, base.rotateStep),
  };
}

/** The light presets in the owner's order, without unknown or repeated ones. None left means all. */
export function readLights(value: unknown): Light[] {
  const known: readonly string[] = Object.values(Light);
  const list = Array.isArray(value) ? value.filter((entry): entry is Light => known.includes(entry as string)) : [];
  const unique = [...new Set(list)];

  return unique.length > 0 ? unique : Object.values(Light);
}

const DEFAULT_SETTINGS: PageSettings = {
  labels: DEFAULT_LABELS,
  locale: "en",
  layout: DEFAULT_LAYOUT,
  features: readFeatures(null),
  controls: DEFAULT_CONTROLS,
  lights: Object.values(Light),
};

const initial = {
  config: DEFAULT_SETTINGS,
  session: null,
  catalog: null,
  saved: null,
  appearance: null,
  past: [],
  future: [],
  bill: EMPTY_BILL,
  category: null,
  slot: null,
  camera: Camera.Full as Camera,
  light: Light.Natural as Light,
  outfits: [],
  result: null,
  busy: false,
  showOutfits: false,
};

export const useEditorStore = create<EditorState>(() => ({ ...initial }));

/** A label by key, with `{name}` placeholders. Falls back to the key's last part. */
export function label(key: string, vars?: Record<string, string | number>): string {
  const labels = useEditorStore.getState().config.labels;
  const text = labels[key] ?? DEFAULT_LABELS[key] ?? key.split(".").pop() ?? key;

  return vars ? text.replace(/\{(\w+)\}/g, (match, name: string) => String(vars[name] ?? match)) : text;
}

/** Replaces the edit, records the previous one for undo and sends the new one to Lua. */
export function edit(next: Appearance): void {
  const { appearance, past } = useEditorStore.getState();

  if (!appearance) {
    return;
  }

  useEditorStore.setState({ appearance: next, past: [...past, appearance].slice(-HISTORY_LIMIT), future: [] });
  sendChange(next);
}

/** Shows a candidate on the ped without recording it. `null` goes back to the edit. */
export function preview(candidate: Appearance | null): void {
  const { appearance } = useEditorStore.getState();

  if (appearance) {
    sendChange(candidate ?? appearance);
  }
}

export function undo(): void {
  const { appearance, past, future } = useEditorStore.getState();
  const previous = past[past.length - 1];

  if (!appearance || !previous) {
    return;
  }

  useEditorStore.setState({ appearance: previous, past: past.slice(0, -1), future: [appearance, ...future] });
  sendChange(previous);
}

export function redo(): void {
  const { appearance, past, future } = useEditorStore.getState();
  const following = future[0];

  if (!appearance || !following) {
    return;
  }

  useEditorStore.setState({ appearance: following, past: [...past, appearance], future: future.slice(1) });
  sendChange(following);
}

/** Opens a category or a slot, and frames it. */
export function selectCategory(category: Category, slot: string | null = null): void {
  const camera = cameraFor(category, slot ?? undefined);

  useEditorStore.setState({ category, slot, camera, showOutfits: false });
  void sendCamera(camera);
}

/** The edit differs from the saved appearance. */
export function isDirty(): boolean {
  return useEditorStore.getState().bill.lines.length > 0;
}

function open(payload: OpenPayload): void {
  const category = payload.categories[0] ?? null;
  const config = useEditorStore.getState().config;

  useEditorStore.setState({
    ...initial,
    config,
    light: config.lights[0] ?? Light.Natural,
    session: payload,
    catalog: payload.catalog,
    saved: payload.appearance,
    appearance: payload.appearance,
    outfits: payload.outfits ?? [],
    category,
    camera: Camera.Full,
  });
}

/** Applies one message from Lua. Exported for tests. */
export function handleMessage(message: NuiMessage): void {
  switch (message.action) {
    case NuiAction.Config: {
      const config = message.payload as PageConfig;

      applyTheme(config.theme);
      useEditorStore.setState({
        config: {
          ...config,
          labels: { ...DEFAULT_LABELS, ...config.labels },
          layout: readLayout(config.layout),
          features: readFeatures(config.features),
          controls: readControls(config.controls),
          lights: readLights(config.lights),
        },
      });
      break;
    }
    case NuiAction.Open:
      open(message.payload as OpenPayload);
      break;
    case NuiAction.Catalog: {
      const { catalog, appearance } = message.payload as { catalog: Catalog; appearance: Appearance };

      useEditorStore.setState({ catalog, appearance, past: [], future: [] });
      break;
    }
    case NuiAction.Appearance: {
      const { appearance, saved } = message.payload as { appearance: Appearance; saved: Appearance };

      useEditorStore.setState({ appearance, saved, past: [], future: [], busy: false });
      break;
    }
    case NuiAction.Outfits:
      useEditorStore.setState({ outfits: (message.payload as { outfits: Outfit[] }).outfits ?? [], busy: false });
      break;
    case NuiAction.Bill:
      useEditorStore.setState({ bill: message.payload as Bill });
      break;
    case NuiAction.Result:
      useEditorStore.setState({ result: message.payload as ActionResult, busy: false });
      break;
    case NuiAction.Close:
      useEditorStore.setState({ ...initial, config: useEditorStore.getState().config });
      break;
    default:
      break;
  }
}

/** Listens for Lua messages. Returns the uninstaller. */
export function installMessages(): () => void {
  const listener = (event: MessageEvent<NuiMessage>) => {
    if (event.data && typeof event.data.action === "string") {
      handleMessage(event.data);
    }
  };

  window.addEventListener("message", listener);

  return () => window.removeEventListener("message", listener);
}

/** Opens the outfits tab and frames the whole body. */
export function openOutfits(): void {
  useEditorStore.setState({ showOutfits: true, camera: Camera.Full });
  void sendCamera(Camera.Full);
}

/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// Showcase scenes: what the page shows for the README. The preview plays them, and `npm run capture` saves each one
// to .github/assets/<id>.webp, animated when `animated` is set. Add a scene for every screen worth showing.

import { COMPONENTS, FACE_FEATURES, OVERLAYS, PROPS } from "@/lib/appearance";
import { Category, NuiAction, StoreKind, type Appearance, type Catalog, type NuiMessage, type StoreKind as Kind } from "@/types/protocol";

/** One step: a message as Lua would send it, or a click on an element, then a pause. */
export interface SceneStep {
  send?: NuiMessage;
  /** CSS selector of the element to click. */
  click?: string;
  /** Milliseconds before the next step. */
  wait?: number;
}

export interface Scene {
  /** File name of the capture: lowercase, digits and dashes. */
  id: string;
  title: string;
  steps: SceneStep[];
  /** Captured as an animated image of the whole run, instead of a still of the end. */
  animated?: boolean;
  /** CSS selector of the element the capture is cropped to, with a margin. The whole screen when unset. */
  crop?: string;
}

/** A screen area in CSS pixels. */
export interface Area {
  x: number;
  y: number;
  width: number;
  height: number;
}

const palette = (count: number, shift: number) =>
  Array.from({ length: count }, (_, index) => {
    const hue = (index * 360) / count + shift;

    return [
      Math.round(128 + 100 * Math.cos((hue * Math.PI) / 180)),
      Math.round(128 + 100 * Math.cos(((hue - 120) * Math.PI) / 180)),
      Math.round(128 + 100 * Math.cos(((hue + 120) * Math.PI) / 180)),
    ];
  });

const textures = (count: number) => Array.from({ length: count }, (_, index) => 1 + (index % 4));

const CATALOG: Catalog = {
  freemode: true,
  components: Object.fromEntries(COMPONENTS.map((slot) => [slot, textures(slot === "top" ? 180 : 40)])),
  props: Object.fromEntries(PROPS.map((slot) => [slot, textures(30)])),
  hair: textures(70),
  overlays: Object.fromEntries(OVERLAYS.map((overlay) => [overlay, 20])),
  hairColors: palette(64, 0),
  makeupColors: palette(64, 40),
  tattoos: Array.from({ length: 240 }, (_, index) => ({ collection: 1000 + (index % 6), overlay: 5000 + index, zone: index % 7 })),
};

const APPEARANCE: Appearance = {
  model: "mp_m_freemode_01",
  headBlend: { shapeFirst: 0, shapeSecond: 21, shapeThird: 0, skinFirst: 0, skinSecond: 21, skinThird: 0, shapeMix: 0.5, skinMix: 0.5, thirdMix: 0 },
  faceFeatures: Object.fromEntries(FACE_FEATURES.map((feature) => [feature, 0])),
  headOverlays: Object.fromEntries(
    OVERLAYS.map((overlay) => [overlay, { style: overlay === "eyebrows" ? 0 : -1, opacity: 1, color: 0, secondColor: 0 }]),
  ),
  hair: { style: 4, texture: 0, color: 2, highlight: 2 },
  eyeColor: 0,
  components: Object.fromEntries(COMPONENTS.map((slot) => [slot, { drawable: 0, texture: 0 }])),
  props: Object.fromEntries(PROPS.map((slot) => [slot, { drawable: -1, texture: 0 }])),
  tattoos: [],
};

const KIND_CATEGORIES: Record<Kind, Category[]> = {
  [StoreKind.Clothing]: [Category.Clothing, Category.Accessories],
  [StoreKind.Barber]: [Category.Hair, Category.FacialHair, Category.Makeup],
  [StoreKind.Tattoo]: [Category.Tattoos],
  [StoreKind.Surgeon]: [Category.Heritage, Category.Features, Category.Eyes, Category.Skin],
  [StoreKind.Wardrobe]: [Category.Clothing, Category.Accessories],
  [StoreKind.Creator]: Object.values(Category),
  [StoreKind.Admin]: Object.values(Category),
};

/** The editor for a store kind, as Lua opens it, with a bill for paid stores. */
export function open(kind: Kind, wait = 900): SceneStep[] {
  const free = kind === StoreKind.Wardrobe || kind === StoreKind.Creator || kind === StoreKind.Admin;

  return [
    {
      send: {
        action: NuiAction.Open,
        payload: {
          kind,
          categories: KIND_CATEGORIES[kind],
          free,
          appearance: APPEARANCE,
          catalog: CATALOG,
          models: ["mp_m_freemode_01", "mp_f_freemode_01"],
          poses: [
            { id: "idle", label: "Standing" },
            { id: "handsUp", label: "Hands up" },
          ],
          outfits: [
            { id: 1, name: "Night out" },
            { id: 2, name: "Gym" },
          ],
          uniforms: kind === StoreKind.Clothing ? [] : ["Police · Officer"],
          maxTattoos: 60,
        },
      },
    },
    {
      send: {
        action: NuiAction.Bill,
        payload: free
          ? { total: 0, lines: [] }
          : {
              total: 140,
              lines: [
                { category: Category.Clothing, key: "top", price: 60 },
                { category: Category.Accessories, key: "hat", price: 40 },
                { category: Category.Accessories, key: "glasses", price: 40, removed: true },
              ],
            },
      },
      wait,
    },
  ];
}

const rail = (label: string) => `nav button[aria-label="${label}"]`;

export const SCENES: Scene[] = [
  { id: "character-creator", title: "Character creator", steps: open(StoreKind.Creator) },
  { id: "clothing-store", title: "Clothing store with a bill", steps: open(StoreKind.Clothing) },
  { id: "barber", title: "Barber", steps: open(StoreKind.Barber) },
  {
    id: "save-refused",
    title: "Refused by the server",
    steps: [
      ...open(StoreKind.Clothing, 300),
      { send: { action: NuiAction.Result, payload: { kind: "save", ok: false, message: "You cannot afford this." } }, wait: 700 },
    ],
  },
  {
    id: "editor-tour",
    title: "Moving between categories",
    animated: true,
    steps: [
      ...open(StoreKind.Creator, 1200),
      { click: rail("Hair"), wait: 1300 },
      { click: rail("Makeup"), wait: 1300 },
      { click: rail("Clothing"), wait: 1300 },
      { click: rail("Tattoos"), wait: 1500 },
    ],
  },
];


/**
 * Plays a scene through `send`. Resolves after the last step's pause, with the area the crop element covered after
 * any step, or null without a crop or when it never showed.
 */
export async function playScene(scene: Scene, send: (message: NuiMessage) => void): Promise<Area | null> {
  let area: Area | null = null;

  for (const step of scene.steps) {
    if (step.send) {
      send(step.send);
    }

    if (step.click) {
      document.querySelector<HTMLElement>(step.click)?.click();
    }

    await new Promise((resolve) => setTimeout(resolve, step.wait ?? 0));

    const box = scene.crop ? document.querySelector(scene.crop)?.getBoundingClientRect() : undefined;

    if (box && box.width > 0) {
      const left = Math.min(area?.x ?? box.left, box.left);
      const top = Math.min(area?.y ?? box.top, box.top);
      const right = Math.max(area ? area.x + area.width : box.right, box.right);
      const bottom = Math.max(area ? area.y + area.height : box.bottom, box.bottom);

      area = { x: left, y: top, width: right - left, height: bottom - top };
    }
  }

  return area;
}

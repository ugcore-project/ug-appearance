/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// Mirrors `UgAp.Enums` in shared/enums.lua. tests/nui.lua checks both sides match.

/** Messages Lua sends: `{ action, payload }`. */
export const NuiAction = {
  Config: "config",
  Open: "open",
  Catalog: "catalog",
  Appearance: "appearance",
  Outfits: "outfits",
  Bill: "bill",
  Result: "result",
  Close: "close",
} as const;

export type NuiAction = (typeof NuiAction)[keyof typeof NuiAction];

/** Callbacks the page posts. Lua checks every body. */
export const NuiCallback = {
  Ready: "ready",
  Change: "change",
  Camera: "camera",
  Rotate: "rotate",
  Zoom: "zoom",
  Pose: "pose",
  Light: "light",
  Compare: "compare",
  Save: "save",
  Cancel: "cancel",
  OutfitSave: "outfitSave",
  OutfitWear: "outfitWear",
  OutfitDelete: "outfitDelete",
  OutfitReplace: "outfitReplace",
  OutfitRename: "outfitRename",
  UniformWear: "uniformWear",
} as const;

export type NuiCallback = (typeof NuiCallback)[keyof typeof NuiCallback];

export const Category = {
  Model: "model",
  Heritage: "heritage",
  Features: "features",
  Eyes: "eyes",
  Skin: "skin",
  Hair: "hair",
  FacialHair: "facialHair",
  Makeup: "makeup",
  Clothing: "clothing",
  Accessories: "accessories",
  Tattoos: "tattoos",
} as const;

export type Category = (typeof Category)[keyof typeof Category];

export const StoreKind = {
  Clothing: "clothing",
  Barber: "barber",
  Tattoo: "tattoo",
  Surgeon: "surgeon",
  Wardrobe: "wardrobe",
  Creator: "creator",
  Admin: "admin",
} as const;

export type StoreKind = (typeof StoreKind)[keyof typeof StoreKind];

export const Camera = {
  Face: "face",
  Upper: "upper",
  Lower: "lower",
  Feet: "feet",
  Full: "full",
} as const;

export type Camera = (typeof Camera)[keyof typeof Camera];

export const Light = {
  Natural: "natural",
  Studio: "studio",
  Day: "day",
  Night: "night",
} as const;

export type Light = (typeof Light)[keyof typeof Light];

export const Side = {
  Left: "left",
  Right: "right",
} as const;

export type Side = (typeof Side)[keyof typeof Side];

export const Place = {
  Top: "top",
  Bottom: "bottom",
} as const;

export type Place = (typeof Place)[keyof typeof Place];

export const Feature = {
  Undo: "undo",
  Randomize: "randomize",
  Compare: "compare",
  Favorites: "favorites",
  Search: "search",
  Cameras: "cameras",
  Rotate: "rotate",
  Zoom: "zoom",
  Poses: "poses",
} as const;

export type Feature = (typeof Feature)[keyof typeof Feature];

export const ResultKind = {
  Save: "save",
  Outfit: "outfit",
} as const;

export type ResultKind = (typeof ResultKind)[keyof typeof ResultKind];

export interface Part {
  drawable: number;
  texture: number;
}

export interface OverlayValue {
  style: number;
  opacity: number;
  color: number;
  secondColor: number;
}

export interface HeadBlend {
  shapeFirst: number;
  shapeSecond: number;
  shapeThird: number;
  skinFirst: number;
  skinSecond: number;
  skinThird: number;
  shapeMix: number;
  skinMix: number;
  thirdMix: number;
}

export interface Hair {
  style: number;
  texture: number;
  color: number;
  highlight: number;
}

export interface Tattoo {
  collection: number;
  overlay: number;
}

export interface Appearance {
  model: string;
  headBlend: HeadBlend;
  faceFeatures: Record<string, number>;
  headOverlays: Record<string, OverlayValue>;
  hair: Hair;
  eyeColor: number;
  components: Record<string, Part>;
  props: Record<string, Part>;
  tattoos: Tattoo[];
}

export interface CatalogTattoo extends Tattoo {
  zone: number;
}

/** What the game offers for the ped: texture counts per drawable, styles per overlay, palettes, tattoos. */
export interface Catalog {
  freemode: boolean;
  components: Record<string, number[]>;
  props: Record<string, number[]>;
  hair?: number[];
  overlays: Record<string, number>;
  hairColors?: number[][];
  makeupColors?: number[][];
  tattoos?: CatalogTattoo[];
}

export interface Outfit {
  id: number;
  name: string;
}

export interface Pose {
  id: string;
  label: string;
}

export interface OpenPayload {
  kind: StoreKind;
  categories: Category[];
  free: boolean;
  appearance: Appearance;
  catalog: Catalog;
  models: string[];
  poses: Pose[];
  outfits: Outfit[];
  uniforms: string[];
  label?: string;
  maxTattoos: number;
}

export interface BillLine {
  category: Category;
  key: string;
  price: number;
  removed?: boolean;
}

export interface Bill {
  total: number;
  lines: BillLine[];
}

export interface ActionResult {
  kind: ResultKind;
  ok: boolean;
  message?: string;
  total?: number;
}

export interface ThemeConfig {
  mode: string;
  colors: Record<string, string>;
  radius: string;
  font: string;
  scale: number;
}

/** The owner's editor screen, from config.lua `layout`. */
export interface PanelLayout {
  side: Side;
  /** Panel width in rem. */
  width: number;
  /** Panel background opacity, 0 to 1. */
  opacity: number;
  blur: boolean;
  toolbar: Place;
  hint: boolean;
  animations: boolean;
  resultDuration: number;
}

export type Features = Record<Feature, boolean>;

export interface Controls {
  /** Degrees per dragged pixel. */
  dragSpeed: number;
  /** Meters per wheel unit. */
  zoomSpeed: number;
  /** Degrees per Q or E press. 0 turns the keys off. */
  keyRotate: number;
  /** Degrees per toolbar turn button. */
  rotateStep: number;
}

export interface PageConfig {
  theme?: ThemeConfig;
  labels: Record<string, string>;
  locale: string;
  layout?: unknown;
  features?: unknown;
  controls?: unknown;
  lights?: unknown;
}

/** The page config after the page checked every owner field. */
export interface PageSettings extends PageConfig {
  layout: PanelLayout;
  features: Features;
  controls: Controls;
  lights: Light[];
}

export interface NuiMessage {
  action: NuiAction;
  payload?: unknown;
}

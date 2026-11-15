/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// Appearance keys in native id order, the same as shared/appearance.lua, plus page helpers: which camera frames a
// slot, edits that keep the original untouched, and randomizing inside what the game offers.

import { Camera, Category, type Appearance, type Catalog } from "@/types/protocol";

export const COMPONENTS = ["mask", "arms", "legs", "bag", "shoes", "accessory", "undershirt", "armor", "decals", "top"] as const;
export const PROPS = ["hat", "glasses", "ears", "watch", "bracelet"] as const;
export const OVERLAYS = [
  "blemishes", "beard", "eyebrows", "ageing", "makeup", "blush", "complexion",
  "sunDamage", "lipstick", "moles", "chestHair", "bodyBlemishes", "addBodyBlemishes",
] as const;
export const FACE_FEATURES = [
  "noseWidth", "nosePeakHeight", "nosePeakLength", "noseBoneHeight", "nosePeakLowering", "noseBoneTwist",
  "eyebrowHeight", "eyebrowDepth", "cheekBoneHeight", "cheekBoneWidth", "cheekWidth", "eyeOpening",
  "lipThickness", "jawBoneWidth", "jawBoneLength", "chinBoneHeight", "chinBoneLength", "chinBoneWidth",
  "chinCleft", "neckThickness",
] as const;

/** Clothing slots in the order shoppers look for them. */
export const CLOTHING_ORDER = ["top", "undershirt", "legs", "shoes", "arms", "accessory", "mask", "bag", "armor", "decals"] as const;

export const OVERLAY_CATEGORY: Record<string, Category> = {
  blemishes: Category.Skin,
  beard: Category.FacialHair,
  eyebrows: Category.FacialHair,
  ageing: Category.Skin,
  makeup: Category.Makeup,
  blush: Category.Makeup,
  complexion: Category.Skin,
  sunDamage: Category.Skin,
  lipstick: Category.Makeup,
  moles: Category.Skin,
  chestHair: Category.FacialHair,
  bodyBlemishes: Category.Skin,
  addBodyBlemishes: Category.Skin,
};

/** Palette of overlays that take a color: hair colors or makeup colors. */
export const OVERLAY_PALETTE: Record<string, "hair" | "makeup"> = {
  beard: "hair",
  eyebrows: "hair",
  chestHair: "hair",
  makeup: "makeup",
  blush: "makeup",
  lipstick: "makeup",
};

const SLOT_CAMERA: Record<string, Camera> = {
  mask: Camera.Face,
  hat: Camera.Face,
  glasses: Camera.Face,
  ears: Camera.Face,
  legs: Camera.Lower,
  shoes: Camera.Feet,
  chestHair: Camera.Upper,
  bodyBlemishes: Camera.Upper,
  addBodyBlemishes: Camera.Upper,
};

const CATEGORY_CAMERA: Record<Category, Camera> = {
  [Category.Model]: Camera.Full,
  [Category.Heritage]: Camera.Face,
  [Category.Features]: Camera.Face,
  [Category.Eyes]: Camera.Face,
  [Category.Skin]: Camera.Face,
  [Category.Hair]: Camera.Face,
  [Category.FacialHair]: Camera.Face,
  [Category.Makeup]: Camera.Face,
  [Category.Clothing]: Camera.Upper,
  [Category.Accessories]: Camera.Upper,
  [Category.Tattoos]: Camera.Full,
};

/** The camera that frames a category, or one of its slots. */
export function cameraFor(category: Category, slot?: string): Camera {
  return (slot && SLOT_CAMERA[slot]) || CATEGORY_CAMERA[category];
}

/** A deep copy changed by `edit`. The original is never touched, so history keeps every step. */
export function produce(appearance: Appearance, edit: (draft: Appearance) => void): Appearance {
  const draft = structuredClone(appearance);

  edit(draft);

  return draft;
}

export const tattooKey = (tattoo: { collection: number; overlay: number }) => `${tattoo.collection}:${tattoo.overlay}`;

function pick(count: number, random: () => number): number {
  return count <= 0 ? 0 : Math.floor(random() * count);
}

/** Random choices inside the catalog for one category. Other categories stay as they are. */
export function randomize(appearance: Appearance, category: Category, catalog: Catalog, random = Math.random): Appearance {
  return produce(appearance, (draft) => {
    const hairColors = catalog.hairColors?.length ?? 0;
    const makeupColors = catalog.makeupColors?.length ?? 0;

    switch (category) {
      case Category.Clothing:
        for (const slot of COMPONENTS) {
          const textures = catalog.components[slot] ?? [];
          const drawable = pick(textures.length, random);

          draft.components[slot] = { drawable, texture: pick(textures[drawable] ?? 0, random) };
        }
        break;
      case Category.Accessories:
        for (const slot of PROPS) {
          const textures = catalog.props[slot] ?? [];
          const drawable = random() < 0.5 ? -1 : pick(textures.length, random);

          draft.props[slot] = { drawable, texture: drawable < 0 ? 0 : pick(textures[drawable] ?? 0, random) };
        }
        break;
      case Category.Hair: {
        const styles = catalog.hair ?? [];
        const style = pick(styles.length, random);

        draft.hair = { style, texture: pick(styles[style] ?? 0, random), color: pick(hairColors, random), highlight: pick(hairColors, random) };
        break;
      }
      case Category.Heritage:
        draft.headBlend = {
          shapeFirst: pick(46, random),
          shapeSecond: pick(46, random),
          shapeThird: 0,
          skinFirst: pick(46, random),
          skinSecond: pick(46, random),
          skinThird: 0,
          shapeMix: Math.round(random() * 100) / 100,
          skinMix: Math.round(random() * 100) / 100,
          thirdMix: 0,
        };
        break;
      case Category.Features:
        for (const feature of FACE_FEATURES) {
          draft.faceFeatures[feature] = Math.round((random() * 2 - 1) * 50) / 100;
        }
        break;
      case Category.Eyes:
        draft.eyeColor = pick(32, random);
        break;
      case Category.Skin:
      case Category.FacialHair:
      case Category.Makeup:
        for (const overlay of OVERLAYS) {
          if (OVERLAY_CATEGORY[overlay] !== category) {
            continue;
          }

          const colors = OVERLAY_PALETTE[overlay] === "makeup" ? makeupColors : hairColors;
          const styles = catalog.overlays[overlay] ?? 0;

          draft.headOverlays[overlay] = {
            style: random() < 0.4 ? -1 : pick(styles, random),
            opacity: Math.round((0.4 + random() * 0.6) * 100) / 100,
            color: pick(colors, random),
            secondColor: pick(colors, random),
          };
        }
        break;
      default:
        break;
    }
  });
}

/** `rgb(...)` of a palette entry, gray when the game gave none. */
export function rgb(color: number[] | undefined): string {
  if (!color || color.length < 3) {
    return "rgb(128, 128, 128)";
  }

  const [r, g, b] = color.map((value) => Math.max(0, Math.min(255, Math.round(value))));

  return `rgb(${r}, ${g}, ${b})`;
}

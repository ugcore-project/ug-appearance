/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// A color per editor category, so the rail and the panel header tell them apart. Owners recolor them through
// theme.colors (src/lib/theme.ts). Class names are written out in full so Tailwind finds them.

import { Category } from "@/types/protocol";

export interface ToneClasses {
  /** Icon color while not selected. */
  text: string;
  /** Selected: solid fill with a glow. */
  solid: string;
  /** Thin bar under the panel header. */
  bar: string;
}

export const CATEGORY_TONES: Record<Category, ToneClasses> = {
  [Category.Model]: { text: "text-tone-model-light", solid: "bg-tone-model text-tone-model-foreground shadow-lg shadow-tone-model/40", bar: "from-tone-model" },
  [Category.Heritage]: { text: "text-tone-heritage-light", solid: "bg-tone-heritage text-tone-heritage-foreground shadow-lg shadow-tone-heritage/40", bar: "from-tone-heritage" },
  [Category.Features]: { text: "text-tone-features-light", solid: "bg-tone-features text-tone-features-foreground shadow-lg shadow-tone-features/40", bar: "from-tone-features" },
  [Category.Eyes]: { text: "text-tone-eyes-light", solid: "bg-tone-eyes text-tone-eyes-foreground shadow-lg shadow-tone-eyes/40", bar: "from-tone-eyes" },
  [Category.Skin]: { text: "text-tone-skin-light", solid: "bg-tone-skin text-tone-skin-foreground shadow-lg shadow-tone-skin/40", bar: "from-tone-skin" },
  [Category.Hair]: { text: "text-tone-hair-light", solid: "bg-tone-hair text-tone-hair-foreground shadow-lg shadow-tone-hair/40", bar: "from-tone-hair" },
  [Category.FacialHair]: {
    text: "text-tone-facial-hair-light",
    solid: "bg-tone-facial-hair text-tone-facial-hair-foreground shadow-lg shadow-tone-facial-hair/40",
    bar: "from-tone-facial-hair",
  },
  [Category.Makeup]: { text: "text-tone-makeup-light", solid: "bg-tone-makeup text-tone-makeup-foreground shadow-lg shadow-tone-makeup/40", bar: "from-tone-makeup" },
  [Category.Clothing]: { text: "text-tone-clothing-light", solid: "bg-tone-clothing text-tone-clothing-foreground shadow-lg shadow-tone-clothing/40", bar: "from-tone-clothing" },
  [Category.Accessories]: {
    text: "text-tone-accessories-light",
    solid: "bg-tone-accessories text-tone-accessories-foreground shadow-lg shadow-tone-accessories/40",
    bar: "from-tone-accessories",
  },
  [Category.Tattoos]: { text: "text-tone-tattoos-light", solid: "bg-tone-tattoos text-tone-tattoos-foreground shadow-lg shadow-tone-tattoos/40", bar: "from-tone-tattoos" },
};

/** The outfits tab. */
export const OUTFIT_TONE: ToneClasses = { text: "text-tone-outfits-light", solid: "bg-tone-outfits text-tone-outfits-foreground shadow-lg shadow-tone-outfits/40", bar: "from-tone-outfits" };

/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// The owner's ug-lib theme, applied to this page too, so every UgCore screen looks the same. Same rules as ug-lib.

import type { ThemeConfig } from "@/types/protocol";

/** Theme tokens owners MAY override, mapped to their CSS variable. */
const THEME_TOKENS: Record<string, string> = {
  background: "--ug-background",
  foreground: "--ug-foreground",
  card: "--ug-card",
  cardForeground: "--ug-card-foreground",
  popover: "--ug-popover",
  popoverForeground: "--ug-popover-foreground",
  primary: "--ug-primary",
  primaryForeground: "--ug-primary-foreground",
  secondary: "--ug-secondary",
  secondaryForeground: "--ug-secondary-foreground",
  muted: "--ug-muted",
  mutedForeground: "--ug-muted-foreground",
  accent: "--ug-accent",
  accentForeground: "--ug-accent-foreground",
  destructive: "--ug-destructive",
  destructiveForeground: "--ug-destructive-foreground",
  success: "--ug-success",
  successForeground: "--ug-success-foreground",
  warning: "--ug-warning",
  warningForeground: "--ug-warning-foreground",
  border: "--ug-border",
  input: "--ug-input",
  ring: "--ug-ring",
};

/** A color per editor tab, with a lighter shade and a text color derived from it. */
export const TONE_TOKENS = [
  "model",
  "heritage",
  "features",
  "eyes",
  "skin",
  "hair",
  "facialHair",
  "makeup",
  "clothing",
  "accessories",
  "tattoos",
  "outfits",
] as const;

/** The heritage mix bar. One color each, nothing derived. */
const MIX_TOKENS = ["mixFirst", "mixSecond"] as const;

/** `facialHair` becomes `facial-hair`, as in `--ug-tone-facial-hair` and `bg-tone-facial-hair`. */
export const toneName = (token: string) => token.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`);

/** The lighter shade for icons and the text color on a solid fill, from one HSL triplet. */
export function toneShades(base: string): { light: string; foreground: string } {
  const [hue, saturation, lightness] = base.split(" ").map((part) => parseFloat(part));
  const l = lightness ?? 50;

  return {
    light: `${hue} ${saturation}% ${Math.min(l + 18, 88)}%`,
    foreground: l > 60 ? "0 0% 10%" : "0 0% 100%",
  };
}

const HSL_TRIPLET = /^\d+(\.\d+)? \d+(\.\d+)?% \d+(\.\d+)?%$/;
const SIZE = /^\d*\.?\d+(rem|px)$/;
const FONTS: Record<string, string> = {
  Inter: '"Inter Variable", ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
};

/** Applies theme values to `<html>`. Lua checked them; they are checked again before reaching CSS. */
export function applyTheme(theme: ThemeConfig | undefined): void {
  const root = document.documentElement;

  root.classList.toggle("dark", theme?.mode !== "light");

  for (const [token, cssVar] of Object.entries(THEME_TOKENS)) {
    const value = theme?.colors?.[token];

    if (typeof value === "string" && HSL_TRIPLET.test(value)) {
      root.style.setProperty(cssVar, value);
    } else {
      root.style.removeProperty(cssVar);
    }
  }

  for (const token of [...TONE_TOKENS, ...MIX_TOKENS]) {
    const name = `--ug-tone-${toneName(token)}`;
    const value = theme?.colors?.[token];
    const derived = (TONE_TOKENS as readonly string[]).includes(token);

    if (typeof value === "string" && HSL_TRIPLET.test(value)) {
      root.style.setProperty(name, value);

      if (derived) {
        const shades = toneShades(value);

        root.style.setProperty(`${name}-light`, shades.light);
        root.style.setProperty(`${name}-fg`, shades.foreground);
      }
    } else {
      root.style.removeProperty(name);
      root.style.removeProperty(`${name}-light`);
      root.style.removeProperty(`${name}-fg`);
    }
  }

  if (theme && SIZE.test(theme.radius)) {
    root.style.setProperty("--ug-radius", theme.radius);
  }

  const font = theme ? FONTS[theme.font] : undefined;

  if (font) {
    root.style.setProperty("--ug-font-sans", font);
  }

  const scale = theme && Number.isFinite(theme.scale) ? Math.min(Math.max(theme.scale, 0.75), 1.5) : 1;

  root.style.setProperty("--ug-scale", String(scale));
}

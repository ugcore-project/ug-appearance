/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// Favorite drawables per model and slot, in this page's storage on the player's PC. Storage MAY be missing or throw:
// favorites are a convenience and never break the editor.

const STORAGE_KEY = "ug-appearance:favorites";
const MAX_PER_SLOT = 100;

type Favorites = Record<string, number[]>;

function read(): Favorites {
  try {
    const parsed: unknown = JSON.parse(window.localStorage.getItem(STORAGE_KEY) ?? "{}");

    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      return {};
    }

    const clean: Favorites = {};

    for (const [key, value] of Object.entries(parsed as Record<string, unknown>)) {
      if (Array.isArray(value)) {
        clean[key] = value.filter((item): item is number => Number.isInteger(item)).slice(0, MAX_PER_SLOT);
      }
    }

    return clean;
  } catch {
    return {};
  }
}

function write(favorites: Favorites): void {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(favorites));
  } catch {
    // Storage is optional.
  }
}

export function getFavorites(key: string): number[] {
  return read()[key] ?? [];
}

/** Adds or removes a drawable. Returns the new list. */
export function toggleFavorite(key: string, drawable: number): number[] {
  const favorites = read();
  const list = favorites[key] ?? [];
  const next = list.includes(drawable) ? list.filter((item) => item !== drawable) : [...list, drawable].slice(-MAX_PER_SLOT);

  favorites[key] = next;
  write(favorites);

  return next;
}

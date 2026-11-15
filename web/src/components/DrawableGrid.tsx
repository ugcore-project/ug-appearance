/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// Numbered cards for every drawable of a slot, with live preview on hover, search, favorites, and the variants of the
// chosen one. No thumbnails: the ped itself is the preview.

import { useMemo, useState } from "react";
import { Ban, Search, Star } from "lucide-react";
import { cn } from "@/lib/cn";
import { getFavorites, toggleFavorite } from "@/lib/favorites";
import { label, useEditorStore } from "@/store/editorStore";
import { Feature, type Part } from "@/types/protocol";

/** Cards rendered at once. More appear on demand, so addon packs with hundreds of drawables stay fast. */
export const PAGE_SIZE = 60;

interface DrawableGridProps {
  /** Texture count per drawable: the length is the drawable count. */
  textures: number[];
  value: Part;
  /** Shows a `none` card for drawable -1 (props). */
  allowNone?: boolean;
  favoritesKey: string;
  onSelect: (part: Part) => void;
  onPreview: (part: Part | null) => void;
}

export function DrawableGrid({ textures, value, allowNone = false, favoritesKey, onSelect, onPreview }: DrawableGridProps) {
  const [query, setQuery] = useState("");
  const [onlyFavorites, setOnlyFavorites] = useState(false);
  const [favorites, setFavorites] = useState<number[]>(() => getFavorites(favoritesKey));
  const [shown, setShown] = useState(PAGE_SIZE);
  const features = useEditorStore((state) => state.config.features);
  const searching = features[Feature.Search];
  const starring = features[Feature.Favorites];

  const drawables = useMemo(() => {
    const all = textures.map((_, index) => index);
    const wanted = searching ? query.trim() : "";
    const filter = starring && onlyFavorites;

    return all.filter((drawable) => (!filter || favorites.includes(drawable)) && (wanted === "" || String(drawable + 1).includes(wanted)));
  }, [textures, query, onlyFavorites, favorites, searching, starring]);

  const variants = value.drawable >= 0 ? (textures[value.drawable] ?? 0) : 0;

  return (
    <div className="space-y-3">
      {(searching || starring) && (
      <div className="flex gap-2">
        {searching && (
        <label className="flex h-9 flex-1 items-center gap-2 rounded-md bg-white/5 px-3 text-sm focus-within:ring-2 focus-within:ring-ring">
          <Search className="h-4 w-4 text-muted-foreground" aria-hidden />
          <input
            className="w-full bg-transparent outline-none placeholder:text-muted-foreground"
            inputMode="numeric"
            placeholder={label("search")}
            aria-label={label("search")}
            value={query}
            onChange={(event) => setQuery(event.target.value.replace(/\D/g, "").slice(0, 4))}
          />
        </label>
        )}
        {starring && (
        <button
          type="button"
          aria-pressed={onlyFavorites}
          aria-label={label("favorites")}
          className={cn("flex h-9 w-9 items-center justify-center rounded-md bg-white/5", onlyFavorites && "bg-warning/20 text-warning")}
          onClick={() => setOnlyFavorites((current) => !current)}
        >
          <Star className="h-4 w-4" fill={onlyFavorites ? "currentColor" : "none"} />
        </button>
        )}
      </div>
      )}

      <div className="grid grid-cols-5 gap-1.5" onMouseLeave={() => onPreview(null)}>
        {allowNone && (
          <button
            type="button"
            className={cn(
              "flex aspect-square flex-col items-center justify-center rounded-md bg-white/5 text-muted-foreground transition-colors hover:bg-white/10",
              value.drawable < 0 && "bg-primary/20 text-foreground ring-2 ring-primary",
            )}
            onMouseEnter={() => onPreview({ drawable: -1, texture: 0 })}
            onClick={() => onSelect({ drawable: -1, texture: 0 })}
          >
            <Ban className="h-4 w-4" aria-hidden />
            <span className="mt-1 text-[10px]">{label("none")}</span>
          </button>
        )}
        {drawables.slice(0, shown).map((drawable) => {
          const selected = drawable === value.drawable;
          const favorite = favorites.includes(drawable);

          return (
            <div key={drawable} className="group relative">
              <button
                type="button"
                aria-label={`${label("drawable")} ${drawable + 1}`}
                aria-pressed={selected}
                className={cn(
                  "flex aspect-square w-full flex-col items-center justify-center rounded-md bg-white/5 transition duration-150",
                  "hover:-translate-y-0.5 hover:bg-white/10",
                  selected && "bg-primary/20 ring-2 ring-primary",
                )}
                onMouseEnter={() => onPreview({ drawable, texture: 0 })}
                onClick={() => onSelect({ drawable, texture: 0 })}
              >
                <span className="text-sm font-semibold tabular-nums">{drawable + 1}</span>
                <span className="mt-1 flex gap-0.5">
                  {Array.from({ length: Math.min(textures[drawable] ?? 0, 5) }, (_, index) => (
                    <span key={index} className="h-1 w-1 rounded-full bg-foreground/40" />
                  ))}
                </span>
              </button>
              {starring && (
              <button
                type="button"
                aria-label={label("favorites")}
                className={cn(
                  "absolute right-0.5 top-0.5 rounded p-0.5 text-warning opacity-0 transition-opacity group-hover:opacity-100",
                  favorite && "opacity-100",
                )}
                onClick={() => setFavorites(toggleFavorite(favoritesKey, drawable))}
              >
                <Star className="h-3 w-3" fill={favorite ? "currentColor" : "none"} />
              </button>
              )}
            </div>
          );
        })}
      </div>

      {drawables.length === 0 && <p className="py-6 text-center text-sm text-muted-foreground">{label("empty")}</p>}

      {drawables.length > shown && (
        <button type="button" className="w-full rounded-md bg-white/5 py-2 text-xs hover:bg-white/10" onClick={() => setShown((count) => count + PAGE_SIZE)}>
          +{drawables.length - shown}
        </button>
      )}

      {variants > 1 && (
        <div className="space-y-2">
          <h3 className="text-[11px] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{label("texture")}</h3>
          <div className="flex flex-wrap gap-1.5" onMouseLeave={() => onPreview(null)}>
            {Array.from({ length: variants }, (_, texture) => (
              <button
                key={texture}
                type="button"
                aria-label={`${label("texture")} ${texture + 1}`}
                aria-pressed={texture === value.texture}
                className={cn(
                  "h-8 min-w-8 rounded-full bg-white/5 px-2 text-xs tabular-nums hover:bg-white/10",
                  texture === value.texture && "bg-primary text-primary-foreground",
                )}
                onMouseEnter={() => onPreview({ drawable: value.drawable, texture })}
                onClick={() => onSelect({ drawable: value.drawable, texture })}
              >
                {texture + 1}
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

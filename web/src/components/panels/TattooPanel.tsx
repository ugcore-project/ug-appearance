/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// Tattoos by body zone. Hovering one shows it on the ped; clicking adds or removes it. The list comes from the game.

import { useMemo, useState } from "react";
import { Minus, Plus } from "lucide-react";
import { cn } from "@/lib/cn";
import { produce, tattooKey } from "@/lib/appearance";
import { edit, label, preview, useEditorStore } from "@/store/editorStore";
import type { Appearance, CatalogTattoo } from "@/types/protocol";

const ZONES = ["0", "1", "2", "3", "4", "5", "other"] as const;
const PAGE_SIZE = 80;

const zoneOf = (tattoo: CatalogTattoo) => (tattoo.zone >= 0 && tattoo.zone <= 5 ? String(tattoo.zone) : "other");

export function TattooPanel() {
  const appearance = useEditorStore((state) => state.appearance) as Appearance;
  const catalog = useEditorStore((state) => state.catalog);
  const maxTattoos = useEditorStore((state) => state.session?.maxTattoos ?? 0);
  const [zone, setZone] = useState<string>("0");
  const [shown, setShown] = useState(PAGE_SIZE);

  const worn = useMemo(() => new Set(appearance.tattoos.map(tattooKey)), [appearance.tattoos]);
  const list = useMemo(() => (catalog?.tattoos ?? []).filter((tattoo) => zoneOf(tattoo) === zone), [catalog, zone]);
  const full = appearance.tattoos.length >= maxTattoos;

  const toggled = (tattoo: CatalogTattoo) =>
    produce(appearance, (draft) => {
      const key = tattooKey(tattoo);

      draft.tattoos = worn.has(key)
        ? draft.tattoos.filter((item) => tattooKey(item) !== key)
        : [...draft.tattoos, { collection: tattoo.collection, overlay: tattoo.overlay }];
    });

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-1.5">
        {ZONES.map((key) => (
          <button
            key={key}
            type="button"
            aria-pressed={key === zone}
            className={cn("rounded-full px-3 py-1.5 text-xs", key === zone ? "bg-primary text-primary-foreground" : "bg-white/5 hover:bg-white/10")}
            onClick={() => {
              setZone(key);
              setShown(PAGE_SIZE);
            }}
          >
            {label(`zone.${key}`)}
          </button>
        ))}
      </div>

      <p className="text-xs text-muted-foreground tabular-nums">
        {label("tattoos")}: {appearance.tattoos.length}/{maxTattoos}
      </p>

      <div className="grid grid-cols-4 gap-1.5" onMouseLeave={() => preview(null)}>
        {list.slice(0, shown).map((tattoo, index) => {
          const key = tattooKey(tattoo);
          const on = worn.has(key);
          const disabled = !on && full;

          return (
            <button
              key={key}
              type="button"
              disabled={disabled}
              aria-pressed={on}
              aria-label={`${label(on ? "tattooRemove" : "tattooAdd")} ${index + 1}`}
              className={cn(
                "flex aspect-square flex-col items-center justify-center gap-1 rounded-md bg-white/5 transition hover:bg-white/10 disabled:opacity-40",
                on && "bg-primary/20 ring-2 ring-primary",
              )}
              onMouseEnter={() => !disabled && preview(toggled(tattoo))}
              onClick={() => edit(toggled(tattoo))}
            >
              <span className="text-sm font-semibold tabular-nums">{index + 1}</span>
              {on ? <Minus className="h-3 w-3" aria-hidden /> : <Plus className="h-3 w-3 text-muted-foreground" aria-hidden />}
            </button>
          );
        })}
      </div>

      {list.length === 0 && <p className="py-6 text-center text-sm text-muted-foreground">{label("empty")}</p>}

      {list.length > shown && (
        <button type="button" className="w-full rounded-md bg-white/5 py-2 text-xs hover:bg-white/10" onClick={() => setShown((count) => count + PAGE_SIZE)}>
          +{list.length - shown}
        </button>
      )}
    </div>
  );
}

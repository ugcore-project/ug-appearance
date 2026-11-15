/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// The vertical tab bar. Only the categories of the store are shown; outfits appear where clothes can be saved.

import type { LucideIcon } from "lucide-react";
import { Brush, Dna, Eye, Glasses, Layers, Palette, PenTool, ScanFace, Scissors, Shirt, Smile, User } from "lucide-react";
import { cn } from "@/lib/cn";
import { CATEGORY_TONES, OUTFIT_TONE, type ToneClasses } from "@/lib/tones";
import { label, openOutfits, selectCategory, useEditorStore } from "@/store/editorStore";
import { Category, Side, StoreKind } from "@/types/protocol";

const ICONS: Record<Category, LucideIcon> = {
  [Category.Model]: User,
  [Category.Heritage]: Dna,
  [Category.Features]: ScanFace,
  [Category.Eyes]: Eye,
  [Category.Skin]: Palette,
  [Category.Hair]: Scissors,
  [Category.FacialHair]: Smile,
  [Category.Makeup]: Brush,
  [Category.Clothing]: Shirt,
  [Category.Accessories]: Glasses,
  [Category.Tattoos]: PenTool,
};

const OUTFIT_KINDS: readonly string[] = [StoreKind.Clothing, StoreKind.Wardrobe, StoreKind.Admin];

/** The store kinds that show the outfits tab. */
const hasOutfits = (kind: string | undefined) => kind !== undefined && OUTFIT_KINDS.includes(kind);

function RailButton({ icon: Icon, text, active, tone, right, onClick }: {
  icon: LucideIcon;
  text: string;
  active: boolean;
  tone: ToneClasses;
  /** The rail sits on the right: the tooltip opens to the left. */
  right: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      title={text}
      aria-label={text}
      aria-pressed={active}
      className={cn(
        "group relative flex h-11 w-11 items-center justify-center rounded-xl transition-all duration-150",
        active ? tone.solid : cn(tone.text, "hover:bg-white/10 hover:brightness-125"),
      )}
      onClick={onClick}
    >
      <Icon className="h-5 w-5" aria-hidden />
      <span
        className={cn(
          "pointer-events-none absolute z-50 whitespace-nowrap rounded-md border border-white/10 bg-popover/95 px-2 py-1 text-xs text-popover-foreground opacity-0 shadow-lg transition-opacity group-hover:opacity-100",
          right ? "right-full mr-3" : "left-full ml-3",
        )}
      >
        {text}
      </span>
    </button>
  );
}

export function CategoryRail() {
  const categories = useEditorStore((state) => state.session?.categories ?? []);
  const kind = useEditorStore((state) => state.session?.kind);
  const category = useEditorStore((state) => state.category);
  const showOutfits = useEditorStore((state) => state.showOutfits);
  const right = useEditorStore((state) => state.config.layout.side === Side.Right);

  return (
    <nav className="flex flex-col items-center gap-1.5 rounded-2xl bg-black/60 p-1.5 backdrop-blur-md" aria-label={label("title")}>
      {categories.map((key) => (
        <RailButton
          key={key}
          icon={ICONS[key]}
          text={label(`category.${key}`)}
          tone={CATEGORY_TONES[key]}
          right={right}
          active={!showOutfits && key === category}
          onClick={() => selectCategory(key)}
        />
      ))}
      {hasOutfits(kind) && (
        <>
          <span className="my-1 h-px w-6 bg-white/10" />
          <RailButton icon={Layers} text={label("outfits")} active={showOutfits} tone={OUTFIT_TONE} right={right} onClick={openOutfits} />
        </>
      )}
    </nav>
  );
}

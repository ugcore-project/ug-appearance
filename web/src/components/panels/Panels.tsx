/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// One panel per category. Every change goes through `edit` (recorded, sent to Lua) and every hover through `preview`.

import { cn } from "@/lib/cn";
import {
  CLOTHING_ORDER,
  FACE_FEATURES,
  OVERLAYS,
  OVERLAY_CATEGORY,
  OVERLAY_PALETTE,
  PROPS,
  produce,
} from "@/lib/appearance";
import { edit, label, preview, selectCategory, useEditorStore } from "@/store/editorStore";
import { Category, type Appearance, type Part } from "@/types/protocol";
import { DrawableGrid } from "@/components/DrawableGrid";
import { Section, Slider, Stepper, Swatches } from "@/components/ui/Controls";

const PARENTS = 46;
const EYE_COLORS = 32;

function useEdit(): Appearance {
  return useEditorStore((state) => state.appearance) as Appearance;
}

/** Chips to switch slots inside a category. Switching also frames the slot. */
function SlotChips({ category, slots, prefix }: { category: Category; slots: readonly string[]; prefix: string }) {
  const slot = useEditorStore((state) => state.slot) ?? slots[0];

  return (
    <div className="-mx-1 flex flex-wrap gap-1.5">
      {slots.map((key) => (
        <button
          key={key}
          type="button"
          aria-pressed={key === slot}
          className={cn(
            "rounded-full px-3 py-1.5 text-xs transition-colors",
            key === slot ? "bg-primary text-primary-foreground" : "bg-white/5 hover:bg-white/10",
          )}
          onClick={() => selectCategory(category, key)}
        >
          {label(`${prefix}.${key}`)}
        </button>
      ))}
    </div>
  );
}

export function ClothingPanel({ props: isProps }: { props: boolean }) {
  const appearance = useEdit();
  const catalog = useEditorStore((state) => state.catalog);
  const category = isProps ? Category.Accessories : Category.Clothing;
  const slots: readonly string[] = isProps ? PROPS : CLOTHING_ORDER;
  const slot = useEditorStore((state) => state.slot) ?? slots[0] ?? "";
  const group = isProps ? "props" : "components";
  const textures = (isProps ? catalog?.props[slot] : catalog?.components[slot]) ?? [];
  const value = appearance[group][slot] ?? { drawable: 0, texture: 0 };
  const withPart = (part: Part) =>
    produce(appearance, (draft) => {
      draft[group][slot] = part;
    });

  return (
    <div className="space-y-4">
      <SlotChips category={category} slots={slots} prefix={isProps ? "prop" : "component"} />
      <DrawableGrid
        key={`${appearance.model}:${slot}`}
        textures={textures}
        value={value}
        allowNone={isProps}
        favoritesKey={`${appearance.model}:${group}:${slot}`}
        onSelect={(part) => edit(withPart(part))}
        onPreview={(part) => preview(part ? withPart(part) : null)}
      />
    </div>
  );
}

export function HairPanel() {
  const appearance = useEdit();
  const catalog = useEditorStore((state) => state.catalog);
  const colors = catalog?.hairColors ?? [];
  const withHair = (change: Partial<Appearance["hair"]>) =>
    produce(appearance, (draft) => {
      draft.hair = { ...draft.hair, ...change };
    });

  return (
    <div className="space-y-5">
      <DrawableGrid
        key={`${appearance.model}:hair`}
        textures={catalog?.hair ?? []}
        value={{ drawable: appearance.hair.style, texture: appearance.hair.texture }}
        favoritesKey={`${appearance.model}:hair`}
        onSelect={(part) => edit(withHair({ style: part.drawable, texture: part.texture }))}
        onPreview={(part) => preview(part ? withHair({ style: part.drawable, texture: part.texture }) : null)}
      />
      <Swatches
        label={label("color")}
        colors={colors}
        value={appearance.hair.color}
        onChange={(color) => edit(withHair({ color }))}
        onPreview={(color) => preview(color === null ? null : withHair({ color }))}
      />
      <Swatches
        label={label("highlight")}
        colors={colors}
        value={appearance.hair.highlight}
        onChange={(highlight) => edit(withHair({ highlight }))}
        onPreview={(highlight) => preview(highlight === null ? null : withHair({ highlight }))}
      />
    </div>
  );
}

export function OverlayPanel({ category }: { category: Category }) {
  const appearance = useEdit();
  const catalog = useEditorStore((state) => state.catalog);
  const slots = OVERLAYS.filter((overlay) => OVERLAY_CATEGORY[overlay] === category);
  const slot = useEditorStore((state) => state.slot) ?? slots[0] ?? "";
  const overlay = appearance.headOverlays[slot] ?? { style: -1, opacity: 1, color: 0, secondColor: 0 };
  const styles = catalog?.overlays[slot] ?? 0;
  const palette = OVERLAY_PALETTE[slot];
  const colors = (palette === "makeup" ? catalog?.makeupColors : catalog?.hairColors) ?? [];
  const withOverlay = (change: Partial<typeof overlay>) =>
    produce(appearance, (draft) => {
      draft.headOverlays[slot] = { ...overlay, ...change };
    });

  return (
    <div className="space-y-5">
      {slots.length > 1 && <SlotChips category={category} slots={slots} prefix="overlay" />}
      <DrawableGrid
        key={`${appearance.model}:${slot}`}
        textures={Array.from({ length: styles }, () => 1)}
        value={{ drawable: overlay.style, texture: 0 }}
        allowNone
        favoritesKey={`${appearance.model}:overlay:${slot}`}
        onSelect={(part) => edit(withOverlay({ style: part.drawable }))}
        onPreview={(part) => preview(part ? withOverlay({ style: part.drawable }) : null)}
      />
      {overlay.style >= 0 && (
        <>
          <Slider label={label("opacity")} value={overlay.opacity} min={0} max={1} onChange={(opacity) => edit(withOverlay({ opacity }))} />
          {palette && (
            <Swatches
              label={label("color")}
              colors={colors}
              value={overlay.color}
              onChange={(color) => edit(withOverlay({ color }))}
              onPreview={(color) => preview(color === null ? null : withOverlay({ color }))}
            />
          )}
        </>
      )}
    </div>
  );
}

export function HeritagePanel() {
  const appearance = useEdit();
  const blend = appearance.headBlend;
  const withBlend = (change: Partial<typeof blend>) =>
    produce(appearance, (draft) => {
      draft.headBlend = { ...draft.headBlend, ...change };
    });

  return (
    <div className="space-y-5">
      <Section title={label("category.heritage")}>
        <div className="space-y-1.5">
          {(["shapeFirst", "shapeSecond", "skinFirst", "skinSecond"] as const).map((key) => (
            <Stepper key={key} label={label(key)} value={blend[key]} count={PARENTS} onChange={(value) => edit(withBlend({ [key]: value }))} />
          ))}
        </div>
      </Section>
      <div className="relative h-2 overflow-hidden rounded-full bg-gradient-to-r from-tone-mix-first/70 to-tone-mix-second/70">
        <span className="absolute top-0 h-full w-1 -translate-x-1/2 rounded-full bg-white" style={{ left: `${blend.shapeMix * 100}%` }} />
      </div>
      <Slider label={label("shapeMix")} value={blend.shapeMix} min={0} max={1} onChange={(shapeMix) => edit(withBlend({ shapeMix }))} />
      <Slider label={label("skinMix")} value={blend.skinMix} min={0} max={1} onChange={(skinMix) => edit(withBlend({ skinMix }))} />
    </div>
  );
}

export function FeaturesPanel() {
  const appearance = useEdit();

  return (
    <div className="space-y-3">
      {FACE_FEATURES.map((feature) => (
        <Slider
          key={feature}
          label={label(`feature.${feature}`)}
          value={appearance.faceFeatures[feature] ?? 0}
          min={-1}
          max={1}
          centered
          onChange={(value) =>
            edit(
              produce(appearance, (draft) => {
                draft.faceFeatures[feature] = value;
              }),
            )
          }
        />
      ))}
    </div>
  );
}

export function EyesPanel() {
  const appearance = useEdit();
  const withEyes = (eyeColor: number) =>
    produce(appearance, (draft) => {
      draft.eyeColor = eyeColor;
    });

  return (
    <div className="space-y-3">
      <Stepper label={label("eyeColor")} value={appearance.eyeColor} count={EYE_COLORS} onChange={(value) => edit(withEyes(value))} />
      <div className="grid grid-cols-8 gap-1.5" onMouseLeave={() => preview(null)}>
        {Array.from({ length: EYE_COLORS }, (_, index) => (
          <button
            key={index}
            type="button"
            aria-label={`${label("eyeColor")} ${index + 1}`}
            className={cn(
              "aspect-square rounded-md bg-white/5 text-xs tabular-nums hover:bg-white/10",
              index === appearance.eyeColor && "bg-primary/20 ring-2 ring-primary",
            )}
            onMouseEnter={() => preview(withEyes(index))}
            onClick={() => edit(withEyes(index))}
          >
            {index + 1}
          </button>
        ))}
      </div>
    </div>
  );
}

export function ModelPanel() {
  const appearance = useEdit();
  const models = useEditorStore((state) => state.session?.models ?? []);

  return (
    <div className="grid grid-cols-2 gap-2">
      {models.map((model) => (
        <button
          key={model}
          type="button"
          aria-pressed={model === appearance.model}
          className={cn(
            "rounded-lg bg-white/5 px-3 py-4 text-sm font-medium transition hover:bg-white/10",
            model === appearance.model && "bg-primary/20 ring-2 ring-primary",
          )}
          onClick={() =>
            model !== appearance.model &&
            edit(
              produce(appearance, (draft) => {
                draft.model = model;
              }),
            )
          }
        >
          {model === "mp_m_freemode_01" ? label("modelMale") : model === "mp_f_freemode_01" ? label("modelFemale") : model}
        </button>
      ))}
    </div>
  );
}

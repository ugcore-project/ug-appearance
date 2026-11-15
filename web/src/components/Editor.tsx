/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// The editor screen. The empty middle is the stage: dragging turns the ped, the wheel zooms.

import { useEffect, useRef, useState, type PointerEvent, type WheelEvent } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { cn } from "@/lib/cn";
import { CATEGORY_TONES, OUTFIT_TONE } from "@/lib/tones";
import { sendCancel, sendRotate, sendSave, sendZoom } from "@/lib/nui";
import { isDirty, label, redo, undo, useEditorStore } from "@/store/editorStore";
import { Category, Feature, Place, Side, type ActionResult } from "@/types/protocol";
import { BillCard } from "@/components/BillCard";
import { CategoryRail } from "@/components/CategoryRail";
import { Toolbar } from "@/components/Toolbar";
import { ConfirmDialog } from "@/components/ui/Dialog";
import {
  ClothingPanel,
  EyesPanel,
  FeaturesPanel,
  HairPanel,
  HeritagePanel,
  ModelPanel,
  OverlayPanel,
} from "@/components/panels/Panels";
import { OutfitsPanel } from "@/components/panels/OutfitsPanel";
import { TattooPanel } from "@/components/panels/TattooPanel";

function Panel({ category }: { category: Category }) {
  switch (category) {
    case Category.Model:
      return <ModelPanel />;
    case Category.Heritage:
      return <HeritagePanel />;
    case Category.Features:
      return <FeaturesPanel />;
    case Category.Eyes:
      return <EyesPanel />;
    case Category.Hair:
      return <HairPanel />;
    case Category.Skin:
    case Category.FacialHair:
    case Category.Makeup:
      return <OverlayPanel category={category} />;
    case Category.Clothing:
      return <ClothingPanel props={false} />;
    case Category.Accessories:
      return <ClothingPanel props />;
    case Category.Tattoos:
      return <TattooPanel />;
    default:
      return null;
  }
}

function ResultToast({ result }: { result: ActionResult }) {
  return (
    <motion.div
      role="status"
      layout
      initial={{ opacity: 0, y: 12, scale: 0.95 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, y: 8, scale: 0.97 }}
      transition={{ type: "spring", stiffness: 460, damping: 32 }}
      className={cn(
        "rounded-xl px-4 py-2.5 text-sm font-medium shadow-lg backdrop-blur-md",
        result.ok ? "bg-success/90 text-success-foreground" : "bg-destructive/90 text-destructive-foreground",
      )}
    >
      {result.message ?? label(result.ok ? "saved" : "errorFailed")}
    </motion.div>
  );
}

/** Typing in a field MUST NOT turn the ped or leave the editor. */
const isTyping = (target: EventTarget | null) =>
  target instanceof HTMLElement && (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.tagName === "SELECT");

export function Editor() {
  const session = useEditorStore((state) => state.session);
  const category = useEditorStore((state) => state.category);
  const showOutfits = useEditorStore((state) => state.showOutfits);
  const result = useEditorStore((state) => state.result);
  const { layout, features, controls } = useEditorStore((state) => state.config);
  const [leaving, setLeaving] = useState(false);
  const drag = useRef<number | null>(null);

  const save = () => {
    if (!useEditorStore.getState().busy) {
      useEditorStore.setState({ busy: true, result: null });
      void sendSave();
    }
  };

  const cancel = () => {
    if (isDirty()) {
      setLeaving(true);
    } else {
      void sendCancel();
    }
  };

  useEffect(() => {
    if (!result) {
      return undefined;
    }

    const timer = window.setTimeout(() => useEditorStore.setState({ result: null }), layout.resultDuration);

    return () => window.clearTimeout(timer);
  }, [result, layout.resultDuration]);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (isTyping(event.target)) {
        return;
      }

      const key = event.key.toLowerCase();
      const turns = features[Feature.Rotate] && controls.keyRotate > 0;

      if (!features[Feature.Undo] && (event.ctrlKey || event.metaKey) && (key === "z" || key === "y")) {
        return;
      }

      if ((event.ctrlKey || event.metaKey) && key === "z") {
        event.preventDefault();

        if (event.shiftKey) {
          redo();
        } else {
          undo();
        }
      } else if ((event.ctrlKey || event.metaKey) && key === "y") {
        event.preventDefault();
        redo();
      } else if (turns && key === "q") {
        sendRotate(-controls.keyRotate);
      } else if (turns && key === "e") {
        sendRotate(controls.keyRotate);
      } else if (key === "escape") {
        cancel();
      }
    };

    window.addEventListener("keydown", onKey);

    return () => window.removeEventListener("keydown", onKey);
  });

  if (!session) {
    return null;
  }

  const onPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    if (!features[Feature.Rotate]) {
      return;
    }

    drag.current = event.clientX;
    event.currentTarget.setPointerCapture(event.pointerId);
  };

  const onPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    if (drag.current !== null) {
      sendRotate((event.clientX - drag.current) * controls.dragSpeed);
      drag.current = event.clientX;
    }
  };

  const onPointerUp = () => {
    drag.current = null;
  };

  const onWheel = (event: WheelEvent<HTMLDivElement>) => {
    if (features[Feature.Zoom]) {
      void sendZoom(event.deltaY * controls.zoomSpeed);
    }
  };

  const title = session.label ?? label(`kind.${session.kind}`);
  const tone = showOutfits || !category ? OUTFIT_TONE : CATEGORY_TONES[category];
  const heading = showOutfits ? label("outfits") : category ? label(`category.${category}`) : "";
  const right = layout.side === Side.Right;
  // The panel, the rail and the gaps: the toolbar keeps clear of them on narrow screens.
  const clearance = { "--ug-clear": `${layout.width + 6}rem` } as React.CSSProperties;

  return (
    <div data-side={layout.side} className={cn("fixed inset-0 select-none text-foreground", !layout.animations && "ug-still")}>
      <div
        className={cn("absolute inset-0", features[Feature.Rotate] && "cursor-grab active:cursor-grabbing")}
        data-testid="stage"
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        onWheel={onWheel}
      />

      <div className={cn("pointer-events-none absolute inset-y-6 flex gap-3", right ? "right-6 flex-row-reverse" : "left-6")}>
        {/* Above the panel, so the rail's tooltips are not drawn behind it. */}
        <div className="pointer-events-auto relative z-20 self-center">
          <CategoryRail />
        </div>
        <section
          data-panel
          className={cn("pointer-events-auto flex flex-col overflow-hidden rounded-2xl", layout.blur && "backdrop-blur-md")}
          style={{ width: `${layout.width}rem`, backgroundColor: `rgb(0 0 0 / ${layout.opacity})` }}
        >
          <header className="relative border-b border-white/10 px-5 py-4">
            <p className={cn("text-xs font-semibold uppercase tracking-widest", tone.text)}>{title}</p>
            <h1 className="text-xl font-bold">{heading}</h1>
            <span className={cn("absolute inset-x-0 bottom-0 h-0.5 bg-gradient-to-r to-transparent", tone.bar)} />
          </header>
          <div key={showOutfits ? "outfits" : (category ?? "")} className="ug-enter flex-1 overflow-y-auto px-5 py-4">
            {showOutfits ? <OutfitsPanel /> : category && <Panel category={category} />}
          </div>
        </section>
      </div>

      {/* Centered on the screen. Narrower screens center it right of the panel, so they never overlap. */}
      <div
        data-toolbar={layout.toolbar}
        className={cn(
          "pointer-events-none absolute inset-x-6 flex justify-center min-[1600px]:px-0",
          layout.toolbar === Place.Bottom ? "bottom-14" : "top-6",
          right ? "pr-[var(--ug-clear)]" : "pl-[var(--ug-clear)]",
        )}
        style={clearance}
      >
        <div className="pointer-events-auto">
          <Toolbar />
        </div>
      </div>

      <div className={cn("pointer-events-none absolute bottom-6 flex flex-col gap-3", right ? "left-6 items-start" : "right-6 items-end")}>
        <AnimatePresence>{result && <ResultToast key={`${result.kind}-${String(result.ok)}-${result.message ?? ""}`} result={result} />}</AnimatePresence>
        <div className="pointer-events-auto">
          <BillCard onSave={save} onCancel={cancel} />
        </div>
      </div>

      {layout.hint && (
        <p data-hint className="pointer-events-none absolute inset-x-0 bottom-6 text-center text-xs text-white/60 [text-shadow:0_1px_2px_rgb(0_0_0/0.8)]">
          {label("hint")}
        </p>
      )}

      <ConfirmDialog
        open={leaving}
        title={label("leaveTitle")}
        hint={label("leaveHint")}
        confirmLabel={label("leave")}
        cancelLabel={label("stay")}
        destructive
        onCancel={() => setLeaving(false)}
        onConfirm={() => {
          setLeaving(false);
          void sendCancel();
        }}
      />
    </div>
  );
}

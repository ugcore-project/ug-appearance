/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// Small controls shared by the panels: a labeled slider, a color palette, a stepper and section headings.

import { useState, type ReactNode } from "react";
import { cn } from "@/lib/cn";
import { rgb } from "@/lib/appearance";

export function Section({ title, children, aside }: { title: string; children: ReactNode; aside?: ReactNode }) {
  return (
    <section className="space-y-2">
      <div className="flex items-center justify-between">
        <h3 className="text-[11px] font-semibold uppercase tracking-[0.12em] text-muted-foreground">{title}</h3>
        {aside}
      </div>
      {children}
    </section>
  );
}

interface SliderProps {
  label: string;
  value: number;
  min: number;
  max: number;
  step?: number;
  /** Shows a mark at the middle, for features that go both ways. */
  centered?: boolean;
  onChange: (value: number) => void;
}

export function Slider({ label, value, min, max, step = 0.01, centered = false, onChange }: SliderProps) {
  const percent = ((value - min) / (max - min)) * 100;
  const shown = centered ? `${value > 0 ? "+" : ""}${Math.round(value * 100)}` : `${Math.round(percent)}%`;

  return (
    <label className="block space-y-1.5">
      <span className="flex items-center justify-between text-xs">
        <span className="text-foreground/90">{label}</span>
        <span className="tabular-nums text-muted-foreground">{shown}</span>
      </span>
      <span className="relative block">
        {centered && <span className="pointer-events-none absolute left-1/2 top-1/2 h-3 w-px -translate-y-1/2 bg-foreground/30" />}
        <input
          type="range"
          aria-label={label}
          className="ug-range w-full"
          min={min}
          max={max}
          step={step}
          value={value}
          style={{ ["--ug-fill" as string]: `${percent}%` }}
          onChange={(event) => onChange(Number(event.target.value))}
          onDoubleClick={() => onChange(centered ? 0 : min)}
        />
      </span>
    </label>
  );
}

interface SwatchesProps {
  label: string;
  colors: number[][];
  value: number;
  onChange: (index: number) => void;
  onPreview?: (index: number | null) => void;
}

export function Swatches({ label, colors, value, onChange, onPreview }: SwatchesProps) {
  return (
    <Section title={label}>
      <div className="grid grid-cols-10 gap-1.5" onMouseLeave={() => onPreview?.(null)}>
        {colors.map((color, index) => (
          <button
            key={index}
            type="button"
            aria-label={`${label} ${index + 1}`}
            className={cn(
              "aspect-square rounded-full ring-offset-2 ring-offset-card transition-transform duration-150 hover:scale-110",
              index === value ? "ring-2 ring-primary" : "ring-1 ring-white/10",
            )}
            style={{ background: rgb(color) }}
            onMouseEnter={() => onPreview?.(index)}
            onClick={() => onChange(index)}
          />
        ))}
      </div>
    </Section>
  );
}

interface StepperProps {
  label: string;
  value: number;
  count: number;
  /** Allows -1, shown as `none`. */
  noneLabel?: string;
  onChange: (value: number) => void;
}

/** Previous and next through a numbered list, for long lists such as parents. The number is typed in too. */
export function Stepper({ label, value, count, noneLabel, onChange }: StepperProps) {
  const min = noneLabel ? -1 : 0;
  const total = count - min;
  const go = (delta: number) => onChange(((value - min + delta + total) % total) + min);
  const shown = value < 0 ? "" : String(value + 1);
  const [draft, setDraft] = useState<string | null>(null);

  // Typed numbers are 1-based. Empty or 0 means none where allowed; anything else out of range is dropped.
  const commit = () => {
    if (draft === null) {
      return;
    }

    const text = draft.trim();
    const typed = text === "" ? 0 : Number(text);

    setDraft(null);

    if (!Number.isInteger(typed)) {
      return;
    }

    if (typed === 0 && noneLabel) {
      onChange(-1);
    } else if (typed >= 1 && typed <= count && typed - 1 !== value) {
      onChange(typed - 1);
    }
  };

  return (
    <div className="flex items-center justify-between gap-2 rounded-md bg-white/5 px-2 py-1.5">
      <span className="min-w-0 truncate text-xs text-foreground/90">{label}</span>
      <span className="flex shrink-0 items-center gap-1">
        <button type="button" aria-label={`${label} -`} className="h-7 w-7 rounded-md text-white/85 hover:bg-white/10 hover:text-white" onClick={() => go(-1)}>
          ‹
        </button>
        <span className="flex items-baseline gap-0.5 text-sm font-semibold tabular-nums">
          <input
            type="text"
            inputMode="numeric"
            aria-label={label}
            className="w-10 rounded bg-transparent text-right outline-none placeholder:text-muted-foreground focus:bg-white/10 focus:ring-1 focus:ring-ring"
            value={draft ?? shown}
            placeholder={value < 0 && noneLabel ? noneLabel : undefined}
            onFocus={(event) => {
              setDraft(shown);
              event.currentTarget.select();
            }}
            onChange={(event) => setDraft(event.target.value.replace(/[^0-9]/g, "").slice(0, 4))}
            onBlur={commit}
            onKeyDown={(event) => {
              if (event.key === "Enter") {
                event.currentTarget.blur();
              } else if (event.key === "Escape") {
                event.stopPropagation();
                setDraft(null);
                event.currentTarget.blur();
              } else if (event.key === "ArrowUp" || event.key === "ArrowDown") {
                event.preventDefault();
                setDraft(null);
                go(event.key === "ArrowUp" ? 1 : -1);
              }
            }}
          />
          <span className="text-xs font-normal text-muted-foreground">/{count}</span>
        </span>
        <button type="button" aria-label={`${label} +`} className="h-7 w-7 rounded-md text-white/85 hover:bg-white/10 hover:text-white" onClick={() => go(1)}>
          ›
        </button>
      </span>
    </div>
  );
}

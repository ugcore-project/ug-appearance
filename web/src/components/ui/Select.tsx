/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// A dropdown in the editor's style. Native selects open an OS list that CEF draws in its own colors.

import { useEffect, useId, useRef, useState, type KeyboardEvent } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { Check, ChevronDown } from "lucide-react";
import { cn } from "@/lib/cn";

export interface SelectOption {
  value: string;
  label: string;
}

interface SelectProps {
  label: string;
  value: string;
  options: SelectOption[];
  onChange: (value: string) => void;
  className?: string;
}

export function Select({ label, value, options, onChange, className }: SelectProps) {
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);
  const root = useRef<HTMLDivElement>(null);
  const listId = useId();
  const current = options.find((option) => option.value === value) ?? options[0];

  useEffect(() => {
    if (!open) {
      return undefined;
    }

    const onPointer = (event: PointerEvent) => {
      if (root.current && !root.current.contains(event.target as Node)) {
        setOpen(false);
      }
    };

    window.addEventListener("pointerdown", onPointer);

    return () => window.removeEventListener("pointerdown", onPointer);
  }, [open]);

  const show = () => {
    setActive(Math.max(0, options.findIndex((option) => option.value === value)));
    setOpen(true);
  };

  const choose = (option: SelectOption) => {
    setOpen(false);

    if (option.value !== value) {
      onChange(option.value);
    }
  };

  // React stops the native event too, so the editor's window keys (Escape, Q, E) do not fire while choosing.
  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const key = event.key;

    if (!open) {
      if (key === "ArrowDown" || key === "ArrowUp") {
        event.preventDefault();
        event.stopPropagation();
        show();
      }

      return;
    }

    event.stopPropagation();

    if (key === "Escape") {
      setOpen(false);
    } else if (key === "ArrowDown") {
      event.preventDefault();
      setActive((index) => (index + 1) % options.length);
    } else if (key === "ArrowUp") {
      event.preventDefault();
      setActive((index) => (index - 1 + options.length) % options.length);
    } else if (key === "Enter" || key === " ") {
      event.preventDefault();

      const option = options[active];

      if (option) {
        choose(option);
      }
    }
  };

  return (
    <div ref={root} className={cn("relative", className)} onKeyDown={onKeyDown}>
      <button
        type="button"
        aria-label={label}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={listId}
        className="flex h-9 items-center gap-1.5 rounded-lg px-2.5 text-xs text-foreground transition-colors hover:bg-white/10"
        onClick={() => (open ? setOpen(false) : show())}
      >
        <span className="max-w-[9rem] truncate">{current?.label}</span>
        <ChevronDown className={cn("h-3.5 w-3.5 text-white/70 transition-transform duration-200", open && "rotate-180")} aria-hidden />
      </button>

      <AnimatePresence>
        {open && (
          <motion.ul
            id={listId}
            role="listbox"
            aria-label={label}
            className="absolute right-0 top-full z-40 mt-2 max-h-64 min-w-[10rem] overflow-y-auto rounded-xl border border-white/10 bg-popover/95 p-1 text-popover-foreground shadow-2xl backdrop-blur-md"
            initial={{ opacity: 0, y: -6, scale: 0.97 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            exit={{ opacity: 0, y: -4, scale: 0.98 }}
            transition={{ duration: 0.14, ease: "easeOut" }}
          >
            {options.map((option, index) => {
              const selected = option.value === value;

              return (
                <li
                  key={option.value}
                  role="option"
                  aria-selected={selected}
                  className={cn(
                    "flex cursor-pointer items-center justify-between gap-3 rounded-lg px-2.5 py-1.5 text-xs transition-colors",
                    index === active ? "bg-white/10 text-white" : "text-white/80",
                    selected && "font-semibold text-primary",
                  )}
                  onPointerEnter={() => setActive(index)}
                  onClick={() => choose(option)}
                >
                  <span className="truncate">{option.label}</span>
                  {selected && <Check className="h-3.5 w-3.5 shrink-0" aria-hidden />}
                </li>
              );
            })}
          </motion.ul>
        )}
      </AnimatePresence>
    </div>
  );
}

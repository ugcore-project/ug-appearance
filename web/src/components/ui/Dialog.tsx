/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// An animated confirmation dialog. While open it owns Escape, so the editor does not close behind it.

import { useEffect, useId } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { Button } from "@/components/ui/Button";

interface ConfirmDialogProps {
  open: boolean;
  title: string;
  hint?: string;
  confirmLabel: string;
  cancelLabel: string;
  destructive?: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}

export function ConfirmDialog({ open, title, hint, confirmLabel, cancelLabel, destructive = false, onConfirm, onCancel }: ConfirmDialogProps) {
  const titleId = useId();

  useEffect(() => {
    if (!open) {
      return undefined;
    }

    // Capture runs before the editor's window listener, and stopping here keeps it from seeing the key.
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.stopPropagation();
        onCancel();
      }
    };

    window.addEventListener("keydown", onKey, true);

    return () => window.removeEventListener("keydown", onKey, true);
  }, [open, onCancel]);

  return (
    <AnimatePresence>
      {open && (
        <motion.div
          key="backdrop"
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-[2px]"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.15 }}
          onPointerDown={(event) => {
            if (event.target === event.currentTarget) {
              onCancel();
            }
          }}
        >
          <motion.div
            role="dialog"
            aria-modal="true"
            aria-labelledby={titleId}
            className="w-80 space-y-4 rounded-2xl border border-white/10 bg-popover/95 p-5 text-popover-foreground shadow-2xl"
            initial={{ opacity: 0, scale: 0.92, y: 12 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 6 }}
            transition={{ type: "spring", stiffness: 420, damping: 30 }}
          >
            <div className="space-y-1">
              <h2 id={titleId} className="break-words text-base font-semibold">
                {title}
              </h2>
              {hint && <p className="text-sm text-muted-foreground">{hint}</p>}
            </div>
            <div className="flex gap-2">
              <Button variant="outline" className="flex-1" autoFocus onClick={onCancel}>
                {cancelLabel}
              </Button>
              <Button variant={destructive ? "destructive" : "default"} className="flex-1" onClick={onConfirm}>
                {confirmLabel}
              </Button>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

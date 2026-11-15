/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// Saved outfits and the uniforms of the player's job or gang. Wearing is free. Saving and replacing store what the
// character wears now, as saved by the server: unpaid changes are not part of it.

import { useState, type ReactNode } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { BadgeCheck, Check, Pencil, RefreshCw, Shirt, Trash2, X } from "lucide-react";
import { cn } from "@/lib/cn";
import { sendOutfitDelete, sendOutfitRename, sendOutfitReplace, sendOutfitSave, sendOutfitWear, sendUniformWear } from "@/lib/nui";
import { label, useEditorStore } from "@/store/editorStore";
import type { Outfit } from "@/types/protocol";
import { Section } from "@/components/ui/Controls";
import { Button } from "@/components/ui/Button";
import { ConfirmDialog } from "@/components/ui/Dialog";

const NAME_MAX = 32;
const INPUT =
  "h-9 w-full min-w-0 rounded-md bg-white/5 px-3 text-sm outline-none placeholder:text-muted-foreground focus:ring-2 focus:ring-ring";

/** Actions that ask first. */
type Pending = { action: "replace" | "delete"; outfit: Outfit } | null;

type Run = (action: () => Promise<boolean>) => void;

function IconButton({ text, danger = false, type = "button", disabled, onClick, children }: {
  text: string;
  danger?: boolean;
  type?: "button" | "submit";
  disabled?: boolean;
  onClick?: () => void;
  children: ReactNode;
}) {
  return (
    <button
      type={type}
      title={text}
      aria-label={text}
      disabled={disabled}
      className={cn(
        "shrink-0 rounded-md p-2 text-white/80 transition-colors disabled:opacity-40",
        danger ? "hover:bg-destructive/20 hover:text-destructive" : "hover:bg-white/10 hover:text-white",
      )}
      onClick={onClick}
    >
      {children}
    </button>
  );
}

function RenameForm({ outfit, busy, run, onDone }: { outfit: Outfit; busy: boolean; run: Run; onDone: () => void }) {
  const [name, setName] = useState(outfit.name);
  const trimmed = name.trim();

  return (
    <form
      className="flex min-w-0 flex-1 items-center gap-1"
      onSubmit={(event) => {
        event.preventDefault();

        if (trimmed && trimmed !== outfit.name) {
          run(() => sendOutfitRename(outfit.id, trimmed));
        }

        onDone();
      }}
    >
      <input
        className={cn(INPUT, "h-8 flex-1")}
        maxLength={NAME_MAX}
        aria-label={label("rename")}
        autoFocus
        value={name}
        onFocus={(event) => event.currentTarget.select()}
        onChange={(event) => setName(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === "Escape") {
            event.stopPropagation();
            onDone();
          }
        }}
      />
      <IconButton text={label("confirm")} type="submit" disabled={busy || trimmed === ""}>
        <Check className="h-4 w-4" />
      </IconButton>
      <IconButton text={label("cancel")} onClick={onDone}>
        <X className="h-4 w-4" />
      </IconButton>
    </form>
  );
}

export function OutfitsPanel() {
  const outfits = useEditorStore((state) => state.outfits);
  const uniforms = useEditorStore((state) => state.session?.uniforms ?? []);
  const busy = useEditorStore((state) => state.busy);
  const [name, setName] = useState("");
  const [renaming, setRenaming] = useState<number | null>(null);
  // Kept while the dialog animates out, so its text does not blank.
  const [pending, setPending] = useState<Pending>(null);
  const [asking, setAsking] = useState(false);

  const ask = (next: NonNullable<Pending>) => {
    setPending(next);
    setAsking(true);
  };

  const run: Run = (action) => {
    useEditorStore.setState({ busy: true });
    void action();
  };

  const confirmPending = () => {
    if (pending && asking) {
      const id = pending.outfit.id;

      run(() => (pending.action === "replace" ? sendOutfitReplace(id) : sendOutfitDelete(id)));
    }

    setAsking(false);
  };

  const replacing = pending?.action === "replace";

  return (
    <div className="space-y-6">
      <Section title={label("outfits")}>
        <form
          className="space-y-2"
          onSubmit={(event) => {
            event.preventDefault();

            const trimmed = name.trim();

            if (trimmed) {
              run(() => sendOutfitSave(trimmed));
              setName("");
            }
          }}
        >
          <input
            className={INPUT}
            maxLength={NAME_MAX}
            placeholder={label("outfitName")}
            aria-label={label("outfitName")}
            value={name}
            onChange={(event) => setName(event.target.value)}
          />
          <Button type="submit" className="w-full" disabled={busy || name.trim() === ""}>
            {label("outfitSave")}
          </Button>
        </form>

        <ul className="space-y-1.5">
          <AnimatePresence initial={false}>
            {outfits.map((outfit) => (
              <motion.li
                key={outfit.id}
                layout
                initial={{ opacity: 0, y: -4 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, x: -12 }}
                transition={{ duration: 0.15 }}
                className="flex min-w-0 items-center gap-1 rounded-md bg-white/5 py-1.5 pl-3 pr-1"
              >
                {renaming === outfit.id ? (
                  <RenameForm outfit={outfit} busy={busy} run={run} onDone={() => setRenaming(null)} />
                ) : (
                  <>
                    <Shirt className="h-4 w-4 shrink-0 text-white/70" aria-hidden />
                    <span className="min-w-0 flex-1 truncate pl-1 text-sm" title={outfit.name}>
                      {outfit.name}
                    </span>
                    <Button variant="outline" className="h-8 shrink-0 px-3" disabled={busy} onClick={() => run(() => sendOutfitWear(outfit.id))}>
                      {label("wear")}
                    </Button>
                    <IconButton text={label("replace")} disabled={busy} onClick={() => ask({ action: "replace", outfit })}>
                      <RefreshCw className="h-4 w-4" />
                    </IconButton>
                    <IconButton text={label("rename")} disabled={busy} onClick={() => setRenaming(outfit.id)}>
                      <Pencil className="h-4 w-4" />
                    </IconButton>
                    <IconButton text={label("delete")} danger disabled={busy} onClick={() => ask({ action: "delete", outfit })}>
                      <Trash2 className="h-4 w-4" />
                    </IconButton>
                  </>
                )}
              </motion.li>
            ))}
          </AnimatePresence>
        </ul>
        {outfits.length === 0 && <p className="text-sm text-muted-foreground">{label("empty")}</p>}
      </Section>

      {uniforms.length > 0 && (
        <Section title={label("uniforms")}>
          <ul className="space-y-1.5">
            {uniforms.map((uniform, index) => (
              <li key={uniform} className="flex min-w-0 items-center gap-2 rounded-md bg-white/5 px-3 py-2">
                <BadgeCheck className="h-4 w-4 shrink-0 text-primary" aria-hidden />
                <span className="min-w-0 flex-1 truncate text-sm">{uniform}</span>
                <Button variant="outline" className="h-8 shrink-0 px-3" disabled={busy} onClick={() => run(() => sendUniformWear(index + 1))}>
                  {label("wear")}
                </Button>
              </li>
            ))}
          </ul>
        </Section>
      )}

      <ConfirmDialog
        open={asking}
        title={pending ? label(replacing ? "outfitReplaceTitle" : "outfitDeleteTitle", { name: pending.outfit.name }) : ""}
        hint={label(replacing ? "outfitReplaceHint" : "outfitDeleteHint")}
        confirmLabel={label(replacing ? "replace" : "delete")}
        cancelLabel={label("cancel")}
        destructive={!replacing}
        onCancel={() => setAsking(false)}
        onConfirm={confirmPending}
      />
    </div>
  );
}

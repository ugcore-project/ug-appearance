/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// The change list and the total. Lua computes both with the same code the server charges with: the page only shows them.

import { Check, Minus, Receipt } from "lucide-react";
import { money } from "@/lib/format";
import { label, useEditorStore } from "@/store/editorStore";
import { Category, type BillLine } from "@/types/protocol";
import { Button } from "@/components/ui/Button";

const PREFIX: Partial<Record<Category, string>> = {
  [Category.Clothing]: "component",
  [Category.Accessories]: "prop",
  [Category.Skin]: "overlay",
  [Category.FacialHair]: "overlay",
  [Category.Makeup]: "overlay",
  [Category.Features]: "feature",
};

/** `Clothing · Tops`, or only the category when the key has no label of its own. */
function lineLabel(line: BillLine): string {
  const category = label(`category.${line.category}`);
  const prefix = PREFIX[line.category];

  return prefix ? `${category} · ${label(`${prefix}.${line.key}`)}` : category;
}

export function BillCard({ onSave, onCancel }: { onSave: () => void; onCancel: () => void }) {
  const bill = useEditorStore((state) => state.bill);
  const free = useEditorStore((state) => state.session?.free ?? true);
  const busy = useEditorStore((state) => state.busy);
  const locale = useEditorStore((state) => state.config.locale);
  const paid = !free && bill.total > 0;

  return (
    <section className="w-80 overflow-hidden rounded-2xl bg-black/70 backdrop-blur-md">
      <header className="flex items-center gap-2 border-b border-white/10 px-4 py-3">
        <Receipt className="h-4 w-4 text-muted-foreground" aria-hidden />
        <h2 className="flex-1 text-sm font-semibold">{label("changes")}</h2>
        <span className="rounded-full bg-white/10 px-2 py-0.5 text-xs tabular-nums">{bill.lines.length}</span>
      </header>

      <ul className="max-h-56 space-y-1 overflow-y-auto px-4 py-3 text-sm">
        {bill.lines.map((line) => (
          <li key={`${line.category}:${line.key}`} className="ug-enter flex items-center gap-2">
            {line.removed ? <Minus className="h-3 w-3 text-destructive" aria-hidden /> : <Check className="h-3 w-3 text-success" aria-hidden />}
            <span className="flex-1 truncate text-foreground/90">
              {lineLabel(line)}
              {line.removed && <span className="ml-1 text-muted-foreground">({label("removed")})</span>}
            </span>
            {!free && <span className="tabular-nums text-muted-foreground">{line.price > 0 ? money(line.price, locale) : label("free")}</span>}
          </li>
        ))}
        {bill.lines.length === 0 && <li className="py-2 text-center text-muted-foreground">{label("noChanges")}</li>}
      </ul>

      <footer className="space-y-3 border-t border-white/10 px-4 py-3">
        {!free && (
          <div className="flex items-baseline justify-between">
            <span className="text-xs uppercase tracking-wide text-muted-foreground">{label("total")}</span>
            <span key={bill.total} className="ug-pop text-xl font-bold tabular-nums">
              {bill.total > 0 ? money(bill.total, locale) : label("free")}
            </span>
          </div>
        )}
        <div className="flex gap-2">
          <Button variant="outline" className="flex-1" disabled={busy} onClick={onCancel}>
            {label("cancel")}
          </Button>
          <Button className="flex-1" disabled={busy} onClick={onSave}>
            {paid ? `${label("pay")} ${money(bill.total, locale)}` : label("save")}
          </Button>
        </div>
      </footer>
    </section>
  );
}

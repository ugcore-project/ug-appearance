/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { readFileSync } from "node:fs";
import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { MotionGlobalConfig } from "framer-motion";
import { beforeEach, describe, expect, it, vi } from "vitest";
import App from "@/App";
import { flattenLabels } from "@/lib/labels";
import {
  DEFAULT_CONTROLS,
  DEFAULT_LABELS,
  DEFAULT_LAYOUT,
  handleMessage,
  HISTORY_LIMIT,
  readControls,
  readFeatures,
  readLayout,
  readLights,
  useEditorStore,
} from "@/store/editorStore";
import { toneShades } from "@/lib/theme";
import { Category, Light, NuiAction, StoreKind, type Appearance, type OpenPayload } from "@/types/protocol";

MotionGlobalConfig.skipAnimations = true;

const nui = vi.hoisted(() => ({
  isEnvBrowser: () => false,
  sendReady: vi.fn(),
  sendChange: vi.fn(),
  sendRotate: vi.fn(),
  sendZoom: vi.fn(),
  sendCamera: vi.fn(),
  sendPose: vi.fn(),
  sendLight: vi.fn(),
  sendCompare: vi.fn(),
  sendSave: vi.fn(),
  sendCancel: vi.fn(),
  sendOutfitSave: vi.fn(),
  sendOutfitWear: vi.fn(),
  sendOutfitDelete: vi.fn(),
  sendOutfitReplace: vi.fn(),
  sendOutfitRename: vi.fn(),
  sendUniformWear: vi.fn(),
}));

vi.mock("@/lib/nui", () => nui);

/** The labels Lua sends: the `page` group of locales/en.json. */
const LABELS = flattenLabels((JSON.parse(readFileSync("../locales/en.json", "utf8")) as { page: Record<string, unknown> }).page);

const APPEARANCE: Appearance = {
  model: "mp_m_freemode_01",
  headBlend: { shapeFirst: 0, shapeSecond: 0, shapeThird: 0, skinFirst: 0, skinSecond: 0, skinThird: 0, shapeMix: 0.5, skinMix: 0.5, thirdMix: 0 },
  faceFeatures: {},
  headOverlays: {},
  hair: { style: 0, texture: 0, color: 0, highlight: 0 },
  eyeColor: 0,
  components: { top: { drawable: 0, texture: 0 } },
  props: { hat: { drawable: -1, texture: 0 } },
  tattoos: [],
};

function payload(change: Partial<OpenPayload> = {}): OpenPayload {
  return {
    kind: StoreKind.Clothing,
    categories: [Category.Clothing, Category.Accessories],
    free: false,
    appearance: APPEARANCE,
    catalog: { freemode: true, components: { top: [2, 1, 3] }, props: { hat: [1, 1] }, overlays: {}, tattoos: [] },
    models: ["mp_m_freemode_01"],
    poses: [],
    outfits: [{ id: 7, name: "Night out" }],
    uniforms: [],
    maxTattoos: 2,
    ...change,
  };
}

function open(change?: Partial<OpenPayload>) {
  act(() => handleMessage({ action: NuiAction.Open, payload: payload(change) }));
}

beforeEach(() => {
  for (const fn of Object.values(nui)) {
    if (typeof fn === "function" && "mockReset" in fn) {
      fn.mockReset();
    }
  }

  act(() => handleMessage({ action: NuiAction.Close }));
  configure();
});

/** A label Lua sends. */
const L = (key: string) => LABELS[key] ?? key;

/** What Lua sends first, with owner values on top. */
function configure(owner: Record<string, unknown> = {}) {
  act(() => handleMessage({ action: NuiAction.Config, payload: { labels: { ...DEFAULT_LABELS, ...LABELS }, locale: "en", ...owner } }));
}

describe("owner config", () => {
  const ALL_OFF = { undo: false, randomize: false, compare: false, favorites: false, search: false, cameras: false, rotate: false, zoom: false, poses: false };

  it("places and sizes the panel, moves the toolbar and drops the hint", () => {
    configure({ layout: { side: "right", width: 30, opacity: 0.3, blur: false, toolbar: "bottom", hint: false } });
    render(<App />);
    open();

    const panel = document.querySelector<HTMLElement>("[data-panel]")!;

    expect(document.querySelector("[data-side]")?.getAttribute("data-side")).toBe("right");
    expect(panel.style.width).toBe("30rem");
    expect(panel.style.backgroundColor).toContain("0.3");
    expect(panel.className).not.toContain("backdrop-blur");
    expect(document.querySelector("[data-toolbar]")?.getAttribute("data-toolbar")).toBe("bottom");
    expect(document.querySelector("[data-hint]")).toBeNull();
  });

  it("hides the tools the owner turned off, and their keys, drag and wheel do nothing", () => {
    configure({ features: ALL_OFF });
    render(<App />);
    open({ poses: [{ id: "idle", label: "Idle" }, { id: "handsUp", label: "Hands up" }] });

    for (const name of ["Undo", "Randomize", L("compare"), L("camera.face"), "Pose", "Favorites"]) {
      expect(screen.queryByRole("button", { name })).toBeNull();
    }

    expect(screen.queryByRole("textbox", { name: "Search" })).toBeNull();

    const stage = screen.getByTestId("stage");

    fireEvent.keyDown(window, { key: "q" });
    fireEvent.pointerDown(stage, { clientX: 0, pointerId: 1 });
    fireEvent.pointerMove(stage, { clientX: 50, pointerId: 1 });
    fireEvent.wheel(stage, { deltaY: 100 });
    expect(nui.sendRotate).not.toHaveBeenCalled();
    expect(nui.sendZoom).not.toHaveBeenCalled();
  });

  it("uses the owner's control speeds", () => {
    configure({ controls: { keyRotate: 30, zoomSpeed: 0.01, dragSpeed: 1, rotateStep: 90 } });
    render(<App />);
    open();

    expect(screen.getByRole("textbox", { name: "Search" })).toBeDefined();
    expect(screen.getAllByRole("button", { name: "Favorites" }).length).toBeGreaterThan(0);

    fireEvent.keyDown(window, { key: "q" });
    expect(nui.sendRotate).toHaveBeenLastCalledWith(-30);

    fireEvent.wheel(screen.getByTestId("stage"), { deltaY: 100 });
    expect(nui.sendZoom).toHaveBeenLastCalledWith(1);

    fireEvent.click(screen.getByRole("button", { name: `${L("view")} +` }));
    expect(nui.sendRotate).toHaveBeenLastCalledWith(90);
  });

  it("shows the owner's lights in order, the first one on", () => {
    configure({ lights: ["night", "studio"] });
    render(<App />);
    open();

    const night = screen.getByRole("button", { name: L("light.night") });
    const studio = screen.getByRole("button", { name: L("light.studio") });

    expect(night.compareDocumentPosition(studio) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
    expect(screen.queryByRole("button", { name: L("light.day") })).toBeNull();
    expect(useEditorStore.getState().light).toBe(Light.Night);
  });

  it("stills the page when animations are off", () => {
    configure({ layout: { animations: false } });
    render(<App />);
    open();

    expect(document.querySelector("[data-side]")?.className).toContain("ug-still");
  });

  it("recolors a tab and derives its shades", () => {
    configure({ theme: { mode: "dark", colors: { facialHair: "200 80% 55%", mixFirst: "10 50% 50%" }, radius: "", font: "", scale: 1 } });

    const style = document.documentElement.style;

    expect(style.getPropertyValue("--ug-tone-facial-hair")).toBe("200 80% 55%");
    expect(style.getPropertyValue("--ug-tone-facial-hair-light")).toBe("200 80% 73%");
    expect(style.getPropertyValue("--ug-tone-facial-hair-fg")).toBe("0 0% 100%");
    expect(style.getPropertyValue("--ug-tone-mix-first")).toBe("10 50% 50%");
    expect(style.getPropertyValue("--ug-tone-clothing")).toBe("");
    expect(toneShades("50 90% 80%")).toEqual({ light: "50 90% 88%", foreground: "0 0% 10%" });
  });

  it("reads every owner field on its own", () => {
    expect(readLayout(null)).toEqual(DEFAULT_LAYOUT);
    expect(readLayout({ side: "up", width: 99, toolbar: "bottom", hint: "no" })).toEqual({ ...DEFAULT_LAYOUT, width: 40, toolbar: "bottom" });
    expect(readFeatures({ zoom: false, undo: "no" }).zoom).toBe(false);
    expect(readFeatures({ zoom: false, undo: "no" }).undo).toBe(true);
    expect(readControls({ keyRotate: -5 })).toEqual({ ...DEFAULT_CONTROLS, keyRotate: 0 });
    expect(readLights(["day", "day", "disco"])).toEqual(["day"]);
    expect(readLights([])).toEqual(Object.values(Light));
  });
});

describe("editor", () => {
  it("renders nothing until a store opens", () => {
    render(<App />);

    expect(nui.sendReady).toHaveBeenCalledOnce();
    expect(screen.queryByText("Hold to compare")).toBeNull();
  });

  it("shows only the store categories, and outfits where clothes can be saved", () => {
    render(<App />);
    open();

    expect(screen.getByRole("button", { name: "Clothing" })).toBeDefined();
    expect(screen.getByRole("button", { name: "Accessories" })).toBeDefined();
    expect(screen.queryByRole("button", { name: "Tattoos" })).toBeNull();
    expect(screen.getByRole("button", { name: "Outfits" })).toBeDefined();

    open({ kind: StoreKind.Barber, categories: [Category.Hair] });
    expect(screen.queryByRole("button", { name: "Outfits" })).toBeNull();
  });

  it("records edits, undoes and redoes them, and sends each one", () => {
    render(<App />);
    open();

    fireEvent.click(screen.getByRole("button", { name: "Style 2" }));
    expect(useEditorStore.getState().appearance?.components.top).toEqual({ drawable: 1, texture: 0 });
    expect(nui.sendChange).toHaveBeenLastCalledWith(expect.objectContaining({ components: { top: { drawable: 1, texture: 0 } } }));

    fireEvent.keyDown(window, { key: "z", ctrlKey: true });
    expect(useEditorStore.getState().appearance?.components.top).toEqual({ drawable: 0, texture: 0 });

    fireEvent.keyDown(window, { key: "y", ctrlKey: true });
    expect(useEditorStore.getState().appearance?.components.top).toEqual({ drawable: 1, texture: 0 });
  });

  it("keeps a bounded history", () => {
    render(<App />);
    open();

    for (let index = 0; index < HISTORY_LIMIT + 10; index++) {
      fireEvent.click(screen.getByRole("button", { name: `Style ${(index % 3) + 1}` }));
    }

    expect(useEditorStore.getState().past).toHaveLength(HISTORY_LIMIT);
  });

  it("shows the bill from Lua and pays with the total", () => {
    render(<App />);
    open();
    act(() =>
      handleMessage({ action: NuiAction.Bill, payload: { total: 1500, lines: [{ category: Category.Clothing, key: "top", price: 1500 }] } }),
    );

    const pay = screen.getByRole("button", { name: "Pay $1,500" });

    fireEvent.click(pay);
    fireEvent.click(pay);
    expect(nui.sendSave).toHaveBeenCalledOnce();

    act(() => handleMessage({ action: NuiAction.Result, payload: { kind: "save", ok: false, message: "You cannot afford this." } }));
    expect(screen.getByRole("status").textContent).toBe("You cannot afford this.");
    expect(useEditorStore.getState().busy).toBe(false);
  });

  it("asks before leaving with changes, and leaves at once without", () => {
    render(<App />);
    open();

    fireEvent.keyDown(window, { key: "Escape" });
    expect(nui.sendCancel).toHaveBeenCalledOnce();

    act(() => handleMessage({ action: NuiAction.Bill, payload: { total: 60, lines: [{ category: Category.Clothing, key: "top", price: 60 }] } }));
    fireEvent.click(screen.getByRole("button", { name: "Cancel" }));
    expect(screen.getByRole("dialog")).toBeDefined();
    expect(nui.sendCancel).toHaveBeenCalledOnce();

    fireEvent.click(screen.getByRole("button", { name: "Leave" }));
    expect(nui.sendCancel).toHaveBeenCalledTimes(2);
  });

  it("does not turn the ped while typing an outfit name", () => {
    render(<App />);
    open();
    fireEvent.click(screen.getByRole("button", { name: "Outfits" }));

    const input = screen.getByRole("textbox");

    fireEvent.keyDown(input, { key: "q" });
    expect(nui.sendRotate).not.toHaveBeenCalled();

    fireEvent.keyDown(window, { key: "q" });
    expect(nui.sendRotate).toHaveBeenCalledWith(-15);
  });

  it("limits tattoos to the store maximum", () => {
    render(<App />);
    open({
      kind: StoreKind.Tattoo,
      categories: [Category.Tattoos],
      catalog: {
        freemode: true,
        components: {},
        props: {},
        overlays: {},
        tattoos: [1, 2, 3].map((overlay) => ({ collection: 9, overlay, zone: 0 })),
      },
    });

    fireEvent.click(screen.getByRole("button", { name: "Add 1" }));
    fireEvent.click(screen.getByRole("button", { name: "Add 2" }));

    expect(useEditorStore.getState().appearance?.tattoos).toHaveLength(2);
    expect((screen.getByRole("button", { name: "Add 3" }) as HTMLButtonElement).disabled).toBe(true);

    fireEvent.click(screen.getByRole("button", { name: "Remove 1" }));
    expect(useEditorStore.getState().appearance?.tattoos).toEqual([{ collection: 9, overlay: 2 }]);
  });

  it("asks before replacing or deleting an outfit, and Escape only closes the question", async () => {
    render(<App />);
    open();
    fireEvent.click(screen.getByRole("button", { name: "Outfits" }));

    fireEvent.click(screen.getByRole("button", { name: "Replace" }));
    expect(screen.getByRole("dialog").textContent).toContain('Replace "Night out"?');
    expect(nui.sendOutfitReplace).not.toHaveBeenCalled();

    fireEvent.keyDown(window, { key: "Escape" });
    expect(nui.sendCancel).not.toHaveBeenCalled();
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());

    fireEvent.click(screen.getByRole("button", { name: "Replace" }));
    fireEvent.click(screen.getAllByRole("button", { name: "Replace" }).at(-1)!);
    expect(nui.sendOutfitReplace).toHaveBeenCalledWith(7);
    await waitFor(() => expect(screen.queryByRole("dialog")).toBeNull());

    act(() => useEditorStore.setState({ busy: false }));
    fireEvent.click(screen.getByRole("button", { name: "Delete" }));
    fireEvent.click(screen.getAllByRole("button", { name: "Delete" }).at(-1)!);
    expect(nui.sendOutfitDelete).toHaveBeenCalledWith(7);
  });

  it("renames an outfit inline", () => {
    render(<App />);
    open();
    fireEvent.click(screen.getByRole("button", { name: "Outfits" }));
    fireEvent.click(screen.getByRole("button", { name: "Rename" }));

    const input = screen.getByRole("textbox", { name: "Rename" });

    fireEvent.change(input, { target: { value: "  Work  " } });
    fireEvent.submit(input.closest("form")!);
    expect(nui.sendOutfitRename).toHaveBeenCalledWith(7, "Work");
    expect(screen.queryByRole("textbox", { name: "Rename" })).toBeNull();
  });

  it("takes a typed number in steppers and drops numbers out of range", () => {
    render(<App />);
    open({ kind: StoreKind.Surgeon, categories: [Category.Heritage] });

    const mother = screen.getByRole("textbox", { name: "Mother" });

    fireEvent.focus(mother);
    fireEvent.change(mother, { target: { value: "40" } });
    fireEvent.blur(mother);
    expect(useEditorStore.getState().appearance?.headBlend.shapeFirst).toBe(39);

    fireEvent.focus(mother);
    fireEvent.change(mother, { target: { value: "99" } });
    fireEvent.blur(mother);
    expect(useEditorStore.getState().appearance?.headBlend.shapeFirst).toBe(39);
    expect((mother as HTMLInputElement).value).toBe("40");
  });

  it("chooses a pose from the dropdown", () => {
    render(<App />);
    open({ poses: [{ id: "idle", label: "Idle" }, { id: "handsUp", label: "Hands up" }] });

    fireEvent.click(screen.getByRole("button", { name: "Pose" }));
    fireEvent.click(screen.getByRole("option", { name: "Hands up" }));
    expect(nui.sendPose).toHaveBeenCalledWith("handsUp");

    fireEvent.click(screen.getByRole("button", { name: "Pose" }));
    fireEvent.keyDown(screen.getByRole("listbox"), { key: "Escape" });
    expect(nui.sendCancel).not.toHaveBeenCalled();
  });
});

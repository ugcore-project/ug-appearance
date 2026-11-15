/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

// Camera, pose, light and history controls, floating over the game.

import { useState, type ReactNode } from "react";
import { Dices, Eye, Lightbulb, Moon, Redo2, RotateCcw, RotateCw, Sun, Trees, Undo2 } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/cn";
import { randomize } from "@/lib/appearance";
import { sendCamera, sendCompare, sendLight, sendPose, sendRotate } from "@/lib/nui";
import { edit, label, redo, undo, useEditorStore } from "@/store/editorStore";
import { Camera, Category, Feature, Light } from "@/types/protocol";
import { Select } from "@/components/ui/Select";

const CAMERAS = Object.values(Camera);
const LIGHT_ICONS: Record<Light, LucideIcon> = {
  [Light.Natural]: Trees,
  [Light.Studio]: Lightbulb,
  [Light.Day]: Sun,
  [Light.Night]: Moon,
};

function Group({ children }: { children: ReactNode }) {
  return <div className="flex items-center gap-0.5 rounded-xl bg-black/60 p-1 backdrop-blur-md">{children}</div>;
}

function Tool({ text, active, disabled, onClick, children, ...rest }: {
  text: string;
  active?: boolean;
  disabled?: boolean;
  onClick?: () => void;
  children: ReactNode;
  onPointerDown?: () => void;
  onPointerUp?: () => void;
  onPointerLeave?: () => void;
}) {
  return (
    <button
      type="button"
      title={text}
      aria-label={text}
      aria-pressed={active}
      disabled={disabled}
      className={cn(
        "flex h-9 min-w-9 items-center justify-center rounded-lg px-2 text-xs transition-colors disabled:opacity-30",
        active ? "bg-white/15 text-white" : "text-white/80 hover:bg-white/10 hover:text-white",
      )}
      onClick={onClick}
      {...rest}
    >
      {children}
    </button>
  );
}

export function Toolbar() {
  const camera = useEditorStore((state) => state.camera);
  const light = useEditorStore((state) => state.light);
  const poses = useEditorStore((state) => state.session?.poses ?? []);
  const canUndo = useEditorStore((state) => state.past.length > 0);
  const canRedo = useEditorStore((state) => state.future.length > 0);
  const category = useEditorStore((state) => state.category);
  const showOutfits = useEditorStore((state) => state.showOutfits);
  const { features, controls, lights } = useEditorStore((state) => state.config);
  const [pose, setPose] = useState(poses[0]?.id ?? "");
  const [comparing, setComparing] = useState(false);

  const compare = (active: boolean) => {
    if (active !== comparing) {
      setComparing(active);
      void sendCompare(active);
    }
  };

  const shuffle = () => {
    const { appearance, catalog } = useEditorStore.getState();

    if (appearance && catalog && category && category !== Category.Model && category !== Category.Tattoos) {
      edit(randomize(appearance, category, catalog));
    }
  };

  return (
    <div className="flex flex-wrap items-center justify-center gap-2">
      {(features[Feature.Undo] || features[Feature.Randomize] || features[Feature.Compare]) && (
        <Group>
          {features[Feature.Undo] && (
            <>
              <Tool text={label("undo")} disabled={!canUndo} onClick={undo}>
                <Undo2 className="h-4 w-4" />
              </Tool>
              <Tool text={label("redo")} disabled={!canRedo} onClick={redo}>
                <Redo2 className="h-4 w-4" />
              </Tool>
            </>
          )}
          {features[Feature.Randomize] && (
            <Tool
              text={label("randomize")}
              disabled={showOutfits || !category || category === Category.Model || category === Category.Tattoos}
              onClick={shuffle}
            >
              <Dices className="h-4 w-4" />
            </Tool>
          )}
          {features[Feature.Compare] && (
            <Tool
              text={label("compare")}
              active={comparing}
              onPointerDown={() => compare(true)}
              onPointerUp={() => compare(false)}
              onPointerLeave={() => compare(false)}
            >
              <Eye className="h-4 w-4" />
            </Tool>
          )}
        </Group>
      )}

      {(features[Feature.Rotate] || features[Feature.Cameras]) && (
      <Group>
        {features[Feature.Rotate] && (
        <Tool text={`${label("view")} -`} onClick={() => sendRotate(-controls.rotateStep)}>
          <RotateCcw className="h-4 w-4" />
        </Tool>
        )}
        {features[Feature.Cameras] && CAMERAS.map((preset) => (
          <Tool
            key={preset}
            text={label(`camera.${preset}`)}
            active={camera === preset}
            onClick={() => {
              useEditorStore.setState({ camera: preset });
              void sendCamera(preset);
            }}
          >
            {label(`camera.${preset}`)}
          </Tool>
        ))}
        {features[Feature.Rotate] && (
        <Tool text={`${label("view")} +`} onClick={() => sendRotate(controls.rotateStep)}>
          <RotateCw className="h-4 w-4" />
        </Tool>
        )}
      </Group>
      )}

      {lights.length > 1 && (
        <Group>
          {lights.map((key) => {
            const Icon = LIGHT_ICONS[key];

            return (
              <Tool
                key={key}
                text={label(`light.${key}`)}
                active={light === key}
                onClick={() => {
                  useEditorStore.setState({ light: key });
                  void sendLight(key);
                }}
              >
                <Icon className="h-4 w-4" />
              </Tool>
            );
          })}
        </Group>
      )}

      {features[Feature.Poses] && poses.length > 1 && (
        <Group>
          <Select
            label={label("pose")}
            value={pose}
            options={poses.map((item) => ({ value: item.id, label: item.label }))}
            onChange={(id) => {
              setPose(id);
              void sendPose(id);
            }}
          />
        </Group>
      )}
    </div>
  );
}

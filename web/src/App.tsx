/*

    ug-appearance - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

*/

import { MotionConfig } from "framer-motion";
import { lazy, Suspense, useEffect } from "react";
import { Editor } from "@/components/Editor";
import { isEnvBrowser, sendReady } from "@/lib/nui";
import { installMessages, useEditorStore } from "@/store/editorStore";

// Dev only: removed from production builds.
// Dev and showcase builds only: removed from production builds.
const Preview = import.meta.env.DEV || import.meta.env.MODE === "showcase" ? lazy(() => import("@/dev/Preview")) : null;

export default function App() {
  const animations = useEditorStore((state) => state.config.layout.animations);

  useEffect(() => {
    const uninstall = installMessages();

    void sendReady();

    return uninstall;
  }, []);

  return (
    <MotionConfig reducedMotion={animations ? "user" : "always"}>
      <Editor />
      {Preview && isEnvBrowser() && (
        <Suspense fallback={null}>
          <Preview />
        </Suspense>
      )}
    </MotionConfig>
  );
}

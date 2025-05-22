import React, { useContext } from "react";

import { DEFAULT_INTENT } from "./constants";
import {
  DirectShareContact,
  DonateSendMessageOptions,
  ShareIntent,
  ShareIntentOptions,
} from "./types";
import useShareIntent from "./useShareIntent";

type ShareIntentContextState = {
  isReady: boolean;
  hasShareIntent: boolean;
  shareIntent: ShareIntent;
  donateSendMessage: (options: DonateSendMessageOptions) => Promise<void>;
  publishDirectShareTargets: (
    contacts: DirectShareContact[],
  ) => Promise<boolean>;
  reportShortcutUsed: (shortcutId: string) => void;
  removeShortcut: (shortcutId: string) => void;
  removeAllShortcuts: () => void;
  resetShareIntent: (clearNativeModule?: boolean) => void;
  error: string | null;
};

const ShareIntentContext = React.createContext<ShareIntentContextState>({
  isReady: false,
  hasShareIntent: false,
  shareIntent: DEFAULT_INTENT,
  donateSendMessage: () => Promise.reject(new Error("Not implemented")),
  publishDirectShareTargets: () => Promise.reject(new Error("Not implemented")),
  reportShortcutUsed: () => {},
  removeShortcut: () => {},
  removeAllShortcuts: () => {},
  resetShareIntent: () => {},
  error: null,
});

export const ShareIntentContextConsumer = ShareIntentContext.Consumer;

export function useShareIntentContext() {
  return useContext(ShareIntentContext);
}

export function ShareIntentProvider({
  options,
  children,
}: {
  options?: ShareIntentOptions;
  children: any;
}) {
  const {
    isReady,
    hasShareIntent,
    shareIntent,
    donateSendMessage,
    publishDirectShareTargets,
    reportShortcutUsed,
    removeShortcut,
    removeAllShortcuts,
    resetShareIntent,
    error,
  } = useShareIntent(options);

  return (
    <ShareIntentContext.Provider
      value={{
        isReady,
        hasShareIntent,
        shareIntent,
        donateSendMessage,
        publishDirectShareTargets,
        reportShortcutUsed,
        removeShortcut,
        removeAllShortcuts,
        resetShareIntent,
        error,
      }}
    >
      {children}
    </ShareIntentContext.Provider>
  );
}

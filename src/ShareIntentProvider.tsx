import React, { useContext } from "react";

import { DEFAULT_INTENT } from "./constants";
import {
  DonateSendMessageOptions,
  ShareIntent,
  ShareIntentOptions,
} from "./types";
import { useShareIntent } from "./useShareIntent";

type ShareIntentContextState = {
  isReady: boolean;
  hasShareIntent: boolean;
  shareIntent: ShareIntent;
  donateSendMessage: (options: DonateSendMessageOptions) => void;
  resetShareIntent: (clearNativeModule?: boolean) => void;
  error: string | null;
};

const ShareIntentContext = React.createContext<ShareIntentContextState>({
  isReady: false,
  hasShareIntent: false,
  shareIntent: DEFAULT_INTENT,
  donateSendMessage: () => {},
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
        resetShareIntent,
        error,
      }}
    >
      {children}
    </ShareIntentContext.Provider>
  );
}

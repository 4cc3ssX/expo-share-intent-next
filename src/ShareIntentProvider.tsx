import React, { useContext } from "react";

import {
  DonateSendMessageOptions,
  ShareIntent,
  ShareIntentOptions,
} from "./types";
import useShareIntent, { SHAREINTENT_DEFAULTVALUE } from "./useShareIntent";

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
  shareIntent: SHAREINTENT_DEFAULTVALUE,
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

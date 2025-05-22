import { useLinkingURL } from "expo-linking";
import { useCallback, useEffect, useRef, useState } from "react";
import { AppState, AppStateStatus, Platform } from "react-native";

import { ExpoShareIntent } from "./ExpoShareIntent";
import {
  addShareIntentListener,
  clearShareIntent,
  donateSendMessage,
  getShareIntent,
} from "./ShareIntent";
import { DEFAULT_INTENT, LOG_TAG } from "./constants";
import {
  DonateSendMessageOptions,
  ShareIntent,
  ShareIntentOptions,
} from "./types";
import { getScheme, getShareExtensionKey, parseShareIntent } from "./utils";

export interface UseShareIntentResult {
  isReady: boolean;
  hasShareIntent: boolean;
  shareIntent: ShareIntent;
  donateSendMessage: (options: DonateSendMessageOptions) => void;
  resetShareIntent: (clearNative?: boolean) => void;
  error: string | null;
}

export const useShareIntent = (
  options: ShareIntentOptions = {},
): UseShareIntentResult => {
  const {
    debug = false,
    resetOnBackground = true,
    disabled = Platform.OS === "web",
    onResetShareIntent,
  } = options;

  const url = useLinkingURL();
  const appStateRef = useRef(AppState.currentState);
  const [shareIntent, setShareIntent] = useState<ShareIntent>(DEFAULT_INTENT);
  const [error, setError] = useState<string | null>(null);
  const [isReady, setIsReady] = useState(false);

  const hasIntent = Boolean(
    shareIntent.text || shareIntent.webUrl || shareIntent.files?.length,
  );

  /**
   * Clears the share intent
   */
  const resetIntent = useCallback(
    (clearNative = true) => {
      if (disabled) return;
      setError(null);
      if (clearNative) {
        clearShareIntent(getShareExtensionKey(options));
      }

      if (hasIntent) {
        setShareIntent(DEFAULT_INTENT);
        onResetShareIntent?.();
      }
    },
    [disabled, hasIntent, onResetShareIntent, options],
  );

  /**
   * Requests native module for share intent
   */
  const refreshIntent = useCallback(() => {
    if (disabled) return;
    debug && console.debug(LOG_TAG, "refreshing intent", url);

    const scheme = getScheme(options);
    if (url?.includes(`${scheme}://dataUrl=`)) {
      // iOS universal link
      getShareIntent(url);
    } else if (Platform.OS === "android") {
      getShareIntent("");
    } else {
      debug && console.debug(LOG_TAG, "no intent to fetch");
    }
  }, [disabled, debug, url, options]);

  // Initial mount & URL change
  useEffect(() => {
    if (!disabled) {
      refreshIntent();
    }
  }, [disabled, refreshIntent]);

  // Handle app state changes
  useEffect(() => {
    if (disabled) return;

    const onAppStateChange = (nextState: AppStateStatus) => {
      const prevState = appStateRef.current;
      if (nextState === "active") {
        debug && console.debug(LOG_TAG, "App became active, refreshing intent");
        refreshIntent();
      } else if (
        resetOnBackground &&
        prevState === "active" &&
        (nextState === "inactive" || nextState === "background")
      ) {
        debug &&
          console.debug(LOG_TAG, "App moved to background, resetting intent");
        resetIntent();
      }
      appStateRef.current = nextState;
    };

    const subscription = AppState.addEventListener("change", onAppStateChange);
    return () => subscription.remove();
  }, [disabled, debug, refreshIntent, resetIntent, resetOnBackground]);

  // Native module event listeners
  useEffect(() => {
    if (disabled) {
      debug && console.debug(LOG_TAG, "Share intent is disabled");
      return;
    }

    if (!ExpoShareIntent) {
      debug &&
        console.warn(LOG_TAG, "ExpoShareIntent not available, share disabled");
      return;
    }

    const changeSub = addShareIntentListener("onChange", (event) => {
      debug &&
        console.debug(LOG_TAG, "ShareIntent onChange:", JSON.stringify(event));
      try {
        const intent = parseShareIntent(event.data, options);
        setShareIntent(intent);
      } catch (err) {
        debug && console.error(LOG_TAG, "Error parsing intent", err);
        setError("Failed to parse share intent");
      }
    });

    const errorSub = addShareIntentListener("onError", ({ data }) => {
      debug && console.debug(LOG_TAG, "ShareIntent onError:", data);
      setError(data);
    });

    const donateSub = addShareIntentListener("onDonate", ({ data }) => {
      debug && console.debug(LOG_TAG, "ShareIntent onDonate:", data);
    });

    setIsReady(true);
    return () => {
      changeSub.remove();
      errorSub.remove();
      donateSub.remove();
    };
  }, [disabled, debug, options]);

  return {
    isReady,
    hasShareIntent: hasIntent,
    shareIntent,
    donateSendMessage,
    publishDirectShareTargets,
    reportShortcutUsed,
    removeShortcut,
    removeAllShortcuts,
    resetShareIntent: resetIntent,
    error,
  };
};

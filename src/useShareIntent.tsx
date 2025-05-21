import { useLinkingURL } from "expo-linking";
import { useCallback, useEffect, useRef, useState } from "react";
import { AppState, AppStateStatus, Platform } from "react-native";

import ExpoShareIntentModule from "./ExpoShareIntentModule";
import { DEFAULT_INTENT } from "./constants";
import {
  DonateSendMessageOptions,
  ShareIntent,
  ShareIntentOptions,
} from "./types";
import { getScheme, getShareExtensionKey, parseShareIntent } from "./utils";

const useShareIntent = (options: ShareIntentOptions = {}) => {
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
        ExpoShareIntentModule?.clearShareIntent(getShareExtensionKey(options));
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
    debug && console.debug("useShareIntent: refreshing intent", url);

    const scheme = getScheme(options);
    if (url?.includes(`${scheme}://dataUrl=`)) {
      // iOS universal link
      ExpoShareIntentModule?.getShareIntent(url);
    } else if (Platform.OS === "android") {
      ExpoShareIntentModule?.getShareIntent("");
    } else {
      debug && console.debug("useShareIntent: no intent to fetch");
    }
  }, [disabled, debug, url, options]);

  /**
   * Donate send message for Siri suggestions (iOS)
   */
  const donateSendMessage = useCallback(
    ({ conversationId, name, imageURL, content }: DonateSendMessageOptions) => {
      if (!conversationId || !name) {
        console.error("donateSendMessage requires conversationId and name");
        return;
      }
      if (Platform.OS !== "ios") {
        console.warn("donateSendMessage is only available on iOS");
        return;
      }
      ExpoShareIntentModule?.donateSendMessage(
        conversationId,
        name,
        imageURL,
        content,
      );
    },
    [],
  );

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
        debug && console.debug("App became active, refreshing intent");
        refreshIntent();
      } else if (
        resetOnBackground &&
        prevState === "active" &&
        (nextState === "inactive" || nextState === "background")
      ) {
        debug && console.debug("App moved to background, resetting intent");
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
      debug && console.debug("Share intent is disabled");
      return;
    }
    if (!ExpoShareIntentModule) {
      debug &&
        console.warn("ExpoShareIntentModule not available, share disabled");
      return;
    }

    const changeSub = ExpoShareIntentModule.addListener("onChange", (event) => {
      debug && console.debug("ShareIntent onChange:", JSON.stringify(event));
      try {
        const intent = parseShareIntent(event.data, options);
        setShareIntent(intent);
      } catch (err) {
        debug && console.error("Error parsing intent", err);
        setError("Failed to parse share intent");
      }
    });

    const errorSub = ExpoShareIntentModule.addListener(
      "onError",
      ({ data }) => {
        debug && console.debug("ShareIntent onError:", data);
        setError(data);
      },
    );

    setIsReady(true);
    return () => {
      changeSub.remove();
      errorSub.remove();
    };
  }, [disabled, debug, options]);

  return {
    isReady,
    hasShareIntent: hasIntent,
    shareIntent,
    donateSendMessage,
    resetShareIntent: resetIntent,
    error,
  } as const;
};

export default useShareIntent;

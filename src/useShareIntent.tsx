import { useLinkingURL } from "expo-linking";
import { useCallback, useEffect, useRef, useState } from "react";
import { AppState, Platform } from "react-native";

import ExpoShareIntentModule from "./ExpoShareIntentModule";
import {
  DonateSendMessageOptions,
  ShareIntent,
  ShareIntentOptions,
} from "./ExpoShareIntentModule.types";
import { getScheme, getShareExtensionKey, parseShareIntent } from "./utils";

export const SHAREINTENT_DEFAULTVALUE: ShareIntent = {
  files: null,
  text: null,
  webUrl: null,
  type: null,
};

export const SHAREINTENT_OPTIONS_DEFAULT: ShareIntentOptions = {
  debug: false,
  resetOnBackground: true,
  disabled: Platform.OS === "web",
};

const isValueAvailable = (shareIntent: ShareIntent) =>
  !!(shareIntent?.text || shareIntent?.webUrl || shareIntent?.files);

export default function useShareIntent(
  options: ShareIntentOptions = SHAREINTENT_OPTIONS_DEFAULT,
) {
  const url = useLinkingURL();

  const appState = useRef(AppState.currentState);
  const [shareIntent, setSharedIntent] = useState<ShareIntent>(
    SHAREINTENT_DEFAULTVALUE,
  );
  const [error, setError] = useState<string | null>(null);
  const [isReady, setIsReady] = useState(false);

  const resetShareIntent = (clearNativeModule = true) => {
    if (options.disabled) return;
    setError(null);
    clearNativeModule &&
      ExpoShareIntentModule?.clearShareIntent(getShareExtensionKey(options));
    if (isValueAvailable(shareIntent)) {
      setSharedIntent(SHAREINTENT_DEFAULTVALUE);
      options.onResetShareIntent?.();
    }
  };

  /**
   * Call native module on universal linking url change
   */
  const refreshShareIntent = () => {
    options.debug && console.debug("useShareIntent[refresh]", url);
    if (url?.includes(`${getScheme(options)}://dataUrl=`)) {
      // iOS only
      ExpoShareIntentModule?.getShareIntent(url);
    } else if (Platform.OS === "android") {
      ExpoShareIntentModule?.getShareIntent("");
    } else if (Platform.OS === "ios") {
      options.debug &&
        console.debug("useShareIntent[refresh] not a valid refresh url");
    }
  };

  const donateSendMessage = useCallback((options: DonateSendMessageOptions) => {
    if (!options.conversationIdentifier || !options.name) {
      console.error("useShareIntent[donateSendMessage] missing chatId or name");
      return;
    }

    if (Platform.OS !== "ios") {
      console.warn("useShareIntent[donateSendMessage] only available on iOS");
      return;
    }

    ExpoShareIntentModule?.donateSendMessage(
      options.conversationIdentifier,
      options.name,
      options.imageURL,
      options.content,
    );
  }, []);

  useEffect(() => {
    if (options.disabled) return;
    options.debug &&
      console.debug("useShareIntent[mount]", getScheme(options), options);
    refreshShareIntent();
  }, [url, options.disabled]);

  /**
   * Handle application state (active, background, inactive)
   */
  useEffect(() => {
    if (options.disabled) return;
    const subscription = AppState.addEventListener("change", (nextAppState) => {
      if (nextAppState === "active") {
        options.debug && console.debug("useShareIntent[active] refresh intent");
        refreshShareIntent();
      } else if (
        options.resetOnBackground !== false &&
        appState.current === "active" &&
        ["inactive", "background"].includes(nextAppState)
      ) {
        options.debug &&
          console.debug("useShareIntent[to-background] reset intent");
        resetShareIntent();
      }
      appState.current = nextAppState;
    });
    return () => {
      subscription.remove();
    };
  }, [url, shareIntent, options.disabled]);

  /**
   * Detect Native Module response
   */
  useEffect(() => {
    if (options.disabled) {
      options.debug &&
        console.debug(
          "expo-share-intent-next module is disabled by configuration!",
        );
      return;
    } else if (!ExpoShareIntentModule) {
      options.debug &&
        console.warn(
          "expo-share-intent-next module is disabled: ExpoShareIntentModule not found!",
        );
      return;
    }
    const changeSubscription = ExpoShareIntentModule.addListener(
      "onChange",
      (event) => {
        options.debug &&
          console.debug(
            "useShareIntent[onChange]",
            JSON.stringify(event, null, 2),
          );
        try {
          setSharedIntent(parseShareIntent(event.data, options));
        } catch (e) {
          options.debug && console.error("useShareIntent[onChange]", e);
          setError("Cannot parse share intent value !");
        }
      },
    );
    const errorSubscription = ExpoShareIntentModule.addListener(
      "onError",
      (event) => {
        options.debug && console.debug("useShareIntent[error]", event?.data);
        setError(event?.data);
      },
    );
    setIsReady(true);
    return () => {
      changeSubscription.remove();
      errorSubscription.remove();
    };
  }, [options.disabled]);

  return {
    isReady,
    hasShareIntent: isValueAvailable(shareIntent),
    shareIntent,
    donateSendMessage,
    resetShareIntent,
    error,
  };
}

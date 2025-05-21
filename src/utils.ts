import Constants from "expo-constants";
import { createURL } from "expo-linking";

import {
  AndroidShareIntent,
  IosShareIntent,
  ShareIntent,
  ShareIntentFile,
  ShareIntentOptions,
} from "./types";
import { DEFAULT_INTENT } from "./constants";

/**
 * Determine the custom URI scheme for the app.
 */
export const getScheme = ({ scheme, debug }: ShareIntentOptions = {}) => {
  if (scheme) {
    debug && console.debug("[scheme] from options:", scheme);
    return scheme;
  }

  const configScheme = Constants.expoConfig?.scheme;
  if (configScheme) {
    const selected = Array.isArray(configScheme)
      ? configScheme[0]
      : configScheme;
    debug &&
      console.debug(
        "[scheme] from expoConfig:",
        Array.isArray(configScheme)
          ? `multiple detected (${configScheme.join(",")}), using ${selected}`
          : selected,
      );
    return selected;
  }

  const url = createURL("dataUrl=");
  const match = url.match(/^([^:]+):/);
  const extracted = match?.[1] || null;
  debug && console.debug("[scheme] from linking url:", url, extracted);
  return extracted;
};

/**
 * Key for storing share data in native storage.
 */
export const getShareExtensionKey = (options?: ShareIntentOptions) => {
  const scheme = getScheme(options);
  return `${scheme}ShareKey`;
};

/**
 * Safely parse JSON, returning default on failure.
 */
const safeParse = <T>(value: string, fallback: T | null = null): T | null => {
  try {
    return JSON.parse(value) as T;
  } catch {
    return fallback;
  }
};

/**
 * Convert native share payload into a unified ShareIntent.
 */
export const parseShareIntent = (
  data: string | AndroidShareIntent,
  options: ShareIntentOptions = {},
): ShareIntent => {
  if (!data) return DEFAULT_INTENT;

  const raw: IosShareIntent | AndroidShareIntent | null =
    typeof data === "string" ? safeParse<IosShareIntent>(data) : data;

  if (!raw) return DEFAULT_INTENT;

  // Text or URL share
  if (raw.text) {
    const webUrl =
      raw.text
        .match(/https?:\/\/[^\s]+/gi)
        ?.find((u) => u.startsWith("http")) || null;
    return {
      ...DEFAULT_INTENT,
      conversationIdentifier: raw.conversationIdentifier,
      type: webUrl ? "weburl" : "text",
      text: raw.text,
      webUrl,
      meta: { title: (raw as IosShareIntent).meta?.title },
    };
  }

  // iOS weburls array
  if (
    Array.isArray((raw as IosShareIntent).weburls) &&
    (raw as IosShareIntent).weburls?.length
  ) {
    const weburl = (raw as IosShareIntent).weburls?.[0]!;
    return {
      ...DEFAULT_INTENT,
      conversationIdentifier: raw.conversationIdentifier,
      type: "weburl",
      text: weburl.url,
      webUrl: weburl.url,
      meta: safeParse<Record<string, string>>(weburl.meta, {}),
    };
  }

  // Files or media
  const files = (raw.files || []).filter((f: any) => f.path || f.contentUri);
  const shareFiles: ShareIntentFile[] = files.map((f: any) => ({
    path: f.path || f.contentUri || null,
    mimeType: f.mimeType || null,
    fileName: f.fileName || null,
    width: f.width ? Number(f.width) : null,
    height: f.height ? Number(f.height) : null,
    size: f.fileSize ? Number(f.fileSize) : null,
    duration: f.duration ? Number(f.duration) : null,
  }));

  const isMedia = shareFiles.every(
    (f) => f.mimeType?.startsWith("image/") || f.mimeType?.startsWith("video/"),
  );

  const result: ShareIntent = {
    ...DEFAULT_INTENT,
    conversationIdentifier: raw.conversationIdentifier,
    files: shareFiles.length ? shareFiles : null,
    type: isMedia ? "media" : "file",
  };

  options.debug && console.debug("[parsed]", result);
  return result;
};

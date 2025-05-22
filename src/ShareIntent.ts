import { ExpoShareIntent } from "./ExpoShareIntent";
import { LOG_TAG } from "./constants";
import type { DonateSendMessageOptions, ExpoShareIntentEvents } from "./types";

export async function getShareIntent(url?: string): Promise<string> {
  if (!ExpoShareIntent?.getShareIntent) {
    throw new Error("ExpoShareIntent module is not available");
  }

  return ExpoShareIntent.getShareIntent(url);
}

export async function clearShareIntent(key: string): Promise<void> {
  if (!ExpoShareIntent?.clearShareIntent) {
    throw new Error("ExpoShareIntent module is not available");
  }

  return ExpoShareIntent.clearShareIntent(key);
}

export async function donateSendMessage(
  options: DonateSendMessageOptions,
): Promise<void> {
  if (!ExpoShareIntent?.donateSendMessage) {
    throw new Error("ExpoShareIntent module is not available");
  }

  const { conversationId, name, imageURL, content } = options;
  if (!conversationId || !name) {
    console.error(
      LOG_TAG,
      `donateSendMessage requires both conversationId and name`,
    );
    return;
  }

  return ExpoShareIntent.donateSendMessage(
    conversationId,
    name,
    imageURL,
    content,
  );
}

export function hasShareIntent(key: string): Promise<boolean> {
  if (!ExpoShareIntent?.hasShareIntent) {
    throw new Error("ExpoShareIntent module is not available");
  }

  return ExpoShareIntent.hasShareIntent(key);
}

export function addShareIntentListener<T extends keyof ExpoShareIntentEvents>(
  eventName: T,
  listener: ExpoShareIntentEvents[T],
) {
  if (!ExpoShareIntent) {
    throw new Error("ExpoShareIntent module is not available");
  }

  return ExpoShareIntent.addListener(eventName, listener);
}

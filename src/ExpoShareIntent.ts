import { requireOptionalNativeModule, NativeModule } from "expo-modules-core";

import {
  ExpoShareIntentEvents,
  PublishDirectShareTargetsContact,
} from "./types";

declare class ExpoShareIntentType extends NativeModule<ExpoShareIntentEvents> {
  getShareIntent(url?: string): Promise<string>;
  clearShareIntent(key: string): Promise<void>;
  donateSendMessage(
    conversationId: string,
    name: string,
    imageURL?: string,
    content?: string,
  ): Promise<void>;

  // Android-only methods
  publishDirectShareTargets(
    contacts: PublishDirectShareTargetsContact[],
  ): Promise<boolean>;
  reportShortcutUsed(shortcutId: string): void;
  removeShortcut(shortcutId: string): void;
  removeAllShortcuts(): void;

  hasShareIntent(key: string): Promise<boolean>;
}

export const ExpoShareIntent = requireOptionalNativeModule<ExpoShareIntentType>(
  "ExpoShareIntentModule",
);

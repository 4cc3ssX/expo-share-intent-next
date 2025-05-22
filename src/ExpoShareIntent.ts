import { requireOptionalNativeModule, NativeModule } from "expo-modules-core";

import { ExpoShareIntentEvents } from "./types";

declare class ExpoShareIntentType extends NativeModule<ExpoShareIntentEvents> {
  getShareIntent(url?: string): Promise<string>;
  clearShareIntent(key: string): Promise<void>;
  donateSendMessage(
    conversationId: string,
    name: string,
    imageURL?: string,
    content?: string,
  ): Promise<void>;
  hasShareIntent(key: string): Promise<boolean>;
}

export const ExpoShareIntent = requireOptionalNativeModule<ExpoShareIntentType>(
  "ExpoShareIntentModule",
);

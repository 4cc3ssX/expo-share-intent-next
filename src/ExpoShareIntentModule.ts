import { requireOptionalNativeModule, NativeModule } from "expo-modules-core";

import {
  ChangeEventPayload,
  DonateEventPayload,
  ErrorEventPayload,
  StateEventPayload,
} from "./ExpoShareIntentModule.types";

type ExpoShareIntentModuleEvents = {
  onError: (event: ErrorEventPayload) => void;
  onChange: (event: ChangeEventPayload) => void;
  onStateChange: (event: StateEventPayload) => void;
  onDonate: (event: DonateEventPayload) => void;
};

declare class ExpoShareIntentModuleType extends NativeModule<ExpoShareIntentModuleEvents> {
  getShareIntent(url: string): string;
  clearShareIntent(key: string): Promise<void>;
  donateSendMessage(
    conversationIdentifier: string,
    name: string,
    imageURL?: string,
    content?: string,
  ): Promise<void>;
  hasShareIntent(key: string): boolean;
}

// Import the native module. it will be resolved on native platforms to ExpoShareIntentModule.ts
// It loads the native module object from the JSI or falls back to
// the bridge module (from NativeModulesProxy) if the remote debugger is on.
const ExpoShareIntentModule =
  requireOptionalNativeModule<ExpoShareIntentModuleType>(
    "ExpoShareIntentModule",
  );
export default ExpoShareIntentModule;

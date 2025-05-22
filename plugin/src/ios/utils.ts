import { Parameters } from "../types";
import { shareExtensionName } from "./constants";

export const getShareExtensionName = (parameters?: Parameters) => {
  if (!parameters?.iosShareExtensionName) return shareExtensionName;
  return parameters.iosShareExtensionName.replace(/[^a-zA-Z0-9]/g, "");
};

export const getAppGroup = (identifier: string, parameters: Parameters) => {
  return parameters.iosAppGroupIdentifier || `group.${identifier}`;
};

export const getShareExtensionBundledIdentifier = (
  appIdentifier: string,
  parameters: Parameters,
) => {
  return (
    parameters.iosShareExtensionBundleIdentifier ||
    `${appIdentifier}.share-extension`
  );
};

export const getUserActivityTypes = (userActivityTypes: string[]) => {
  if (!userActivityTypes.includes("INSendMessageIntent")) {
    userActivityTypes.push("INSendMessageIntent");
  }

  return userActivityTypes;
};

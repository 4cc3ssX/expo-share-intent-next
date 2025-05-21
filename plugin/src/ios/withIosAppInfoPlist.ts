import { ConfigPlugin, withInfoPlist } from "@expo/config-plugins";

import { getAppGroup, getUserActivityTypes } from "./utils";
import { Parameters } from "../types";

export const withIosAppInfoPlist: ConfigPlugin<Parameters> = (
  config,
  parameters,
) => {
  return withInfoPlist(config, (config) => {
    const appIdentifier = config.ios?.bundleIdentifier!;
    config.modResults["AppGroupIdentifier"] = getAppGroup(
      appIdentifier,
      parameters,
    );
    const userActivityTypes = (config.modResults["NSUserActivityTypes"] ??
      []) as string[];
    config.modResults["NSUserActivityTypes"] =
      getUserActivityTypes(userActivityTypes);
    return config;
  });
};

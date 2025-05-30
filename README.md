# Expo Share Intent 🚀

![npm](https://img.shields.io/npm/v/expo-share-intent-next.svg)
![License](https://img.shields.io/npm/l/expo-share-intent-next.svg)

A simple high-performance native module for handling share intents in Expo (React Native) apps. Share **URLs, text, images, videos and files** to your **iOS** and **Android** apps with a consistent behavior across platforms.

| iOS                                                                                                                                                     | Android                                                                                                                   |
| ------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| ![Simulator Screen Recording - iPhone 15 Pro](https://github.com/user-attachments/assets/b98d1ec1-8ad3-410f-b09b-14b4dce52260) | ![Simulator Android](https://github.com/user-attachments/assets/d2c38b8f-6ec1-4c62-b7b8-dc13aeea8c93) |

## Compatibility

| Expo       | Compatible Version |
| ---------- | ------------------ |
| **SDK 53** | 4.0+               |
| **SDK 52** | 3.0+               |
| **SDK 51** | 2.0+               |
| **SDK 50** | 1.0+               |
| **SDK 49** | 0.2+               |

> iOS privacy manifest is available since v1.4.1

- [Usage](#usage)
  - [Configure Content Types](#customize-content-types-in-appjson)
  - [Share Intent content](#share-intent-content)
  - [Expo Router](#expo-router)
  - [React Navigation](#react-navigation)
  - [iOS Custom View](#ios-custom-view-)

## Installation

**Install npm package**

```bash
yarn add expo-share-intent-next
# or
npm install expo-share-intent-next
```

**Requirement: `patch-package`**

For the moment this package need a post-install script

- copy the [xcode patch](https://github.com/eatmatch/expo-share-intent-next/blob/main/example/basic/patches/xcode%2B3.0.1.patch) in you `patches` project directory (like example)
- add post-install script to `package.json`

```json
  "scripts": {
    ...
    "postinstall": "patch-package"
  },
```

- add `patch-package` for auto patching

```bash
yarn add patch-package
```

> More info in [#13](https://github.com/eatmatch/expo-share-intent-next/issues/13) and [FAQ](https://github.com/eatmatch/expo-share-intent-next/edit/main/README.md#config-sync-failed)

**Requirement: `expo-linking`**

Since Expo52, you also need to install `expo-linking` in your app :

```
expo install expo-linking
```

**Into your `app.json`:**

- add expo plugin

```json
  "plugins": [
      "expo-share-intent-next"
  ],
```

> by default only text and url sharing is activated

- configure a custom URL scheme

```json
  "scheme": "my-app"
```

> More info here : [Linking to your app](https://docs.expo.dev/guides/linking/#linking-to-your-app)

**Run your app in dev-client**

```
expo prebuild --no-install --clean
expo run:ios
expo run:android
```

> We cannot use expo go with this package, more info [here](https://github.com/eatmatch/expo-share-intent-next?tab=readme-ov-file#expo-go-)

## Usage

#### Use the hook in your App

Make sure to use the hook in your main `App.tsx` component before any other Provider :

```ts
import { useShareIntent } from "expo-share-intent-next";

const { hasShareIntent, shareIntent, resetShareIntent, error } =
  useShareIntent();
```

See [App.tsx ](https://github.com/eatmatch/expo-share-intent-next/blob/main/example/basic/App.tsx) for more details

#### Use the Provider in your App

When dealing with multiple screens and providers your may use `ShareIntentProvider` and it's specific hook `useShareIntentContext`. Must be in your top component (`App.tsx`) before any other Provider :

```tsx
import { ShareIntentProvider, useShareIntentContext } from "expo-share-intent-next";


const Home = () => {
  const { hasShareIntent, shareIntent, resetShareIntent, error } = useShareIntentContext();
  return ...
}

export default const App = () => {
  return (
    <ShareIntentProvider>
      <ThirdPartyExtraProvider>
        <Home />
      </ThirdPartyExtraProvider>
    </ShareIntentProvider>
  )
}

```

#### Share intent content

```ts
const { shareIntent } = useShareIntent();
```

| attribute                | description                                                                                                                                          | example                                                                                                                                                                                                                                                                                                  |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `shareIntent.text`       | raw text from text/weburl (ios) and text/\* (android)                                                                                                | "`some text`", "`http://example.com`", "`Hey, Click on my link : http://example.com/nickname`"                                                                                                                                                                                                           |
| `shareIntent.webUrl`     | link extracted from raw text                                                                                                                         | `null`, "`http://example.com`", "`http://example.com/nickname`"                                                                                                                                                                                                                                          |
| `shareIntent.files`      | image / movies / audio / files with name, path, mimetype, size (in octets) and image/video dimensions (width/height/duration)                        | `[{ path: "file:///local/path/filename", mimeType: "image/jpeg", fileName: "originalFilename.jpg", size: 2567402, width: 800, height: 600 }, { path: "file:///local/path/filename", mimeType: "video/mp4", fileName: "originalFilename.mp4", size: 2567402, width: 800, height: 600, duration: 20000 }]` |
| `shareIntent.meta`       | meta object which contains extra information about the share intent                                                                                  | `{ title: "My cool blog article", "og:image": "https://.../image.png" }`                                                                                                                                                                                                                                 |
| `shareIntent.meta.title` | optional title property sent by other app (available on Android and when `NSExtensionActivationSupportsWebPageWithMaxCount` is enabled on iOS)       | `My cool blog article`                                                                                                                                                                                                                                                                                   |
| `shareIntent.meta.xxx`   | list all webpage metadata available in meta tags `<meta name=""... />` (iOS only, available with `NSExtensionActivationSupportsWebPageWithMaxCount`) |                                                                                                                                                                                                                                                                                                          |

#### Customize Content Types in `app.json`

Simply choose content types you need :

```json
  "plugins": [
      [
        "expo-share-intent-next",
        {
          "iosActivationRules": {
            "NSExtensionActivationSupportsWebURLWithMaxCount": 1,
            "NSExtensionActivationSupportsWebPageWithMaxCount": 1,
            "NSExtensionActivationSupportsImageWithMaxCount": 1,
            "NSExtensionActivationSupportsMovieWithMaxCount": 1,
          },
          "androidIntentFilters": ["text/*", "image/*"]
        }
      ],
  ],
```

| Option                        | Values                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| iosActivationRules            | Allow **text** sharing with `"NSExtensionActivationSupportsText": true`<br/>**Url** sharing with `"NSExtensionActivationSupportsWebURLWithMaxCount": 1` and `"NSExtensionActivationSupportsWebPageWithMaxCount": 1`<br/>**Images** sharing with `"NSExtensionActivationSupportsImageWithMaxCount": 1`<br/>**Videos** sharing with `"NSExtensionActivationSupportsMovieWithMaxCount": 1`<br/>**Files and audio** sharing with `"NSExtensionActivationSupportsFileWithMaxCount": 1`<br/>_default value_: `{ "NSExtensionActivationSupportsWebURLWithMaxCount": 1, "NSExtensionActivationSupportsWebPageWithMaxCount": 1 }"`<br/>_More info in apple developper doc [here](https://developer.apple.com/documentation/bundleresources/information_property_list/nsextension/nsextensionattributes/nsextensionactivationrule)_<br/>you can also provide a custom query (ex: `"iosActivationRules": "SUBQUERY (...)"`) |
| iosShareExtensionName         | override `CFBundleDisplayName` the extension `info.plist`, also used as extension name for xcode target (ex: `ExpoShareIntent Example Extension`, folder: `ExpoShareIntentExampleExtension`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| iosAppGroupIdentifier         | custom application group identifier for `com.apple.security.application-groups` (ex: `group.custom.exposhareintent.example`) cf [#94](https://github.com/eatmatch/expo-share-intent-next/issues/94)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| androidIntentFilters          | **one file sharing** array of MIME types :`"text/*"` / `"image/*"` / `"video/*"` / `"*/*"`<br/>_default value_: `["text/*"]` (text and url)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| androidMultiIntentFilters     | **multiple files sharing** array of MIME types : `"image/*"` / `"video/*"` / `"audio/*`/ `"*/*"`<br/>_default value_: `[]`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| androidMainActivityAttributes | _default value_: `{ "android:launchMode": "singleTask" }`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| preprocessorInjectJS          | Add javascript to webpage preprocessor before the share extension is called (cf [Accessing a Webpage](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html#//apple_ref/doc/uid/TP40014214-CH21-SW12)).<br/>Example: <code>preprocessorInjectJS: "metas['og\\:image'] = metas['og\\:image'] &#124;&#124; document.querySelector('img#seo-image')?.getAttribute('src')"</code>                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| disableAndroid                | Disable the android share intent. Useful if you want to use a custom implementation. _default value_: `false`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| disableIOS                    | Disable the ios share extension. Useful if you want to use a custom implementation (ex: [iOS Custom View](#ios-custom-view-)). _default value_: `false`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |

### Expo Router

With `expo-router` you need to handle loading elements on [Layout](https://docs.expo.dev/routing/appearance/). It's the only way to call the native module using deeplink url.

An example is available with Expo Router v3 in [example/expo-router](https://github.com/eatmatch/expo-share-intent-next/tree/main/example/expo-router/)

### React Navigation

If you want to handle share intent with React Navigation v6, you must use the `ShareIntentProvider` and add a custom mapping function in your linking configuration.

Take a look at the example in [example/react-navigation](https://github.com/eatmatch/expo-share-intent-next/tree/main/example/react-navigation/).

## Troubleshooting - FAQ

### iOS Extension Target

When building on EAS you should only have **one** extension target (during credentials setting process).

To avoid expo auto configuration to add an experimental "appExtensions" to `app.json` you must manually configure your eas build (projectId in `app.json` and a `eas.json` file).

More details in [#1](https://github.com/eatmatch/expo-share-intent-next-demo/issues/1)

### Config sync failed

```bash
$ yarn prebuild
⠧ Running prebuild[expo-share-intent-next] add ios share extension (scheme:exposhareintentexample appIdentifier:expo.modules.exposhareintent.example)
⠇ Running prebuild[expo-share-intent-next] add android filters text/* image/*
✖ Config sync failed
TypeError: [ios.xcodeproj]: withIosXcodeprojBaseMod: Cannot read properties of null (reading 'path')
```

This package need a post-install script, see `xcode+3.0.1.patch` file in [example/patches](https://github.com/eatmatch/expo-share-intent-next/tree/main/example/basic/patches) (more info [#31](https://github.com/eatmatch/expo-share-intent-next-demo/issues/31) and [#13](https://github.com/eatmatch/expo-share-intent-next/issues/13))

### Expo Go ?

We are using native code to make share intent works, so we can't use Expo Go and have to use a custom dev client, that's why the demo use `expo prebuild --no-install` command and then `expo run:ios`, instead of a simple `expo start --ios`
-> More information [here](https://docs.expo.dev/workflow/customizing/)

That way you can test your share intent into simulator, but that does not exempt you to test a complete build on device at the end of your development process to make sure all works as excepted.

NB: don't commit your ios/ and android/ folder, rebuild it before EAS build.

> If you want to open your application in expo go with this package your can **disable** the native module call with `useShareIntent({ disabled: true })`. Allowing to speed test other features on your app without share intent.

### Google Signin and CFBundleURLSchemes

When using `@react-native-google-signin/google-signin` you need to configure a custom scheme in your app.json to handle google signin fallback. By doing this, the original app scheme is deleted and must be manually reassigned :

```json
 "scheme": "exposhareintentexample",
 "ios": {
      "supportsTablet": true,
      "bundleIdentifier": "expo.modules.exposhareintent.example",
      "infoPlist": {
        "CFBundleURLTypes": [
          {
            "CFBundleURLSchemes": [
              "com.googleusercontent.apps.xxxxxxxx-xxxxxxxxx",
              "exposhareintentexample"
            ]
          }
        ]
      }
    },
```

### iOS Custom view ?

This project does not and will not support the iOS custom view (native view in the context of sharing intent). Everything must be managed in the main application!

> Managing a custom view requires to package a complete application (seperate react-native bundle), which comes with its own set of constraints (loading time, compatibility with third-party libraries, specific mainEntry, etc.). However `expo-share-intent-next` aims to remain small and powerful, with easy version upgrades.

If iOS Custom view is a must have feature for you, simply disable iOS configuration of this plugin in your `app.json` ([`disableIOS: true`](#customize-content-types-in-appjson)) and configure the [`expo-share-extension`](https://github.com/MaxAst/expo-share-extension) package.

> for archive a POC was made on this [PR](https://github.com/eatmatch/expo-share-intent-next/pull/138)

### iOS Context Menu ?

This project does not and will not support the iOS Context Menu!

> Even if it sounds interesting, the implementation is too specific for each use case and would require a separate project.

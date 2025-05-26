import ExpoModulesCore
import Foundation
import Intents
import Photos

public class ExpoShareIntentModule: Module {
    // Each module class must implement the definition function. The definition consists of components
    // that describes the module's functionality and behavior.
    // See https://docs.expo.dev/modules/module-api for more details about available components.
    public func definition() -> ModuleDefinition {
        // Sets the name of the module that JavaScript code will use to refer to the module. Takes a string as an argument.
        // Can be inferred from module's class name, but it's recommended to set it explicitly for clarity.
        // The module will be accessible from `requireNativeModule('ExpoShareIntentModule')` in JavaScript.
        Name("ExpoShareIntentModule")

        Events("onDonate", "onChange", "onStateChange", "onError")

        // Defines a JavaScript function that always returns a Promise and whose native code
        // is by default dispatched on the different thread than the JavaScript runtime runs on.
        AsyncFunction("getShareIntent") { (url: String?, promise: Promise) in
            guard let urlString = url else {
                promise.reject("E_NO_URL", "getShareIntent: URL was nil")
                return
            }

            let fileUrl = URL(string: urlString)
            let json = handleUrl(url: fileUrl)
            if json != "error" && json != "empty" {
                self.sendEvent(
                    "onChange",
                    [
                        "data": json
                    ]
                )
            }
        }

        AsyncFunction("donateSendMessage") {
            (
                conversationId: String,
                name: String,
                imageURL: String?,
                content: String?
            ) in

            /// Build the INPerson, optionally with the INImage
            let image: INImage = await createINImage(
                from: imageURL,
                name: name,
                size: 80
            )

            let recipient = INPerson(
                personHandle: INPersonHandle(
                    value: conversationId,
                    type: .unknown
                ),
                nameComponents: nil,
                displayName: name,
                image: image,
                contactIdentifier: nil,
                customIdentifier: conversationId
            )

            let groupName = INSpeakableString(spokenPhrase: name)
            /// Create & donate the intent
            let intent = INSendMessageIntent(
                recipients: [recipient],
                outgoingMessageType: .outgoingMessageText,
                content: content,
                speakableGroupName: groupName,
                conversationIdentifier: conversationId,
                serviceName: Bundle.serviceName,
                sender: nil,
                attachments: nil
            )
            intent.suggestedInvocationPhrase = "Send message to \(name)"
            intent.setImage(
                image,
                forParameterNamed: \.speakableGroupName
            )

            let interaction = INInteraction(
                intent: intent,
                response: nil
            )
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                interaction.donate { error in
                    print("donated \(String(describing: error))")
                    if let error = error {
                        self.reportError(error.localizedDescription)
                    } else {
                        let json = [
                            "conversationIdentifier": conversationId,
                            "name": name,
                            "content": content,
                        ]

                        self.sendEvent(
                            "onDonate",
                            [
                                "data": json
                            ]
                        )
                        continuation.resume()
                    }
                }
            }
        }

        Function("clearShareIntent") { (sharedKey: String) in
            let appGroupIdentifier = self.getAppGroupIdentifier()
            let userDefaults = UserDefaults(suiteName: appGroupIdentifier)
            userDefaults?.set(nil, forKey: sharedKey)
            userDefaults?.synchronize()
        }

        Function("hasShareIntent") { (key: String) in
            // for Android only
            return false
        }
    }

    // MARK: Create INImage
    func createINImage(
        from urlString: String?,
        name: String,
        size: CGFloat = 80
    ) async -> INImage {
        // always have a fallback UIImage
        let fallback = createMonogramAvatar(
            for: name,
            size: .init(width: size, height: size)
        )

        guard let urlString = urlString,
            let url = URL(string: urlString)
        else {
            // no URL at all → wrap monogram
            return INImage(imageData: fallback.pngData()!)
        }

        // Local file → use the URL constructor with dimensions
        if url.isFileURL {
            if let img = INImage(
                url: url,
                width: Double(size),
                height: Double(size)
            ) {
                return img
            }
            // fallback if that fails
            return INImage(imageData: fallback.pngData()!)
        }

        // Remote URL → download, crop, then wrap
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let raw = UIImage(data: data) else {
                return INImage(imageData: fallback.pngData()!)
            }
            let square = cropToSquareCoverMode(raw, size: size)
            guard let png = square.pngData() else {
                return INImage(imageData: fallback.pngData()!)
            }
            return INImage(imageData: png)
        } catch {
            return INImage(imageData: fallback.pngData()!)
        }
    }

    // MARK: Crop to square
    func cropToSquareCoverMode(_ image: UIImage, size: CGFloat) -> UIImage {
        let shortest = min(image.size.width, image.size.height)
        let cropRect = CGRect(
            x: (image.size.width - shortest) / 2,
            y: (image.size.height - shortest) / 2,
            width: shortest,
            height: shortest
        )
        guard let cgCropped = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        let cropped = UIImage(
            cgImage: cgCropped,
            scale: image.scale,
            orientation: image.imageOrientation
        )

        // now scale it down to your target size
        let renderer = UIGraphicsImageRenderer(
            size: .init(width: size, height: size)
        )
        return renderer.image { _ in
            cropped.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
        }
    }

    // MARK: Create Monogram Avatar
    func createMonogramAvatar(
        for name: String,
        size: CGSize = .init(width: 80, height: 80)
    ) -> UIImage {
        let initials = String(name.prefix(1)).uppercased()
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // 1) colored background
            let circleRect = CGRect(origin: .zero, size: size)
            UIColor.systemGray.setFill()
            ctx.cgContext.fillEllipse(in: circleRect)

            // 2) draw the letter centered
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(
                    ofSize: size.width * 0.5,
                    weight: .medium
                ),
                .foregroundColor: UIColor.white,
            ]
            let textSize = initials.size(withAttributes: attrs)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            initials.draw(in: textRect, withAttributes: attrs)
        }
    }

    private var initialMedia: [SharedMediaFile]? = nil
    private var latestMedia: [SharedMediaFile]? = nil

    private var initialText: String? = nil
    private var latestText: String? = nil
    private var conversationId: String? = nil

    /**
     * Handles the shared URL and processes different types of shared content
     * - Parameter url: The URL containing shared content information
     * - Returns: JSON string with content details or error message
     */
    private func handleUrl(url: URL?) -> String? {
        // Verify we have both a URL and app group identifier
        let appGroupIdentifier = self.getAppGroupIdentifier()
        NSLog(
            "HandleUrl \(String(describing: url)) \(String(describing: appGroupIdentifier))"
        )

        guard let url = url else {
            reportError(
                "Cannot retrieve appGroupIdentifier. Please check your share extension iosAppGroupIdentifier."
            )
            return "error"
        }

        // Get shared preferences from app group
        let userDefaults = UserDefaults(suiteName: appGroupIdentifier)
        guard let fragment = url.fragment else {
            reportError("URL fragment is missing")
            return "error"
        }

        // Handle direct text URLs (without a key in host)
        if fragment != "media" && fragment != "file" && fragment != "weburl"
            && fragment != "text"
        {
            return handleDirectTextUrl(
                url: url,
                fragment: fragment
            )
        }

        // Extract the key from URL host
        guard let key = extractKeyFromHost(url: url) else {
            reportError("Cannot extract key from URL host")
            return "error"
        }

        // Process content based on fragment type
        switch fragment {
        case "media":
            return processMediaContent(
                key: key,
                userDefaults: userDefaults,
                fragment: fragment
            )
        case "file":
            return processFileContent(
                key: key,
                userDefaults: userDefaults,
                fragment: fragment
            )
        case "weburl":
            return processWebUrlContent(
                key: key,
                userDefaults: userDefaults,
                fragment: fragment
            )
        case "text":
            return processTextContent(
                key: key,
                userDefaults: userDefaults,
                fragment: fragment
            )
        default:
            reportError("File type is invalid: \(fragment)")
            return "error"
        }
    }

    /**
     * Extracts key from URL host component
     */
    private func extractKeyFromHost(url: URL) -> String? {
        return url.host?.components(separatedBy: "=").last
    }

    /**
     * Reports error via event system
     */
    private func reportError(_ message: String) {
        self.sendEvent("onError", ["data": message])
    }

    /**
     * Handles direct text URL without a key in host
     */
    private func handleDirectTextUrl(
        url: URL,
        fragment: String
    ) -> String? {
        latestText = url.absoluteString
        return latestText.flatMap { text in
            try? ShareIntentText(
                conversationId: self.conversationId,
                text: text,
                type: fragment
            ).toJSON()
        } ?? "empty"
    }

    /**
     * Processes media content from shared preferences
     */
    private func processMediaContent(
        key: String,
        userDefaults: UserDefaults?,
        fragment: String
    ) -> String? {
        guard let json = userDefaults?.object(forKey: key) as? Data else {
            return "empty"
        }

        let sharedArray = decodeMedia(data: json)
        self.conversationId = sharedArray.first?.conversationId
        let sharedMediaFiles = sharedArray.compactMap {
            mediaFile -> SharedMediaFile? in
            guard let path = getAbsolutePath(for: mediaFile.path) else {
                return nil
            }

            if mediaFile.type == .video, let thumbnailPath = mediaFile.thumbnail
            {
                let thumbnail = getAbsolutePath(for: thumbnailPath)
                return SharedMediaFile(
                    path: path,
                    thumbnail: thumbnail,
                    fileName: mediaFile.fileName,
                    fileSize: mediaFile.fileSize,
                    width: mediaFile.width,
                    height: mediaFile.height,
                    duration: mediaFile.duration,
                    mimeType: mediaFile.mimeType,
                    type: mediaFile.type,
                    conversationId: mediaFile.conversationId
                )
            }

            return SharedMediaFile(
                path: path,
                thumbnail: nil,
                fileName: mediaFile.fileName,
                fileSize: mediaFile.fileSize,
                width: mediaFile.width,
                height: mediaFile.height,
                duration: mediaFile.duration,
                mimeType: mediaFile.mimeType,
                type: mediaFile.type,
                conversationId: mediaFile.conversationId
            )
        }

        guard let json = toJson(data: sharedMediaFiles) else { return "[]" }
        
        let conversationIdFragment = self.conversationId != nil
            ? "\"conversationId\": \"\(self.conversationId!)\""
            : "\"conversationId\": null"
        
        return
            "{ \"files\": \(json), \"type\": \"\(fragment)\", \(conversationIdFragment) }"
    }

    /**
     * Processes file content from shared preferences
     */
    private func processFileContent(
        key: String,
        userDefaults: UserDefaults?,
        fragment: String
    ) -> String? {
        guard let json = userDefaults?.object(forKey: key) as? Data else {
            return "empty"
        }

        let sharedArray = decodeMedia(data: json)
        self.conversationId = sharedArray.first?.conversationId
        let sharedMediaFiles = sharedArray.compactMap {
            mediaFile -> SharedMediaFile? in
            guard let path = getAbsolutePath(for: mediaFile.path) else {
                return nil
            }

            return SharedMediaFile(
                path: path,
                thumbnail: nil,
                fileName: mediaFile.fileName,
                fileSize: mediaFile.fileSize,
                width: nil,
                height: nil,
                duration: nil,
                mimeType: mediaFile.mimeType,
                type: mediaFile.type,
                conversationId: mediaFile.conversationId
            )
        }

        guard let json = toJson(data: sharedMediaFiles) else { return "[]" }
        
        let conversationIdFragment = self.conversationId != nil
            ? "\"conversationId\": \"\(self.conversationId!)\""
            : "\"conversationId\": null"
        return
            "{ \"files\": \(json), \"type\": \"\(fragment)\", \(conversationIdFragment) }"
    }

    /**
     * Processes web URL content from shared preferences
     */
    private func processWebUrlContent(
        key: String,
        userDefaults: UserDefaults?,
        fragment: String
    ) -> String? {
        guard let json = userDefaults?.object(forKey: key) as? Data else {
            return "empty"
        }

        let sharedArray = decodeWebUrl(data: json)
        self.conversationId = sharedArray.first?.conversationId
        let sharedWebUrls = sharedArray.map {
            WebUrl(
                url: $0.url,
                meta: $0.meta,
                conversationId: $0.conversationId
            )
        }

        guard let json = toJson(data: sharedWebUrls) else { return "[]" }
        let conversationIdFragment = self.conversationId != nil
            ? "\"conversationId\": \"\(self.conversationId!)\""
            : "\"conversationId\": null"
        return
            "{ \"weburls\": \(json), \"type\": \"\(fragment)\", \(conversationIdFragment) }"
    }

    /**
     * Processes text content from shared preferences
     */
    private func processTextContent(
        key: String,
        userDefaults: UserDefaults?,
        fragment: String
    ) -> String? {
        guard let raw = userDefaults?.object(forKey: key) as? Data else {
            return "empty"
        }

        let decoder = JSONDecoder()
        guard let items = try? decoder.decode([SharedText].self, from: raw)
        else {
            reportError("Failed to decode shared text payload")
            return "error"
        }

        self.conversationId = items.first?.conversationId
        self.latestText = items.map { $0.text }.joined(separator: ",")

        return latestText.flatMap { text in
            try? ShareIntentText(
                conversationId: self.conversationId,
                text: text,
                type: fragment
            ).toJSON()
        } ?? latestText
    }

    private func getAppGroupIdentifier() -> String? {
        let appGroupIdentifier: String? =
            Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier")
            as? String
        if appGroupIdentifier == nil {
            self.sendEvent(
                "onError",
                [
                    "data":
                        "appGroupIdentifier is nil `\(String(describing: appGroupIdentifier))`"
                ]
            )
        }
        return appGroupIdentifier
    }

    private func getAbsolutePath(for identifier: String) -> String? {
        if identifier.starts(with: "file://")
            || identifier.starts(with: "/var/mobile/Media")
            || identifier.starts(with: "/private/var/mobile")
        {
            return identifier
        }
        let phAsset = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: .none
        )
        .firstObject
        if phAsset == nil {
            return nil
        }
        return getImageURL(for: phAsset!)
    }

    private func getImageURL(for asset: PHAsset) -> String? {
        var url: String? = nil
        let semaphore = DispatchSemaphore(value: 0)
        let options2 = PHContentEditingInputRequestOptions()
        options2.isNetworkAccessAllowed = true
        asset.requestContentEditingInput(with: options2) { (input, info) in
            url = input?.fullSizeImageURL?.path
            semaphore.signal()
        }
        semaphore.wait()
        return url
    }

    private func decodeMedia(data: Data) -> [SharedMediaFile] {
        let encodedData = try? JSONDecoder().decode(
            [SharedMediaFile].self,
            from: data
        )
        return encodedData!
    }

    private func decodeWebUrl(data: Data) -> [WebUrl] {
        return (try? JSONDecoder().decode([WebUrl].self, from: data)) ?? []
    }

    private func decodeText(data: Data) -> [ShareIntentText] {
        return (try? JSONDecoder().decode([ShareIntentText].self, from: data))
            ?? []
    }

    private func toJson<T: Encodable>(data: [T]?) -> String? {
        guard let data = data else { return nil }
        return encodeToJsonString(data)
    }

    private func encodeToJsonString<T: Encodable>(_ value: T) -> String? {
        guard let encodedData = try? JSONEncoder().encode(value) else {
            return nil
        }
        return String(data: encodedData, encoding: .utf8)
    }

    struct ShareIntentText: Codable {
        let conversationId: String?
        let text: String
        let type: String  // text / weburl
    }

    struct WebUrl: Codable {
        var conversationId: String?
        var url: String
        var meta: String

        init(url: String, meta: String, conversationId: String?) {
            self.url = url
            self.meta = meta
            self.conversationId = conversationId
        }
    }

    class SharedText: Codable {
        var text: String
        var conversationId: String

        init(text: String, conversationId: String) {
            self.text = text
            self.conversationId = conversationId
        }
    }

    class SharedMediaFile: Codable {
        var conversationId: String?
        var path: String  // can be image, video or url path
        var thumbnail: String?  // video thumbnail
        var fileName: String  // uuid + extension
        var fileSize: Int?
        var width: Int?  // for image
        var height: Int?  // for image
        var duration: Double?  // video duration in milliseconds
        var mimeType: String
        var type: SharedMediaType

        init(
            path: String,
            thumbnail: String?,
            fileName: String,
            fileSize: Int?,
            width: Int?,
            height: Int?,
            duration: Double?,
            mimeType: String,
            type: SharedMediaType,
            conversationId: String?
        ) {
            self.path = path
            self.thumbnail = thumbnail
            self.fileName = fileName
            self.fileSize = fileSize
            self.width = width
            self.height = height
            self.duration = duration
            self.mimeType = mimeType
            self.type = type
            self.conversationId = conversationId
        }
    }

    enum SharedMediaType: Int, Codable {
        case image
        case video
        case file
    }

    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
}

extension Encodable {
    func toJSON() throws -> String? {
        let jsonData = try? JSONEncoder().encode(self)
        let jsonString = String(data: jsonData!, encoding: .utf8)
        return jsonString
    }
}

extension Bundle {
    /// A user‐facing name for this bundle, falling back to bundle name or identifier.
    public var serviceName: String? {
        // 1. Try the display name (what you set as your app name on the Home screen)
        if let displayName = object(forInfoDictionaryKey: "CFBundleDisplayName")
            as? String,
            !displayName.isEmpty
        {
            return displayName
        }
        // 2. Fallback to the bundle name
        if let name = object(forInfoDictionaryKey: "CFBundleName") as? String,
            !name.isEmpty
        {
            return name
        }
        // 3. As a last resort, the bundle identifier (e.g. com.yourcompany.yourapp)
        return bundleIdentifier
    }

    /// A static shorthand if you prefer.
    public static var serviceName: String? {
        return main.serviceName
    }
}

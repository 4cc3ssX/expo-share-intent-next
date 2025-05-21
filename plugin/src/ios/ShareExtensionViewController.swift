import Intents
import MobileCoreServices
import Photos
import Social
import UIKit

class ShareViewController: UIViewController {
  let hostAppGroupIdentifier = "<GROUPIDENTIFIER>"
  let shareProtocol = "<SCHEME>"
  let sharedKey = "<SCHEME>ShareKey"
  var sharedMedia: [SharedMediaFile] = []
  var sharedWebUrl: [WebUrl] = []
  var sharedText: [String] = []
  let imageContentType: String = UTType.image.identifier
  let videoContentType: String = UTType.movie.identifier
  let textContentType: String = UTType.text.identifier
  let urlContentType: String = UTType.url.identifier
  let propertyListType: String = UTType.propertyList.identifier
  let fileURLType: String = UTType.fileURL.identifier
  let pdfContentType: String = UTType.pdf.identifier
  private var conversationId: String? = nil

  override func viewDidLoad() {
    super.viewDidLoad()

    // Populate the recipient property with the metadata in case the person taps a suggestion from the share sheet.
    let intent = self.extensionContext?.intent as? INSendMessageIntent
    if intent != nil {
      self.conversationId = intent!.conversationIdentifier
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    Task {
      guard let extensionContext = self.extensionContext,
        let content = extensionContext.inputItems.first as? NSExtensionItem,
        let attachments = content.attachments
      else {
        dismissWithError(message: "No content found")
        return
      }

      await processAttachments(attachments, content: content)
    }
  }

  private func processAttachments(
    _ attachments: [NSItemProvider], content: NSExtensionItem
  ) async {
    for (index, attachment) in attachments.enumerated() {
      if let handler = getHandlerForAttachment(attachment) {
        await handler(content, attachment, index)
      } else {
        NSLog(
          "[ERROR] content type not handled: \(String(describing: content))")
        await dismissWithError(
          message: "Content type not handled \(String(describing: content))")
      }
    }
  }

  private func getHandlerForAttachment(_ attachment: NSItemProvider) -> (
    (NSExtensionItem, NSItemProvider, Int) async -> Void
  )? {
    if attachment.hasItemConformingToTypeIdentifier(imageContentType) {
      return handleImages
    }
    if attachment.hasItemConformingToTypeIdentifier(videoContentType) {
      return handleVideos
    }
    if attachment.hasItemConformingToTypeIdentifier(fileURLType) {
      return handleFiles
    }
    if attachment.hasItemConformingToTypeIdentifier(pdfContentType) {
      return handlePdf
    }
    if attachment.hasItemConformingToTypeIdentifier(propertyListType) {
      return handlePrepocessing
    }
    if attachment.hasItemConformingToTypeIdentifier(urlContentType) {
      return handleUrl
    }
    if attachment.hasItemConformingToTypeIdentifier(textContentType) {
      return handleText
    }
    return nil
  }

  private func handleText(
    content: NSExtensionItem, attachment: NSItemProvider, index: Int
  ) async {
    Task.detached {
      do {
        guard
          let item = try await attachment.loadItem(
            forTypeIdentifier: self.textContentType) as? String
        else {
          throw NSError(
            domain: "TextLoadingError", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid text format"])
        }

        await self.processTextItem(item, content: content, index: index)
      } catch {
        NSLog("[ERROR] Cannot load text content: \(error)")
        await self.dismissWithError(
          message: "Cannot load text content: \(error)")
      }
    }
  }

  private func processTextItem(
    _ item: String, content: NSExtensionItem, index: Int
  ) async {
    self.sharedText.append(item)

    // If this is the last item, save sharedText in userDefaults and redirect to host app
    let isLastItem = index == (content.attachments?.count)! - 1
    if isLastItem {
      let payload: [SharedText] = sharedText.map {
        SharedText(
          text: $0,
          conversationId: self.conversationId)
      }

      saveAndRedirect(data: self.toData(data: payload), type: .text)
    }
  }

  private func handleUrl(
    content: NSExtensionItem, attachment: NSItemProvider, index: Int
  ) async {
    Task.detached {
      do {
        guard
          let item = try await attachment.loadItem(
            forTypeIdentifier: self.urlContentType) as? URL
        else {
          throw NSError(
            domain: "URLLoadingError", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid URL format"])
        }

        await self.processUrlItem(item, content: content, index: index)
      } catch {
        NSLog("[ERROR] Cannot load url content: \(error)")
        await self.dismissWithError(
          message: "Cannot load url content: \(error)")
      }
    }
  }

  private func processUrlItem(_ url: URL, content: NSExtensionItem, index: Int)
    async
  {
    self.sharedWebUrl.append(
      WebUrl(
        url: url.absoluteString, meta: "",
        conversationId: self.conversationId))

    // If this is the last item, save and redirect
    let isLastItem = index == (content.attachments?.count)! - 1
    if isLastItem {
      saveAndRedirect(data: self.toData(data: self.sharedWebUrl), type: .weburl)
    }
  }

  private func handlePrepocessing(
    content: NSExtensionItem, attachment: NSItemProvider, index: Int
  ) async {
    Task.detached {
      do {
        guard
          let item = try await attachment.loadItem(
            forTypeIdentifier: self.propertyListType, options: nil)
            as? NSDictionary
        else {
          throw NSError(
            domain: "PreprocessingLoadingError", code: 1,
            userInfo: [
              NSLocalizedDescriptionKey: "Invalid preprocessing content"
            ])
        }

        await self.processPreprocessingItem(
          item, content: content, index: index)
      } catch {
        NSLog("[ERROR] Cannot load preprocessing content: \(error)")
        await self.dismissWithError(
          message: "Cannot load preprocessing content: \(error)")
      }
    }
  }

  private func processPreprocessingItem(
    _ item: NSDictionary, content: NSExtensionItem, index: Int
  ) async {
    guard
      let results = item[NSExtensionJavaScriptPreprocessingResultsKey]
        as? NSDictionary
    else {
      dismissWithError(message: "Cannot load preprocessing results")
      return
    }

    NSLog(
      "[DEBUG] NSExtensionJavaScriptPreprocessingResultsKey \(String(describing: results))"
    )
    guard let url = results["baseURI"] as? String,
      let meta = results["meta"] as? String
    else {
      dismissWithError(message: "Missing required preprocessing data")
      return
    }

    self.sharedWebUrl.append(
      WebUrl(
        url: url, meta: meta,
        conversationId: self.conversationId))

    // If this is the last item, save and redirect
    let isLastItem = index == (content.attachments?.count)! - 1
    if isLastItem {
      saveAndRedirect(data: self.toData(data: self.sharedWebUrl), type: .weburl)
    }
  }

  private func handleImages(
    content: NSExtensionItem, attachment: NSItemProvider, index: Int
  ) async {
    Task.detached {
      do {
        let item = try await attachment.loadItem(
          forTypeIdentifier: self.imageContentType)
        await self.processImageItem(item, content: content, index: index)
      } catch {
        NSLog("[ERROR] Cannot load image content: \(error)")
        await self.dismissWithError(
          message: "Cannot load image content: \(error)")
      }
    }
  }

  private func processImageItem(
    _ item: Any, content: NSExtensionItem, index: Int
  ) async {
    let url = extractImageURL(from: item)
    guard let imageUrl = url else {
      dismissWithError(message: "Failed to extract image URL")
      return
    }

    let dimensions = getImageDimensions(from: imageUrl)
    let sharedFile = createSharedMediaFileForImage(
      url: imageUrl, dimensions: dimensions)

    if sharedFile != nil {
      self.sharedMedia.append(sharedFile!)
    }

    // If this is the last item, save and redirect
    let isLastItem = index == (content.attachments?.count)! - 1
    if isLastItem {
      saveAndRedirect(data: self.toData(data: self.sharedMedia), type: .media)
    }
  }

  private func extractImageURL(from item: Any) -> URL? {
    if let dataURL = item as? URL {
      return dataURL
    } else if let imageData = item as? UIImage {
      return saveScreenshot(imageData)
    }
    return nil
  }

  private func documentDirectoryPath() -> URL? {
    let path = FileManager.default.urls(
      for: .documentDirectory, in: .userDomainMask)
    return path.first
  }

  private func saveScreenshot(_ image: UIImage) -> URL? {
    var screenshotURL: URL? = nil
    if let screenshotData = image.pngData(),
      let screenshotPath = documentDirectoryPath()?.appendingPathComponent(
        "screenshot.png")
    {
      try? screenshotData.write(to: screenshotPath)
      screenshotURL = screenshotPath
    }
    return screenshotURL
  }

  private func getImageDimensions(from url: URL) -> (width: Int?, height: Int?)
  {
    var pixelWidth: Int? = nil
    var pixelHeight: Int? = nil

    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      return (nil, nil)
    }

    guard
      let imageProperties = CGImageSourceCopyPropertiesAtIndex(
        imageSource, 0, nil) as Dictionary?
    else {
      return (nil, nil)
    }

    pixelWidth = imageProperties[kCGImagePropertyPixelWidth] as? Int
    pixelHeight = imageProperties[kCGImagePropertyPixelHeight] as? Int

    // Check orientation and flip size if required
    if let raw = imageProperties[kCGImagePropertyOrientation] as? UInt32,
      let cgOrient = CGImagePropertyOrientation(rawValue: raw),
      cgOrient.isLandscape
    {
      swap(&pixelWidth, &pixelHeight)
    }

    return (pixelWidth, pixelHeight)
  }

  private func createSharedMediaFileForImage(
    url: URL, dimensions: (width: Int?, height: Int?)
  ) -> SharedMediaFile? {
    let fileName = getFileName(from: url, type: .image)
    let fileExtension = getExtension(from: url, type: .image)
    let fileSize = getFileSize(from: url)
    let mimeType = url.mimeType(ext: fileExtension)
    let newName = "\(UUID().uuidString).\(fileExtension)"
    let newPath = getAppGroupPath().appendingPathComponent(newName)

    let copied = copyFile(at: url, to: newPath)
    guard copied else {
      return nil
    }

    return SharedMediaFile(
      path: newPath.absoluteString,
      thumbnail: nil,
      fileName: fileName,
      fileSize: fileSize,
      width: dimensions.width,
      height: dimensions.height,
      duration: nil,
      mimeType: mimeType,
      type: .image,
      conversationId: self.conversationId
    )
  }

  private func getAppGroupPath() -> URL {
    return FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: self.hostAppGroupIdentifier)!
  }

  private func handleVideos(
    content: NSExtensionItem, attachment: NSItemProvider, index: Int
  ) async {
    Task.detached {
      do {
        guard
          let url = try await attachment.loadItem(
            forTypeIdentifier: self.videoContentType) as? URL
        else {
          throw NSError(
            domain: "VideoLoadingError", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid video format"])
        }

        await self.processVideoItem(url, content: content, index: index)
      } catch {
        NSLog("[ERROR] Cannot load video content: \(error)")
        await self.dismissWithError(
          message: "Cannot load video content: \(error)")
      }
    }
  }

  private func processVideoItem(
    _ url: URL, content: NSExtensionItem, index: Int
  ) async {
    let fileName = getFileName(from: url, type: .video)
    let fileExtension = getExtension(from: url, type: .video)
    let fileSize = getFileSize(from: url)
    let mimeType = url.mimeType(ext: fileExtension)
    let newName = "\(UUID().uuidString).\(fileExtension)"
    let newPath = getAppGroupPath().appendingPathComponent(newName)

    let copied = copyFile(at: url, to: newPath)
    guard copied else {
      dismissWithError(message: "Failed to copy video file")
      return
    }

    guard
      let sharedFile = getSharedMediaFile(
        forVideo: newPath, fileName: fileName, fileSize: fileSize,
        mimeType: mimeType)
    else {
      dismissWithError(message: "Failed to process video file")
      return
    }

    self.sharedMedia.append(sharedFile)

    // If this is the last item, save and redirect
    let isLastItem = index == (content.attachments?.count)! - 1
    if isLastItem {
      saveAndRedirect(data: self.toData(data: self.sharedMedia), type: .media)
    }
  }

  private func handlePdf(
    content: NSExtensionItem, attachment: NSItemProvider, index: Int
  ) async {
    Task.detached {
      do {
        guard
          let url = try await attachment.loadItem(
            forTypeIdentifier: self.pdfContentType) as? URL
        else {
          throw NSError(
            domain: "PDFLoadingError", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid PDF format"])
        }

        await self.handleFileURL(content: content, url: url, index: index)
      } catch {
        NSLog("[ERROR] Cannot load pdf content: \(error)")
        await self.dismissWithError(
          message: "Cannot load pdf content: \(error)")
      }
    }
  }

  private func handleFiles(
    content: NSExtensionItem, attachment: NSItemProvider, index: Int
  ) async {
    Task.detached {
      do {
        guard
          let url = try await attachment.loadItem(
            forTypeIdentifier: self.fileURLType) as? URL
        else {
          throw NSError(
            domain: "FileLoadingError", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid file format"])
        }

        await self.handleFileURL(content: content, url: url, index: index)
      } catch {
        NSLog("[ERROR] Cannot load file content: \(error)")
        await self.dismissWithError(
          message: "Cannot load file content: \(error)")
      }
    }
  }

  private func handleFileURL(content: NSExtensionItem, url: URL, index: Int)
    async
  {
    let fileName = getFileName(from: url, type: .file)
    let fileExtension = getExtension(from: url, type: .file)
    let fileSize = getFileSize(from: url)
    let mimeType = url.mimeType(ext: fileExtension)
    let newName = "\(UUID().uuidString).\(fileExtension)"
    let newPath = getAppGroupPath().appendingPathComponent(newName)

    let copied = copyFile(at: url, to: newPath)
    guard copied else {
      dismissWithError(message: "Failed to copy file")
      return
    }

    self.sharedMedia.append(
      SharedMediaFile(
        path: newPath.absoluteString,
        thumbnail: nil,
        fileName: fileName,
        fileSize: fileSize,
        width: nil,
        height: nil,
        duration: nil,
        mimeType: mimeType,
        type: .file,
        conversationId: self.conversationId
      )
    )

    // If this is the last item, save and redirect
    let isLastItem = index == (content.attachments?.count)! - 1
    if isLastItem {
      saveAndRedirect(data: self.toData(data: self.sharedMedia), type: .file)
    }
  }

  private func saveAndRedirect(data: Any, type: RedirectType) {
    let userDefaults = UserDefaults(suiteName: self.hostAppGroupIdentifier)
    userDefaults?.set(data, forKey: self.sharedKey)
    userDefaults?.synchronize()
    self.redirectToHostApp(type: type)
  }

  private func dismissWithError(message: String? = nil) {
    DispatchQueue.main.async {
      NSLog("[ERROR] Error loading application ! \(message!)")
      let alert = UIAlertController(
        title: "Error", message: "Error loading application: \(message!)",
        preferredStyle: .alert)

      let action = UIAlertAction(title: "OK", style: .cancel) { _ in
        self.dismiss(animated: true, completion: nil)
        self.extensionContext!.completeRequest(
          returningItems: [], completionHandler: nil)
      }

      alert.addAction(action)
      self.present(alert, animated: true, completion: nil)
    }
  }

  private func redirectToHostApp(type: RedirectType) {
    let url = URL(string: "\(shareProtocol)://dataUrl=\(sharedKey)#\(type)")!
    var responder = self as UIResponder?

    while responder != nil {
      guard let application = responder as? UIApplication else {
        responder = responder!.next
        continue
      }

      guard application.canOpenURL(url) else {
        NSLog("redirectToHostApp canOpenURL KO: \(shareProtocol)")
        self.dismissWithError(
          message: "Application not found, invalid url scheme \(shareProtocol)")
        return
      }

      application.open(url)
      break
    }

    extensionContext!.completeRequest(
      returningItems: [], completionHandler: nil)
  }

  enum RedirectType {
    case media
    case text
    case weburl
    case file
  }

  func getExtension(from url: URL, type: SharedMediaType) -> String {
    let parts = url.lastPathComponent.components(separatedBy: ".")
    var ex: String? = nil
    if parts.count > 1 {
      ex = parts.last
    }
    if ex == nil {
      switch type {
      case .image:
        ex = "PNG"
      case .video:
        ex = "MP4"
      case .file:
        ex = "TXT"
      }
    }
    return ex ?? "Unknown"
  }

  func getFileName(from url: URL, type: SharedMediaType) -> String {
    var name = url.lastPathComponent
    if name == "" {
      name = UUID().uuidString + "." + getExtension(from: url, type: type)
    }
    return name
  }

  func getFileSize(from url: URL) -> Int? {
    do {
      let resources = try url.resourceValues(forKeys: [.fileSizeKey])
      return resources.fileSize
    } catch {
      NSLog("Error: \(error)")
      return nil
    }
  }

  func copyFile(at srcURL: URL, to dstURL: URL) -> Bool {
    do {
      if FileManager.default.fileExists(atPath: dstURL.path) {
        try FileManager.default.removeItem(at: dstURL)
      }
      try FileManager.default.copyItem(at: srcURL, to: dstURL)
    } catch (let error) {
      NSLog("Cannot copy item at \(srcURL) to \(dstURL): \(error)")
      return false
    }
    return true
  }

  private func getSharedMediaFile(
    forVideo: URL, fileName: String, fileSize: Int?, mimeType: String
  )
    -> SharedMediaFile?
  {
    let asset = AVAsset(url: forVideo)
    let thumbnailPath = getThumbnailPath(for: forVideo)
    let duration = (CMTimeGetSeconds(asset.duration) * 1000).rounded()
    var trackWidth: Int? = nil
    var trackHeight: Int? = nil

    // get video info
    let track = asset.tracks(withMediaType: AVMediaType.video).first ?? nil
    if track != nil {
      let size = track!.naturalSize.applying(track!.preferredTransform)
      trackWidth = abs(Int(size.width))
      trackHeight = abs(Int(size.height))
    }

    if FileManager.default.fileExists(atPath: thumbnailPath.path) {
      return SharedMediaFile(
        path: forVideo.absoluteString, thumbnail: thumbnailPath.absoluteString,
        fileName: fileName,
        fileSize: fileSize, width: trackWidth, height: trackHeight,
        duration: duration,
        mimeType: mimeType, type: .video,
        conversationId: self.conversationId)
    }

    var saved = false
    let assetImgGenerate = AVAssetImageGenerator(asset: asset)
    assetImgGenerate.appliesPreferredTrackTransform = true
    assetImgGenerate.maximumSize = CGSize(width: 360, height: 360)
    do {
      let img = try assetImgGenerate.copyCGImage(
        at: CMTimeMakeWithSeconds(600, preferredTimescale: Int32(1.0)),
        actualTime: nil)
      try UIImage.pngData(UIImage(cgImage: img))()?.write(to: thumbnailPath)
      saved = true
    } catch {
      saved = false
    }

    return saved
      ? SharedMediaFile(
        path: forVideo.absoluteString, thumbnail: thumbnailPath.absoluteString,
        fileName: fileName,
        fileSize: fileSize, width: trackWidth, height: trackHeight,
        duration: duration,
        mimeType: mimeType, type: .video,
        conversationId: self.conversationId) : nil
  }

  private func getThumbnailPath(for url: URL) -> URL {
    let fileName = Data(url.lastPathComponent.utf8).base64EncodedString()
      .replacingOccurrences(
        of: "==", with: "")
    let path = FileManager.default
      .containerURL(
        forSecurityApplicationGroupIdentifier: self.hostAppGroupIdentifier)!
      .appendingPathComponent("\(fileName).jpg")
    return path
  }

  class WebUrl: Codable {
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
    var conversationId: String?

    init(text: String, conversationId: String?) {
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
      path: String, thumbnail: String?, fileName: String, fileSize: Int?,
      width: Int?, height: Int?,
      duration: Double?, mimeType: String, type: SharedMediaType,
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

  func toData(data: [WebUrl]) -> Data? {
    let encodedData = try? JSONEncoder().encode(data)
    return encodedData
  }

  func toData(data: [SharedMediaFile]) -> Data? {
    let encodedData = try? JSONEncoder().encode(data)
    return encodedData
  }

  func toData(data: [SharedText]) -> Data? {
    let encodedData = try? JSONEncoder().encode(data)
    return encodedData
  }
}

internal let mimeTypes = [
  "html": "text/html",
  "htm": "text/html",
  "shtml": "text/html",
  "css": "text/css",
  "xml": "text/xml",
  "gif": "image/gif",
  "jpeg": "image/jpeg",
  "jpg": "image/jpeg",
  "js": "application/javascript",
  "atom": "application/atom+xml",
  "rss": "application/rss+xml",
  "mml": "text/mathml",
  "txt": "text/plain",
  "jad": "text/vnd.sun.j2me.app-descriptor",
  "wml": "text/vnd.wap.wml",
  "htc": "text/x-component",
  "png": "image/png",
  "tif": "image/tiff",
  "tiff": "image/tiff",
  "wbmp": "image/vnd.wap.wbmp",
  "ico": "image/x-icon",
  "jng": "image/x-jng",
  "bmp": "image/x-ms-bmp",
  "svg": "image/svg+xml",
  "svgz": "image/svg+xml",
  "webp": "image/webp",
  "woff": "application/font-woff",
  "jar": "application/java-archive",
  "war": "application/java-archive",
  "ear": "application/java-archive",
  "json": "application/json",
  "hqx": "application/mac-binhex40",
  "doc": "application/msword",
  "pdf": "application/pdf",
  "ps": "application/postscript",
  "eps": "application/postscript",
  "ai": "application/postscript",
  "rtf": "application/rtf",
  "m3u8": "application/vnd.apple.mpegurl",
  "xls": "application/vnd.ms-excel",
  "eot": "application/vnd.ms-fontobject",
  "ppt": "application/vnd.ms-powerpoint",
  "wmlc": "application/vnd.wap.wmlc",
  "kml": "application/vnd.google-earth.kml+xml",
  "kmz": "application/vnd.google-earth.kmz",
  "7z": "application/x-7z-compressed",
  "cco": "application/x-cocoa",
  "jardiff": "application/x-java-archive-diff",
  "jnlp": "application/x-java-jnlp-file",
  "run": "application/x-makeself",
  "pl": "application/x-perl",
  "pm": "application/x-perl",
  "prc": "application/x-pilot",
  "pdb": "application/x-pilot",
  "rar": "application/x-rar-compressed",
  "rpm": "application/x-redhat-package-manager",
  "sea": "application/x-sea",
  "swf": "application/x-shockwave-flash",
  "sit": "application/x-stuffit",
  "tcl": "application/x-tcl",
  "tk": "application/x-tcl",
  "der": "application/x-x509-ca-cert",
  "pem": "application/x-x509-ca-cert",
  "crt": "application/x-x509-ca-cert",
  "xpi": "application/x-xpinstall",
  "xhtml": "application/xhtml+xml",
  "xspf": "application/xspf+xml",
  "zip": "application/zip",
  "epub": "application/epub+zip",
  "docx":
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "pptx":
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  "mid": "audio/midi",
  "midi": "audio/midi",
  "kar": "audio/midi",
  "mp3": "audio/mpeg",
  "ogg": "audio/ogg",
  "m4a": "audio/x-m4a",
  "ra": "audio/x-realaudio",
  "3gpp": "video/3gpp",
  "3gp": "video/3gpp",
  "ts": "video/mp2t",
  "mp4": "video/mp4",
  "mpeg": "video/mpeg",
  "mpg": "video/mpeg",
  "mov": "video/quicktime",
  "webm": "video/webm",
  "flv": "video/x-flv",
  "m4v": "video/x-m4v",
  "mng": "video/x-mng",
  "asx": "video/x-ms-asf",
  "asf": "video/x-ms-asf",
  "wmv": "video/x-ms-wmv",
  "avi": "video/x-msvideo",
]

extension URL {
  func mimeType(ext: String?) -> String {
    if #available(iOSApplicationExtension 14.0, *) {
      if let pathExt = ext,
        let mimeType = UTType(filenameExtension: pathExt)?.preferredMIMEType
      {
        return mimeType
      } else {
        return "application/octet-stream"
      }
    } else {
      return mimeTypes[ext?.lowercased() ?? ""] ?? "application/octet-stream"
    }
  }
}

extension Array {
  subscript(safe index: UInt) -> Element? {
    return Int(index) < count ? self[Int(index)] : nil
  }
}

extension CGImagePropertyOrientation {
  /// Returns true if the image is rotated 90° or 270°
  var isLandscape: Bool {
    switch self {
    case .left, .leftMirrored, .right, .rightMirrored:
      return true
    default:
      return false
    }
  }
}

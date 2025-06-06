//
//  Core.swift
//  Project Iris
//
//  Created by ThreeManager785 on 9/15/24.
//

import AuthenticationServices
import Cepheus
import SwiftUI
import SwiftSoup
import UIKit

public final class WebViewUIDelegate: NSObject, WKUIDelegate {
  public static let shared = WebViewUIDelegate()
  public func webView(
    _ webView: WKWebView,
    createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction,
    windowFeatures: WKWindowFeatures
  ) -> WKWebView? {
    if navigationAction.targetFrame == nil {
      webView.load(navigationAction.request)
    }
    return nil
  }
}

public final class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
  public static let shared = WebViewNavigationDelegate()
  
  public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {}
  
  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}
  
  public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {}
  
  public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
    print(error)
  }
  
  public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {}
}

//@MainActor public var webpageIsDisplaying = false
@MainActor public func searchButtonAction(isPrivateModeOn: Bool, searchField: String, isCookiesAllowed: Bool, searchEngine: String, isURL: Bool? = nil, useLegacyEngine: Bool? = nil) {
  let useLegacyEngine = UserDefaults.standard.bool(forKey: "UseLegacyBrowsingEngine")
  //Complete
  var optimizedSearchField: String = searchField
  var optimizedSearchEngine: String = searchEngine
  var optimizedIsURL: Bool? = isURL
  if optimizedIsURL == nil {
    optimizedIsURL = optimizedSearchField.isURL()
  }
  if !optimizedSearchField.hasPrefix("http://") && !optimizedSearchField.hasPrefix("https://") && optimizedIsURL! {
    optimizedSearchField = "http://" + optimizedSearchField
  }
  if !optimizedSearchEngine.hasPrefix("http://") && !optimizedSearchEngine.hasPrefix("https://") {
    optimizedSearchEngine = "http://" + optimizedSearchEngine
  }
  
  //Access
  if useLegacyEngine ?? UserDefaults.standard.bool(forKey: "UseLegacyBrowsingEngine") {
    let session = ASWebAuthenticationSession(
      url: URL(string: (optimizedIsURL! ? optimizedSearchField : optimizedSearchEngine.lowercased().replacingOccurrences(of: "\\iris", with: optimizedSearchField)).urlEncoded())!,
      callbackURLScheme: nil
    ) { _, _ in
      
    }
    if isPrivateModeOn {
      session.prefersEphemeralWebBrowserSession = true
    } else {
      session.prefersEphemeralWebBrowserSession = !isCookiesAllowed
    }
    session.start()
  } else {
    if !optimizedSearchField.isEmpty {
      let webpageConfig = WKWebView()
      webpageConfig.navigationDelegate = WebViewNavigationDelegate.shared
      webpageConfig.uiDelegate = WebViewUIDelegate.shared
      let webpageURLRequest = URLRequest(url: URL(string: (optimizedIsURL! ? optimizedSearchField : optimizedSearchEngine.lowercased().replacingOccurrences(of: "\\iris", with: optimizedSearchField)).urlEncoded())!)
      if #available(watchOS 10.0, *) {
        webpageConfig.configuration.websiteDataStore.httpCookieStore.setCookiePolicy(isCookiesAllowed ? .allow : .disallow)
      }
      webpageConfig.load(webpageURLRequest)
      webpageContent = webpageConfig
      webpageIsArchive = false
      webpageArchiveURL = nil
      webpageArchiveTitle = nil
      webpageIsDisplaying = true
    }
    //    print(webpageIsDisplaying)
  }
  
  //Record
  if !isPrivateModeOn && !optimizedSearchField.isEmpty {
    recordHistory(searchField)
  }
}

@MainActor func createSearchLink(_ content: String) -> String {
  let currentEngine = UserDefaults.standard.integer(forKey: "currentEngine")
  let engineLinks = (UserDefaults.standard.array(forKey: "engineLinks") ?? defaultSearchEngineLinks) as! [String]
  return engineLinks[currentEngine].replacingOccurrences(of: "\\iris", with: content)
}

@MainActor func getCurrentSearchEngineName() -> String {
  let currentEngine = UserDefaults.standard.integer(forKey: "currentEngine")
  let engineNames = (UserDefaults.standard.array(forKey: "engineNames") ?? defaultSearchEngineNames) as! [String]
  let engineNameIsEditable = (UserDefaults.standard.array(forKey: "engineNameIsEditable") ?? defaultSearchEngineEditable) as! [Bool]
  if !engineNameIsEditable[currentEngine] {
    return String(localized: LocalizedStringResource(stringLiteral: engineNames[currentEngine]))
  } else {
    return engineNames[currentEngine]
  }
}

@MainActor public func recordHistory(_ content: String) {
  //Record
  var history = getHistory()
  var lastHistoryID = UserDefaults.standard.integer(forKey: "lastHistoryID")
  history.insert((content, Date.now, lastHistoryID+1), at: 0)
  UserDefaults.standard.set(lastHistoryID+1, forKey: "lastHistoryID")
  updateHistory(history)
}

public func fetchWebPageContent(urlString: String, completion: @escaping (Result<String, Error>) -> Void) {
  guard let url = URL(string: urlString) else {
    completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
    return
  }
  let session = URLSession.shared
  let task = session.dataTask(with: url) { data, response, error in
    if let error = error {
      DispatchQueue.main.async { @MainActor in
        completion(.failure(error))
      }
      return
    }
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      completion(.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
      return
    }
    guard let data = data else {
      completion(.failure(NSError(domain: "No data", code: 0, userInfo: nil)))
      return
    }
    if let content = String(data: data, encoding: .utf8) {
      completion(.success(content))
    } else {
      completion(.failure(NSError(domain: "Unable to parse data", code: 0, userInfo: nil)))
    }
  }
  task.resume()
}

func getTopLevel(from url: String) -> String? {
  if !url.contains(".") {
    return nil
  }
  
  let noScheme: String
  if url.hasPrefix("http://")
      || url.hasPrefix("https://")
      || url.hasPrefix("file://"),
     let spd = url.split(separator: "://")[from: 1] {
    noScheme = String(spd)
  } else {
    noScheme = url
  }
  
  if let dotSpd = noScheme.split(separator: "/").first {
    let specialCharacters: [Character] = ["/", "."]
    if let splashSpd = dotSpd.split(separator: ".").last, let colonSpd = splashSpd.split(separator: ":").first {
      if !colonSpd.contains(specialCharacters) {
        return String(colonSpd)
      }
    }
  }
  return nil
}

func parseMediasFromHTML(_ htmlContent: String, baseURL: URL) -> FullMediaList {
  do {
    let document = try SwiftSoup.parse(htmlContent)
    
    let webSuffixList = [".html", ".htm", ".php", ".xhtml"]
    
    var imageURLs = [URL]()
    var videoURLs = [URL]()
    var audioURLs = [URL]()
    
    // This code snippet is from https://github.com/Darock-Studio/Watch-Browser (MODIFIED)
    // WindowsMEMZ specially licensed this snippet to Project Iris under Unlicense License.
    // If you planned to use this code snippet in any other project,
    // you MUST compliance with the original license of Project Iris
    // (not Unlicense License).
    let videos = try document.body()?.select("video")
    if let videos {
      var srcs = [String]()
      for video in videos {
        var src = try video.attr("src")
        if src.isEmpty, let tagSrc = try? video.select("source") {
          src = try tagSrc.attr("src")
        }
        if !src.isEmpty {
          if src.hasPrefix("/") {
            if baseURL.absoluteString.split(separator: "/").count < 2 {
              continue
            }
            src = "http://" + baseURL.absoluteString.split(separator: "/")[1] + src
          } else if !src.hasPrefix("http://") && !src.hasPrefix("https://") {
            var currentUrlCopy = baseURL.absoluteString
            if webSuffixList.contains(where: { element in currentUrlCopy.hasSuffix(element) }) {
              if currentUrlCopy.split(separator: "/").count < 2 {
                continue
              }
              currentUrlCopy = currentUrlCopy.components(separatedBy: "/").dropLast().joined(separator: "/")
            }
            if !currentUrlCopy.hasSuffix("/") {
              currentUrlCopy += "/"
            }
            src = currentUrlCopy + src
          }
          srcs.append(src)
        }
      }
      videoURLs = srcs.compactMap { URL(string: $0) }
    }
    let iframeVideos = try document.body()?.select("iframe")
    if let iframeVideos {
      var srcs = [String]()
      for video in iframeVideos {
        var src = try video.attr("src")
        if src != "" && (src.hasSuffix(".mp4") || src.hasSuffix(".m3u8")) {
          if src.split(separator: "://").count >= 2 && !src.hasPrefix("http://") && !src.hasPrefix("https://") {
            src = "https://" + src.split(separator: "://").last!
          } else if src.hasPrefix("/") {
            if baseURL.absoluteString.split(separator: "/").count < 2 {
              continue
            }
            src = "https://" + baseURL.absoluteString.split(separator: "/")[1] + src
          }
          srcs.append(src)
        }
      }
      videoURLs += srcs.compactMap { URL(string: $0) }
    }
    let aLinks = try document.body()?.select("a")
    if let aLinks {
      var srcs = [String]()
      for video in aLinks {
        var src = try video.attr("href")
        if src != "" && (src.hasSuffix(".mp4") || src.hasSuffix(".m3u8")) {
          if src.split(separator: "://").count >= 2 && !src.hasPrefix("http://") && !src.hasPrefix("https://") {
            src = "https://" + src.split(separator: "://").last!
          } else if src.hasPrefix("/") {
            if baseURL.absoluteString.split(separator: "/").count < 2 {
              continue
            }
            src = "https://" + baseURL.absoluteString.split(separator: "/")[1] + src
          }
          srcs.append(src)
        }
      }
      videoURLs += srcs.compactMap { URL(string: $0) }
    }
    let images = try document.body()?.select("img")
    if let images {
      var srcs = [String]()
      for image in images {
        var src = try image.attr("src")
        if src != "" {
          if src.hasPrefix("/") {
            if baseURL.absoluteString.split(separator: "/").count < 2 {
              continue
            }
            src = "http://" + baseURL.absoluteString.split(separator: "/")[1] + src
          } else if !src.hasPrefix("http://") && !src.hasPrefix("https://") {
            var currentUrlCopy = baseURL.absoluteString
            if webSuffixList.contains(where: { element in currentUrlCopy.hasSuffix(element) }) {
              if currentUrlCopy.split(separator: "/").count < 2 {
                continue
              }
              currentUrlCopy = currentUrlCopy.components(separatedBy: "/").dropLast().joined(separator: "/")
            }
            if !currentUrlCopy.hasSuffix("/") {
              currentUrlCopy += "/"
            }
            src = currentUrlCopy + src
          }
          srcs.append(src)
        }
      }
      imageURLs = srcs.compactMap { URL(string: $0) }
    }
    let audios = try document.body()?.select("audio")
    if let audios {
      var srcs = [String]()
      for audio in audios {
        var src = try audio.attr("src")
        if src != "" {
          if src.hasPrefix("/") {
            if baseURL.absoluteString.split(separator: "/").count < 2 {
              continue
            }
            src = "http://" + baseURL.absoluteString.split(separator: "/")[1] + src
          } else if !src.hasPrefix("http://") && !src.hasPrefix("https://") {
            var currentUrlCopy = baseURL.absoluteString
            if webSuffixList.contains(where: { element in currentUrlCopy.hasSuffix(element) }) {
              if currentUrlCopy.split(separator: "/").count < 2 {
                continue
              }
              currentUrlCopy = currentUrlCopy.components(separatedBy: "/").dropLast().joined(separator: "/")
            }
            if !currentUrlCopy.hasSuffix("/") {
              currentUrlCopy += "/"
            }
            src = currentUrlCopy + src
          }
          srcs.append(src)
        }
      }
      audioURLs = srcs.compactMap { URL(string: $0) }
    }
    
    //MARK: IMPORTANT
//    print("Images:", fullImageUrls)
//    print("Videos:", fullVideoUrls)
//    print("Audios:", fullAudioUrls)
    return .init(images: imageURLs, videos: videoURLs, audios: audioURLs)
  } catch {
    return .init()
  }
}

struct FullMediaList {
  var images: [URL]
  var videos: [URL]
  var audios: [URL]
  
  var isEmpty: Bool {
    images.isEmpty && videos.isEmpty && audios.isEmpty
  }
}
extension FullMediaList {
  init() {
    images = []
    videos = []
    audios = []
  }
}

func getMediaCompleteURL(_ base: URL, _ relativePath: String) -> URL? {
  return URL(string: relativePath, relativeTo: base)?.absoluteURL
}

func arraySafeAccess<T>(_ array: Array<T>, element: Int, defaultAs: T? = nil) -> T? {
  //This function avoids index out of range error when accessing a range.
  //If out, then it will return nil instead of throwing an error.
  //Normally it will just return the content, but in optional.
  if element >= array.count || element < 0 { //Index out of range
    return defaultAs
  } else { //Index in range
    //    print(array)
    //    print(element)
    return array[element]
  }
}

func getDocumentsDirectory() -> URL {
  let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
  return paths[0]
}

func readPlainTextFile(_ fileName: String) -> String {
  do {
    let fileData = try Data(contentsOf: getDocumentsDirectory().appendingPathComponent(fileName))
    let fileContent = String(decoding: fileData, as: UTF8.self)
    return fileContent
  } catch {
    return "error"
  }
}

func writePlainTextFile(_ content: String, to: String) {
  do {
    let fileURL = getDocumentsDirectory().appendingPathComponent(to)
    try content.write(to: fileURL, atomically: true, encoding: .utf8)
  } catch {
    print(error)
  }
}

func readDataFile(_ fileName: String) -> Data? {
  do {
    let fileData = try Data(contentsOf: getDocumentsDirectory().appendingPathComponent(fileName))
    return fileData
  } catch {
    print(error)
    return nil
  }
}

func writeDataFile(_ content: Data, to: String) {
  do {
    let fileURL = getDocumentsDirectory().appendingPathComponent(to)
    try content.write(to: fileURL)
  } catch {
    print(error)
  }
}

struct DismissButton<L: View>: View {
  var action: () -> Void
  var label: () -> L
  var doDismiss: Bool = true
  @Environment(\.dismiss) var dismiss
  var body: some View {
    Button(action: {
      action()
      if doDismiss {
        dismiss()
      }
    }, label: {
      label()
    })
  }
}

func getSettingsForAppdiagnose(dataProcessor: (inout [String: Any]) -> Void = { _ in }) -> String? {
  let prefPath = NSHomeDirectory() + "/Library/Preferences/\(Bundle.main.infoDictionary?["CFBundleIdentifier"] as! String).plist"
  if let plistData = FileManager.default.contents(atPath: prefPath) {
    do {
      if var plistObject = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
        dataProcessor(&plistObject)
        let jsonData = try JSONSerialization.data(withJSONObject: plistObject)
        return String(decoding: jsonData, as: UTF8.self)
      }
    } catch {
      print(error)
    }
  }
  return nil
}

//func getSettingsValuesFromPlist() -> String? {
//  let correctPasscode = UserDefaults.standard.string(forKey: "correctPasscode") ?? ""
//  let prefPath = NSHomeDirectory() + "/Library/Preferences/\(Bundle.main.infoDictionary?["CFBundleIdentifier"] as! String).plist"
//  do {
//    var result = try String(contentsOfFile: prefPath, encoding: .utf8)
////    if !correctPasscode.isEmpty {
////      result = result.replacingOccurrences(of: correctPasscode, with: "")
////    }
////    print("11111")
//    print(result)
//    return result
//  } catch {
//    print(error)
//  }
//  return nil
//}

//func getSettingsValuesFromPlist() -> String? {
//  guard let bundleID = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String else {
//    print("无法获取 CFBundleIdentifier")
//    return nil
//  }
//  
//  // 更稳妥地获取 Preferences plist 路径
//  let prefPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
//    .appendingPathComponent("Preferences/\(bundleID).plist").path ?? ""
//  
//  do {
//    var result = try String(contentsOfFile: prefPath, encoding: .utf8)
//    if let correctPasscode = UserDefaults.standard.string(forKey: "correctPasscode"), !correctPasscode.isEmpty {
//      result = result.replacingOccurrences(of: correctPasscode, with: "REDACTED") // 避免暴露敏感数据
//    }
//    print(result)
//    return result
//  } catch {
//    print("读取文件失败:", error)
//  }
//  
//  return nil
//}


func getStorageDictionary() -> [String: Any]? {
  let prefPath = NSHomeDirectory() + "/Library/Preferences/\(Bundle.main.infoDictionary?["CFBundleIdentifier"] as! String).plist"
  if let plistData = FileManager.default.contents(atPath: prefPath) {
    do {
      if var plistObject = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
        return plistObject
      }
    } catch {
      print(error)
    }
  }
  return nil
}

extension String {
  func urlEncoded() -> String {
    let encodeUrlString = self.addingPercentEncoding(withAllowedCharacters:
        .urlQueryAllowed)
    return encodeUrlString ?? ""
  }
  
  func urlDecoded() -> String {
    return self.removingPercentEncoding ?? ""
  }
  
  func isURL() -> Bool {
    if self.contains("site:") {
      return false
    }
    
    var topLevelDomainList = (try! String(contentsOf: Bundle.main.url(forResource: "TopLevelDomainList", withExtension: "txt")!, encoding: .utf8))
      .split(separator: "\n")
      .map { String($0) }
    topLevelDomainList.removeAll(where: { str in str.hasPrefix("#") || str.isEmpty })
    if let topLevel = getTopLevel(from: self), topLevelDomainList.contains(topLevel.uppercased().replacingOccurrences(of: " ", with: "")) {
      return true
    } else if self.hasPrefix("http://") || self.hasPrefix("https://") {
      return true
    } else if self.components(separatedBy: ".").count == 4 {
      var components = self.components(separatedBy: ".")
      if components[3].components(separatedBy: ":").count == 2 {
        if (Int(components[3].components(separatedBy: ":")[1]) ?? 999) > 65535 {
          return false
        }
        components[3] = components[3].components(separatedBy: ":")[0]
      }
      for i in 0...3 {
        if (Int(components[i]) ?? 266) > 255 {
          return false
        }
      }
      return true
    } else {
      return false
    }
  }
  
  func numberOfOccurrencesOf(_ string: String) -> Int {
    let theArray = self.components(separatedBy: string)
    return theArray.count - 1
  }
}

extension Array {
  subscript(from index: Int) -> Element? {
    return self.indices ~= index ? self[index] : nil
  }
}

extension Color {
  func HSB_values() -> (Int, Int, Int, CGFloat) {
    let color = UIColor(self)
    var hue: CGFloat = -1
    var saturation: CGFloat = -1
    var brightness: CGFloat = -1
    var opacity: CGFloat = -1
    _ = color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &opacity)
    return (Int(hue*359), Int(saturation*100), Int(brightness*100), opacity)
  }
}

public func getSearchingKeywordFromURL(source: String) -> String? {
  //Initialization
  var engineLinks: [String] = defaultSearchEngineLinks as! [String]
  engineLinks = (UserDefaults.standard.array(forKey: "engineLinks") ?? defaultSearchEngineLinks) as! [String]
  engineLinks.append("https://cn.bing.com/search?q=")
  var output: String? = nil
  
  //Get URL with domain and keyword only
  let splittedSource = source.split(separator: "&").first
  
  //Check through every engine
  for i in 0..<engineLinks.count {
    //Keep domain and keywords before \\iris only
    engineLinks[i] = removeSubstringAndAfter(mainString: engineLinks[i].lowercased(), substring: "\\iris")
    
    //If engine matches the URL
    if source.hasPrefix(engineLinks[i]) {
      //Remove the domain and prefix
      output = source
      output?.removeFirst(engineLinks[i].count)
      
      //And decode the keyword
      output = output?.urlDecoded()
      break
    }
  }
  return output
}

func removeSubstringAndAfter(mainString: String, substring: String) -> String {
    if let range = mainString.range(of: substring) {
        let startIndex = range.lowerBound
        return String(mainString[..<startIndex])
    }
    return mainString
}

import Foundation
import SwiftUI
import Observation
import AppKit
import Security
internal import UniformTypeIdentifiers

struct KeychainHelper {
    static let service = "com.apple.ARDInspectorModern.masterpassword"
    static let account = "masterPassword"

    static func save(password: String) {
        let passwordData = password.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

@Observable
class ARDViewModel {
    var items: [ARDItem] = []
    var computers: [String: ARDComputer] = [:]
    var selectedId: String?
    var isPasswordPromptShowing = false
    var masterPassword = ""
    var shouldSavePassword = false
    var isLoading = false
    var errorMessage: String?
    
    var expandedItems: Set<String> = []
    
    var selectedComputer: ARDComputer? {
        guard let id = selectedId else { return nil }
        return computers[id]
    }
    
    func loadPreferences(from url: URL? = nil) async {
        isLoading = true
        errorMessage = nil
        
        var targetURL: URL?
        var bookmarkWasStale = false
        
        if let url = url {
            targetURL = url
        } else if let (bookmarkURL, isStale) = loadBookmark() {
            targetURL = bookmarkURL
            bookmarkWasStale = isStale
        } else {
            targetURL = await pickPlistFile()
            if let pickedURL = targetURL {
                saveBookmark(for: pickedURL)
            }
        }
        
        guard let finalURL = targetURL else {
            self.errorMessage = "No preferences file selected."
            isLoading = false
            return
        }
        
        if bookmarkWasStale {
            saveBookmark(for: finalURL)
        }
        
        let isSecurityScoped = finalURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                finalURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: finalURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] ?? [:]
            
            let decodedPreferences = try ARDDecoder.decodePreferences(preferences: plist, masterPassword: masterPassword)
            
            self.items = parsePreferences(decodedPreferences)
            
            if shouldSavePassword && !masterPassword.isEmpty {
                KeychainHelper.save(password: masterPassword)
            }
        } catch {
            self.errorMessage = "Error loading preferences: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func attemptAutoLogin() async {
        if let savedPassword = KeychainHelper.load() {
            self.masterPassword = savedPassword
            self.shouldSavePassword = true
            await loadPreferences()
            
            if errorMessage == nil {
                // Success! No need to show password prompt
                return
            } else {
                // Failed with saved password, show prompt
                isPasswordPromptShowing = true
            }
        } else {
            isPasswordPromptShowing = true
        }
    }
    
    func resetPasswordPrompt() {
        masterPassword = ""
        isPasswordPromptShowing = true
    }
    
    private func pickPlistFile() async -> URL? {
        await MainActor.run {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = false
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.title = "Select ARD Preferences File"
            panel.message = "Please select the com.apple.RemoteDesktop.plist file.  If not here, try ~/Library/Preferences"
            panel.prompt = "Open"
            panel.allowedContentTypes = [.propertyList]
            
            let fm = FileManager.default
//            let containerPath = NSString(string: "~/Library/Containers/com.apple.RemoteDesktop/Data/Library/Preferences").expandingTildeInPath
//            let containerURL = URL(fileURLWithPath: containerPath)
            
//            if fm.fileExists(atPath: containerPath) {
//                panel.directoryURL = containerURL
//            } else if let libraryURL = fm.urls(for: .libraryDirectory, in: .userDomainMask).first {
//                panel.directoryURL = libraryURL.appendingPathComponent("Preferences")
//            }
            if let libraryURL = fm.urls(for: .libraryDirectory, in: .userDomainMask).first {
                panel.directoryURL = libraryURL.appendingPathComponent("Containers/com.apple.RemoteDesktop/Data/Library/Preferences")
            }
            
            if panel.runModal() == .OK {
                return panel.url
            }
            return nil
        }
    }
    
    private func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "ARDPlistBookmark")
            print("Successfully saved security-scoped bookmark")
        } catch {
            print("Error saving bookmark: \(error)")
        }
    }
    
    private func loadBookmark() -> (URL, Bool)? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "ARDPlistBookmark") else {
            print("No bookmark found in UserDefaults")
            return nil
        }
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            print("Successfully loaded bookmark. Stale: \(isStale)")
            return (url, isStale)
        } catch {
            print("Error resolving bookmark: \(error)")
            return nil
        }
    }
    
    private func parsePreferences(_ prefs: [String: Any]) -> [ARDItem] {
        let computerDatabase = prefs["ComputerDatabase"] as? [[String: Any]] ?? []
        let listDatabase = prefs["ListDatabase"] as? [[String: Any]] ?? []
        let objectList = prefs["ObjectList"] as? [[String: Any]] ?? []
        
        let allCredentials = prefs["accessCredentials"] as? [String: Any]
        
        var computersMap: [String: ARDComputer] = [:]
        for dict in computerDatabase {
            let uuid: String
            if let u = dict["uuid"] as? String {
                uuid = u
            } else if let u = dict["uuid"] {
                uuid = "\(u)"
            } else {
                uuid = "Unknown"
            }
            
            var computer = ARDComputer(dict: dict)
            
            if let credentials = allCredentials?[uuid] as? [String: Any] {
                computer = computer.updatingCredentials(
                    login: credentials["login"] as? String,
                    password: credentials["password"] as? String
                )
            }
            computersMap[uuid] = computer
        }
        
        self.computers = computersMap
        
        var lists: [String: ARDList] = [:]
        for dict in listDatabase {
            let uuid: String
            if let u = dict["uuid"] as? String {
                uuid = u
            } else if let u = dict["uuid"] {
                uuid = "\(u)"
            } else {
                uuid = "Unknown"
            }
            
            let members = dict["items"] as? [String] ?? []
            lists[uuid] = ARDList(id: uuid, name: dict["listName"] as? String ?? "Unknown List", members: members)
        }
        
        var finalItems: [ARDItem] = []
        
        let allComputers = computersMap.values.sorted { $0.name < $1.name }.map { $0 }
        let allComputersList = ARDList(id: "all", name: "All Computers", members: allComputers.map { $0.id })
        finalItems.append(.list(allComputersList))
        
        for obj in objectList {
            let name = obj["name"] as? String ?? "Unknown"
            let members = obj["members"] as? [String] ?? []
            
            finalItems.append(.folder(ARDFolder(id: name, name: name, members: members)))
        }
        
        let folderMemberIds = Set(objectList.flatMap { $0["members"] as? [String] ?? [] })
        for (uuid, list) in lists {
            if !folderMemberIds.contains(uuid) {
                finalItems.append(.list(list))
            }
        }
        
        return finalItems
    }
}

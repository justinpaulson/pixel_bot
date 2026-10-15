import Capacitor
import Security
import UIKit

@objc(PixelBridgeViewController)
class PixelBridgeViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(PixelVaultPlugin())
        webView?.scrollView.bounces = false
    }
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
}

@objc(PixelVaultPlugin)
class PixelVaultPlugin: CAPPlugin, CAPBridgedPlugin {
    let identifier = "PixelVaultPlugin"
    let jsName = "PixelVault"
    let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "get", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "set", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "clear", returnType: CAPPluginReturnPromise)
    ]
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.lillybitgames.pixel.session",
         kSecAttrAccount as String: "player"]
    }
    @objc func get(_ call: CAPPluginCall) {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecItemNotFound { call.resolve(); return }
        guard status == errSecSuccess, let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            call.reject("Could not read player session."); return
        }
        call.resolve(["value": value])
    }
    @objc func set(_ call: CAPPluginCall) {
        guard let value = call.getString("value"), let data = value.data(using: .utf8) else {
            call.reject("Missing session."); return
        }
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        if status == errSecSuccess { call.resolve() }
        else { call.reject("Could not save player session.") }
    }
    @objc func clear(_ call: CAPPluginCall) {
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound { call.resolve() }
        else { call.reject("Could not clear player session.") }
    }
}

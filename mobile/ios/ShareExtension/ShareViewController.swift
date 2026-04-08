import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private let appGroupId = "group.co.openvine.app"
    private let sharedKey = "SharedVideoPath"

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleSharedVideo()
    }

    private func handleSharedVideo() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            close()
            return
        }

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.movie.identifier) { [weak self] item, error in
                        guard let url = item as? URL else {
                            self?.close()
                            return
                        }
                        self?.saveAndOpenApp(videoUrl: url)
                    }
                    return
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.mpeg4Movie.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.mpeg4Movie.identifier) { [weak self] item, error in
                        guard let url = item as? URL else {
                            self?.close()
                            return
                        }
                        self?.saveAndOpenApp(videoUrl: url)
                    }
                    return
                }
            }
        }

        close()
    }

    private func saveAndOpenApp(videoUrl: URL) {
        guard let containerUrl = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            close()
            return
        }

        let sharedDir = containerUrl.appendingPathComponent("shared_imports", isDirectory: true)
        try? FileManager.default.createDirectory(at: sharedDir, withIntermediateDirectories: true)

        let fileName = "\(UUID().uuidString).mp4"
        let destUrl = sharedDir.appendingPathComponent(fileName)

        do {
            try FileManager.default.copyItem(at: videoUrl, to: destUrl)
        } catch {
            close()
            return
        }

        let userDefaults = UserDefaults(suiteName: appGroupId)
        userDefaults?.set(destUrl.path, forKey: sharedKey)
        userDefaults?.synchronize()

        let urlString = "divine://import?path=\(destUrl.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        DispatchQueue.main.async { [weak self] in
            guard let url = URL(string: urlString) else {
                self?.close()
                return
            }
            self?.openURL(url)
            self?.close()
        }
    }

    @objc private func openURL(_ url: URL) {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let r = responder {
            if r.responds(to: selector) {
                r.perform(selector, with: url)
                return
            }
            responder = r.next
        }
    }

    private func close() {
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}

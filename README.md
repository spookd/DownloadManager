Simple download manager made in Swift using `NSURLConnection`. Not much to explain.

# Usage

Add the source files, the project or the compiled framework to your project. Then, it's as simple as this:

```swift
class Dummy: DownloadManagerDelegate {

    init() {
        let downloadDirectory = let documentsDirectory = (NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! NSString).stringByAppendingPathComponent("Downloads")

        let url  = NSURL(string: "http://burnbit.com/download/353474/enwiki_20150403_pages_articles_xml_bz2")
        let path = downloadDirectory.stringByAppendingPathComponent("wiki-pages-articles-xml.bz2")

        DownloadManager.sharedInstance.subscribe(self)
        DownloadManager.sharedInstance.download(url, filePath: path)
    }

    deinit {
        DownloadManager.sharedInstance.unsubscribe(self)
    }

}

extension Dummy {

    func downloadManager(downloadManager: DownloadManager, downloadDidFail url: NSURL, error: NSError) {
        println("Failed to download: \(url.absoluteString)")
    }

    func downloadManager(downloadManager: DownloadManager, downloadDidStart url: NSURL, resumed: Bool) {
        println("Started to download: \(url.absoluteString)")
    }
    
    func downloadManager(downloadManager: DownloadManager, downloadDidFinish url: NSURL) {
        println("Finished downloading: \(url.absoluteString)")
    }
    
    func downloadManager(downloadManager: DownloadManager, downloadDidProgress url: NSURL, totalSize: UInt64, downloadedSize: UInt64, percentage: Double, averageDownloadSpeedInBytes: UInt64, timeRemaining: NSTimeInterval) {
        println("Downloading \(url.absoluteString) (Percentage: \(percentage))")
    }
    
}
```

# Quick overview

## DownloadManager
```swift
public class DownloadManager {
    public class var sharedInstance: DownloadManager { /* ... */ }
    
    public func subscribe(delegate: DownloadManagerDelegate) { /* ... */ }
    public func unsubscribe(delegate: DownloadManagerDelegate) { /* ... */ }
    public func isDownloading(url: NSURL) -> Bool { /* ... */ }
    public func download(url: NSURL, filePath: String) -> Bool { /* ... */ }
    public func stopDownloading(url: NSURL) { /* ... */ }
}
```

## DownloadManagerDelegate
```swift
public protocol DownloadManagerDelegate: class {
    func downloadManager(downloadManager: DownloadManager, downloadDidFail url: NSURL, error: NSError)
    func downloadManager(downloadManager: DownloadManager, downloadDidStart url: NSURL, resumed: Bool)
    func downloadManager(downloadManager: DownloadManager, downloadDidFinish url: NSURL)
    func downloadManager(downloadManager: DownloadManager, downloadDidProgress url: NSURL, totalSize: UInt64, downloadedSize: UInt64, percentage: Double, averageDownloadSpeedInBytes: UInt64, timeRemaining: NSTimeInterval)
}
```
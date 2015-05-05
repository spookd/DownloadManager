//
//  DownloadManager.swift
//  DownloadManager
//
//  Created by Nicolai Persson on 05/05/15.
//  Copyright (c) 2015 Sprinkle. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

public protocol DownloadManagerDelegate: class {
    func downloadManager(downloadManager: DownloadManager, downloadDidFail url: NSURL, error: NSError)
    func downloadManager(downloadManager: DownloadManager, downloadDidStart url: NSURL, resumed: Bool)
    func downloadManager(downloadManager: DownloadManager, downloadDidFinish url: NSURL)
    func downloadManager(downloadManager: DownloadManager, downloadDidProgress url: NSURL, totalSize: UInt64, downloadedSize: UInt64, percentage: Double, averageDownloadSpeedInBytes: UInt64, timeRemaining: NSTimeInterval)
}

public class DownloadManager: NSObject, NSURLConnectionDataDelegate {
    
    internal let queue = dispatch_queue_create("io.persson.DownloadManager", DISPATCH_QUEUE_CONCURRENT)
    
    internal var delegates: [DownloadManagerDelegate] = []
    internal var downloads: [Download] = []
    
}

// MARK: Static vars

extension DownloadManager {
    
    public class var sharedInstance: DownloadManager {
        struct Singleton {
            static let instance = DownloadManager()
        }
        
        return Singleton.instance
    }
    
}

// MARK: Internal methods

extension DownloadManager {
    
    internal func downloadForConnection(connection: NSURLConnection) -> Download? {
        var result: Download? = nil
        
        sync {
            for download in self.downloads {
                if download.connection == connection {
                    result = download
                    break
                }
            }
        }
        
        return result
    }
    
    internal func sync(closure: () -> Void) {
        dispatch_sync(self.queue, closure)
    }
    
    internal func async(closure: () -> Void) {
        dispatch_async(self.queue, closure)
    }
    
}

// MARK: Public methods

extension DownloadManager {
    
    public func subscribe(delegate: DownloadManagerDelegate) {
        async {
            for (index, d) in enumerate(self.delegates) {
                if delegate === d {
                    return
                }
            }
            
            self.delegates.append(delegate)
        }
    }
    
    public func unsubscribe(delegate: DownloadManagerDelegate) {
        async {
            for (index, d) in enumerate(self.delegates) {
                if delegate === d {
                    self.delegates.removeAtIndex(index)
                    return
                }
            }
        }
    }
    
    public func isDownloading(url: NSURL) -> Bool {
        var result = false
        
        sync {
            for download in self.downloads {
                if download.url == url {
                    result = true
                    break
                }
            }
        }
        
        return result
    }
    
    public func download(url: NSURL, filePath: String) -> Bool {
        var request = NSMutableURLRequest(URL: url)
        
        if let dict: NSDictionary = NSFileManager.defaultManager().attributesOfItemAtPath(filePath, error: nil) {
            request.addValue("bytes=\(dict.fileSize())-", forHTTPHeaderField: "Range")
        }
        
        if let connection = NSURLConnection(request: request, delegate: self, startImmediately: false) {
            sync {
                self.downloads.append(Download(url: url, filePath: filePath, totalSize: 0, connection: connection))
            }
            
            connection.scheduleInRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
            connection.start()
            
            return true
        }
        
        return false
    }
    
    public func stopDownloading(url: NSURL) {
        sync {
            for download in self.downloads {
                if download.url == url {
                    download.connection.cancel()
                    download.close()
                    
                    self.downloads.remove(download)
                    
                    break
                }
            }
        }
    }
    
    func applicationWillTerminate() {
        sync {
            for download in self.downloads {
                download.connection.cancel()
                download.close()
            }
        }
    }
    
}

// MARK: Public methods

extension DownloadManager {
    
    public func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        if let download = self.downloadForConnection(connection) {
            let contentLength = response.expectedContentLength
            
            download.totalSize = contentLength == -1 ? 0 : UInt64(contentLength) + download.downloadedSize
            
            sync {
                for delegate in self.delegates {
                    delegate.downloadManager(self, downloadDidStart: download.url, resumed: download.totalSize > 0)
                }
            }
        }
    }
    
    public func connection(connection: NSURLConnection, didReceiveData data: NSData) {
        if let download = self.downloadForConnection(connection) {
            var percentage: Double = 0
            var remaining: NSTimeInterval = NSTimeInterval.NaN
            
            sync {
                download.write(data)
                download.downloadedSize += UInt64(data.length)
                
                if download.totalSize > 0 {
                    percentage = Double(download.downloadedSize) / Double(download.totalSize)
                    
                    if download.averageDownloadSpeed != UInt64.max {
                        if download.averageDownloadSpeed == 0 {
                            remaining = NSTimeInterval.infinity
                        } else {
                            remaining = NSTimeInterval((download.totalSize - download.downloadedSize) / download.averageDownloadSpeed)
                        }
                    }
                }
                
                for delegate in self.delegates {
                    delegate.downloadManager(
                        self,
                        downloadDidProgress:         download.url,
                        totalSize:                   download.totalSize,
                        downloadedSize:              download.downloadedSize,
                        percentage:                  percentage,
                        averageDownloadSpeedInBytes: download.averageDownloadSpeed,
                        timeRemaining:               remaining
                    )
                }
            }
        }
    }
    
    public func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        if let download = self.downloadForConnection(connection) {
            sync {
                for delegate in self.delegates {
                    delegate.downloadManager(self, downloadDidFail: download.url, error: error)
                }
                
                download.close()
                
                self.downloads.remove(download)
            }
        }
    }
    
    public func connectionDidFinishLoading(connection: NSURLConnection) {
        if let download = self.downloadForConnection(connection) {
            sync {
                for delegate in self.delegates {
                    delegate.downloadManager(self, downloadDidFinish: download.url)
                }
                
                download.close()
                
                self.downloads.remove(download)
            }
        }
    }
    
}
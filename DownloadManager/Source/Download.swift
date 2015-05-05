//
//  Download.swift
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

func ==(left: Download, right: Download) -> Bool {
    return left.url == right.url
}

class Download: Equatable {
    
    let url:      NSURL
    let filePath: String
    
    let stream:     NSOutputStream
    let connection: NSURLConnection
    
    var totalSize: UInt64
    var downloadedSize: UInt64 = 0
    
    // Variables used for calculating average download speed
    // The lower the interval (downloadSampleInterval) the higher the accuracy (fluctuations)
    
    internal let sampleInterval       = 0.25
    internal let sampledSecondsNeeded = 5.0
    
    internal lazy var sampledBytesTotal: Int = {
        return Int(ceil(self.sampledSecondsNeeded / self.sampleInterval))
    }()
    
    internal var samples: [UInt64] = []
    internal var sampleTimer: Timer?
    internal var lastAverageCalculated = NSDate()
    
    internal var bytesWritten = 0
    internal let queue = dispatch_queue_create("dk.dr.radioapp.DownloadManager.SampleQueue", DISPATCH_QUEUE_CONCURRENT)
    
    var averageDownloadSpeed: UInt64 = UInt64.max
    
    init(url: NSURL, filePath: String, totalSize: UInt64, connection: NSURLConnection) {
        dispatch_set_target_queue(self.queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0))
        
        self.url       = url
        self.filePath  = filePath
        self.totalSize = totalSize
        
        if let dict: NSDictionary = NSFileManager.defaultManager().attributesOfItemAtPath(self.filePath, error: nil) {
            self.downloadedSize = dict.fileSize()
        }
        
        self.stream     = NSOutputStream(toFileAtPath: self.filePath, append: self.downloadedSize > 0)!
        self.connection = connection
        
        self.stream.scheduleInRunLoop(NSRunLoop.mainRunLoop(), forMode: NSDefaultRunLoopMode)
        self.stream.open()
        
        self.sampleTimer?.invalidate()
        self.sampleTimer = Timer(interval: self.sampleInterval, repeats: true, pauseInBackground: true, block: { [weak self] () -> () in
            if let strongSelf = self {
                dispatch_sync(strongSelf.queue, { () -> Void in
                    strongSelf.samples.append(UInt64(strongSelf.bytesWritten))
                    
                    let diff = strongSelf.samples.count - strongSelf.sampledBytesTotal
                    
                    if diff > 0 {
                        for i in (0...diff - 1) {
                            strongSelf.samples.removeAtIndex(0)
                        }
                    }
                    
                    strongSelf.bytesWritten = 0
                    
                    let now = NSDate()
                    
                    if now.timeIntervalSinceDate(strongSelf.lastAverageCalculated) >= 5 && strongSelf.samples.count >= strongSelf.sampledBytesTotal {
                        var totalBytes: UInt64 = 0
                        
                        for sample in strongSelf.samples {
                            totalBytes += sample
                        }
                        
                        strongSelf.averageDownloadSpeed  = UInt64(round(Double(totalBytes) / strongSelf.sampledSecondsNeeded))
                        strongSelf.lastAverageCalculated = now
                    }
                })
            }
        })
    }
    
    func write(data: NSData) {
        let written = self.stream.write(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
        
        if written > 0 {
            dispatch_async(self.queue, { () -> Void in
                self.bytesWritten += written
            })
        }
    }
    
    func close() {
        self.sampleTimer?.invalidate()
        self.sampleTimer = nil
        
        self.stream.close()
    }
    
}
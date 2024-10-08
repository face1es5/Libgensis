//
//  Downloader.swift
//  Libgenesis
//
//  Created by Fish on 5/9/2024.
//

import Foundation

/// Book downloader, hold download queue
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published private(set) var downloadTasks: [DownloadTask] = []
    private let downloadTaskQueue = DispatchQueue(label: "com.F1sh.downloadmanager.taskqueue", qos: .background)
    private let condition = NSCondition()
    
    private init() {
        starting()
    }
    
    /// Download book from url **targetURL**.
    ///
    func download(_ targetURL: URL, book: BookItem) {
        addDownloadTask(DownloadTask(targetURL, book: book))
    }
    
    /// Download a list of books.
    func download(_ books: [BookItem]) {
        addDownloadTasks(
            books.compactMap { DownloadTask($0) }
        )
    }
    
    /// Download book from random server, could fail.
    ///
    /// If no download link available, emit this task.
    func download(_ book: BookItem) {
        guard
            let dtask = DownloadTask(book)
        else {
            print("Invalid download task of \(book.truncTitle), check url")
            return
        }
        addDownloadTask(dtask)
    }
    
    /// TODO: Download selected book.
    ///
    func downloadSelected() {
        fatalError("Implement download selected book globally.")
    }
    
    /// Add a list of tasks.
    func addDownloadTasks(_ dtasks: [DownloadTask]) {
        condition.lock()
        downloadTasks += dtasks
        condition.unlock()
        condition.signal()
    }
    
    /// Add tasks.
    func addDownloadTask(_ dtask: DownloadTask) {
        condition.lock()
        downloadTasks.append(dtask)
        condition.unlock()
        condition.signal()
    }
    
    /// Remove task.
    func removeDownloadTask(_ dtask: DownloadTask) {
        // lock lock
        condition.lock()
        downloadTasks.removeAll(where: { $0 == dtask })
        condition.unlock()
        condition.signal()
    }
    
    /// Remove tasks.
    func removeDownloadTasks(_ dtasks: [DownloadTask]) {
        // lock lock
        condition.lock()
        let taskSet = Set(dtasks)
        downloadTasks = downloadTasks.filter { !taskSet.contains($0) }
        condition.unlock()
        condition.signal()
    }
    
    /// Suspend all tasks(if in progress)
    func pauseAll() {
        // lock lock
        condition.lock()
        for dtask in downloadTasks {
            if dtask.loading {  // don't pause completed tasks.
                dtask.pause()
            }
        }
        condition.unlock()
        condition.signal()
    }
    
    /// Resume all suspended tasks.
    func resumeAll() {
        // lock lock
        condition.lock()
        for dtask in downloadTasks {
            if dtask.suspending {
                dtask.resume()
            }
        }
        condition.unlock()
        condition.signal()
    }
    
    /// Remove all tasks.
    func clear() {
        // lock lock
        condition.lock()
        // we should cancel all
        for dtask in downloadTasks {
            dtask.pause()
        }
        downloadTasks = []
        condition.unlock()
        condition.signal()
    }
    
    private func starting() {
        downloadTaskQueue.async { [weak self] in
            guard let self = self else { return }
            while(true) {
                // aquire lock and waiting for new downloading task.
                while(downloadTasks.isEmpty) {
                    condition.lock()
                    condition.wait()
                }
                guard
                    let task = downloadTasks.first(where: { $0.started == false })
                else {
                    condition.unlock()
                    continue
                }
                print("Starting download: \(task.book.title)")
                task.join()
                condition.unlock()
            }
        }
    }
}



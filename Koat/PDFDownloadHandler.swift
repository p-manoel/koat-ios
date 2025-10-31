//
//  PDFDownloadHandler.swift
//  Koat
//
//  Handles PDF downloads and presents share sheet for saving
//

import UIKit
import WebKit
import UniformTypeIdentifiers

class PDFDownloadHandler: NSObject {

    private weak var presentingViewController: UIViewController?
    private var downloadTask: URLSessionDownloadTask?
    private var progressView: UIProgressView?
    private var alertController: UIAlertController?

    init(presentingViewController: UIViewController) {
        self.presentingViewController = presentingViewController
        super.init()
    }

    func handlePDFDownload(from url: URL, cookies: [HTTPCookie]) {
        // Create URL request with cookies for authentication
        var request = URLRequest(url: url)

        // Add cookies to the request
        let cookieHeader = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")

        // Set user agent to indicate iOS app
        request.setValue("Koat iOS App", forHTTPHeaderField: "User-Agent")

        // Show download progress
        showDownloadProgress()

        // Create download task
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        downloadTask = session.downloadTask(with: request)
        downloadTask?.resume()
    }

    private func showDownloadProgress() {
        alertController = UIAlertController(title: "Baixando PDF", message: "\n\n", preferredStyle: .alert)

        // Add progress view
        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progress = 0
        self.progressView = progressView

        if let alertView = alertController?.view {
            alertView.addSubview(progressView)
            NSLayoutConstraint.activate([
                progressView.leadingAnchor.constraint(equalTo: alertView.leadingAnchor, constant: 20),
                progressView.trailingAnchor.constraint(equalTo: alertView.trailingAnchor, constant: -20),
                progressView.topAnchor.constraint(equalTo: alertView.topAnchor, constant: 70)
            ])
        }

        // Add cancel button
        alertController?.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { [weak self] _ in
            self?.downloadTask?.cancel()
        })

        presentingViewController?.present(alertController!, animated: true)
    }

    private func presentShareSheet(for fileURL: URL) {
        // Dismiss progress alert
        alertController?.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }

            // Create activity view controller for sharing/saving the PDF
            let activityViewController = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )

            // Configure for iPad
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = self.presentingViewController?.view
                popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            // Present the share sheet
            self.presentingViewController?.present(activityViewController, animated: true) {
                // Clean up temporary file after sharing
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
    }

    private func showError(_ message: String) {
        alertController?.dismiss(animated: true) { [weak self] in
            let errorAlert = UIAlertController(title: "Erro", message: message, preferredStyle: .alert)
            errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.presentingViewController?.present(errorAlert, animated: true)
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension PDFDownloadHandler: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            // Get the original filename from the response
            let response = downloadTask.response as? HTTPURLResponse
            var fileName = "documento.pdf"

            if let suggestedFilename = response?.suggestedFilename {
                fileName = suggestedFilename
            } else if let url = downloadTask.originalRequest?.url,
                      let lastPathComponent = url.pathComponents.last {
                // Extract filename from URL path
                fileName = lastPathComponent.replacingOccurrences(of: "-", with: "_") + ".pdf"
            }

            // Create a temporary directory to save the file
            let documentsPath = FileManager.default.temporaryDirectory
            let destinationURL = documentsPath.appendingPathComponent(fileName)

            // Remove existing file if it exists
            try? FileManager.default.removeItem(at: destinationURL)

            // Move the downloaded file to the destination
            try FileManager.default.moveItem(at: location, to: destinationURL)

            // Present share sheet
            DispatchQueue.main.async { [weak self] in
                self?.presentShareSheet(for: destinationURL)
            }

        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.showError("Erro ao processar o PDF: \(error.localizedDescription)")
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        DispatchQueue.main.async { [weak self] in
            self?.progressView?.progress = progress
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                self?.showError("Erro no download: \(error.localizedDescription)")
            }
        }
    }
}
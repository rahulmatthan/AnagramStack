//
//  ChainDownloadService.swift
//  AnagramStackClient
//
//  Fetches anagram chains from GitHub repository
//

import Foundation
import Combine
import SwiftUI

@MainActor
class ChainDownloadService: ObservableObject {
    static let shared = ChainDownloadService()

    @Published var isDownloading = false
    @Published var availableChains: [ChainMetadata] = []
    @Published var downloadedChains: [AnagramChain] = []

    private let manifestURL = "https://raw.githubusercontent.com/rahulmatthan/anagram-chains-data/master/manifest.json"
    private let cacheDirectory: URL
    private let manifestLastUpdatedKey = "com.anagramstack.client.manifestLastUpdated"

    init() {
        // Cache directory for downloaded chains
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsURL.appendingPathComponent("DownloadedChains")

        // Create cache directory
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Load cached chains on init
        loadCachedChains()
    }

    // MARK: - Public API

    func fetchLatestChains() async {
        print("🔄 Starting chain fetch from GitHub...")
        guard !isDownloading else {
            print("⚠️ Already downloading, skipping")
            return
        }

        isDownloading = true
        defer { isDownloading = false }

        do {
            // Fetch manifest
            print("🌐 Manifest URL: \(manifestURL)")
            guard let url = URL(string: manifestURL) else {
                print("❌ Invalid manifest URL")
                return
            }

            print("📡 Fetching manifest from GitHub...")

            // Create request with cache-busting headers
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

            let (data, _) = try await URLSession.shared.data(for: request)
            print("✅ Received \(data.count) bytes")

            let manifest = try JSONDecoder().decode(Manifest.self, from: data)
            print("📦 Found \(manifest.chains.count) chains in manifest")

            // Update available chains
            availableChains = manifest.chains

            // Force refresh cached files when manifest timestamp changes.
            let previousManifestUpdate = UserDefaults.standard.string(forKey: manifestLastUpdatedKey)
            let shouldForceRefresh = previousManifestUpdate != manifest.lastUpdated

            // Download new or refreshed chains
            for metadata in manifest.chains {
                await downloadChainIfNeeded(metadata: metadata, forceRefresh: shouldForceRefresh)
            }

            if shouldForceRefresh {
                UserDefaults.standard.set(manifest.lastUpdated, forKey: manifestLastUpdatedKey)
            }

            // Reload cached chains
            loadCachedChains()

        } catch {
            print("❌ Failed to fetch manifest: \(error)")
        }
    }

    func getAllChains() -> [AnagramChain] {
        // Combine bundled + downloaded chains
        var allChains: [AnagramChain] = []

        // Load bundled chains from Resources
        if let bundledChains = loadBundledChains() {
            allChains.append(contentsOf: bundledChains)
        }

        // Add downloaded chains
        allChains.append(contentsOf: downloadedChains)

        return allChains
    }

    // MARK: - Private Methods

    private func downloadChainIfNeeded(metadata: ChainMetadata, forceRefresh: Bool = false) async {
        let cacheURL = cacheDirectory.appendingPathComponent("\(metadata.id).json")

        // Check if already cached
        if !forceRefresh && FileManager.default.fileExists(atPath: cacheURL.path) {
            print("✅ Chain already cached: \(metadata.id)")
            return
        }

        // Download chain
        guard let url = URL(string: metadata.url) else {
            print("❌ Invalid chain URL: \(metadata.url)")
            return
        }

        do {
            // Create request with cache-busting
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let (data, _) = try await URLSession.shared.data(for: request)

            // Validate it's a valid chain
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let chain = try decoder.decode(AnagramChain.self, from: data)

            // Save to cache
            try data.write(to: cacheURL)

            print("✅ Downloaded and cached: \(metadata.id)")

        } catch {
            print("❌ Failed to download chain \(metadata.id): \(error)")
        }
    }

    private func loadCachedChains() {
        var chains: [AnagramChain] = []

        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            for fileURL in files where fileURL.pathExtension == "json" {
                if let data = try? Data(contentsOf: fileURL),
                   let chain = try? decoder.decode(AnagramChain.self, from: data) {
                    chains.append(chain)
                }
            }

            downloadedChains = chains
            print("✅ Loaded \(chains.count) cached chains")

        } catch {
            print("❌ Failed to load cached chains: \(error)")
        }
    }

    private func loadBundledChains() -> [AnagramChain]? {
        guard let bundleURL = Bundle.main.url(forResource: "chains", withExtension: nil) else {
            print("⚠️ No bundled chains folder")
            return nil
        }

        var chains: [AnagramChain] = []

        do {
            let files = try FileManager.default.contentsOfDirectory(at: bundleURL, includingPropertiesForKeys: nil)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            for fileURL in files where fileURL.pathExtension == "json" {
                if let data = try? Data(contentsOf: fileURL),
                   let chain = try? decoder.decode(AnagramChain.self, from: data) {
                    chains.append(chain)
                }
            }

            print("✅ Loaded \(chains.count) bundled chains")
            return chains

        } catch {
            print("❌ Failed to load bundled chains: \(error)")
            return nil
        }
    }
}

// MARK: - Models

struct Manifest: Codable {
    let version: String
    let lastUpdated: String
    let chains: [ChainMetadata]
}

struct ChainMetadata: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let difficulty: String
    let letterCount: Int
    let url: String
}

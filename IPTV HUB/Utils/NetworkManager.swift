//
//  NetworkError.swift
//  Easy IPTV
//
//  Created by Haluk CELEBI on 15.11.2025.
//

import Foundation

// Defines standard errors that can occur in our network layer
enum NetworkError: Error {
    case invalidURL
    case serverError(statusCode: Int)
    case decodingError(Error)
    case unknownError(Error)
    case dataNotFound
}

class NetworkManager {
    
    // Singleton instance accessible throughout the app
    // Efficiently manages resources like cache and connection pool
    static let shared = NetworkManager()
    
    private let session: URLSession
    private let maxRetries = 2
    private let baseRetryDelay: TimeInterval = 0.75
    
    // Initialize with a custom URLSession configuration
    private init() {
        let config = URLSessionConfiguration.default
        
        // Configure caching (optional but recommended)
        // Useful for large files like M3U and EPG lists
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 50_000_000, // 50MB memory cache
                                  diskCapacity: 1_000_000_000, // 1GB disk cache
                                  diskPath: "networkCache")
        // Keep image/icon fetches snappy and limit parallelism per host.
        config.timeoutIntervalForRequest = 12
        config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 4
        
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - 1. Fetch Raw Data
    
    /// Downloads raw 'Data' from a specific URL.
    /// Ideal for M3U and EPG parsers.
    @discardableResult // Caller doesn't have to use the returned value
    func fetchData(from url: URL,
                   cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad) async throws -> Data {
        print("Starting Network Request: \(url.absoluteString)")

        var attempt = 0
        var lastError: Error?

        while attempt <= maxRetries {
            do {
                var request = URLRequest(url: url)
                request.cachePolicy = cachePolicy
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.dataNotFound // Not a valid HTTP response
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    print("Server Error Code: \(httpResponse.statusCode)")
                    throw NetworkError.serverError(statusCode: httpResponse.statusCode)
                }

                return data
            } catch let error as NetworkError {
                lastError = error
            } catch {
                lastError = error
            }

            if attempt < maxRetries, shouldRetry(lastError) {
                let delay = baseRetryDelay * pow(1.5, Double(attempt))
                print("Retrying (attempt \(attempt + 1)) in \(String(format: "%.2f", delay))s for URL: \(url.absoluteString)")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                attempt += 1
                continue
            }
            break
        }

        if let lastError {
            if let networkError = lastError as? NetworkError {
                throw networkError
            }
            print("Unknown Network Error: \(lastError.localizedDescription)")
            throw NetworkError.unknownError(lastError)
        }

        throw NetworkError.dataNotFound
    }
    
    // MARK: - 2. Fetch Generic JSON
    
    /// Downloads data from a URL and automatically decodes it into a desired 'Decodable' model
    /// (e.g., TMDbResult). Ideal for TMDB service.
    func fetch<T: Decodable>(from url: URL, decoder: JSONDecoder = JSONDecoder()) async throws -> T {
        
        do {
            // 1. First, download raw data
            let data = try await fetchData(from: url)
            
            // 2. Try to decode the data into the given model (T)
            let decodedObject = try decoder.decode(T.self, from: data)
            return decodedObject
            
        } catch let error as NetworkError {
            // Propagate error from fetchData
            throw error
        } catch {
            // JSON decoding error
            print("JSON Decoding Error: \(error.localizedDescription)")
            throw NetworkError.decodingError(error)
        }
    }
}

private extension NetworkManager {
    func shouldRetry(_ error: Error?) -> Bool {
        guard let error else { return false }
        if let networkError = error as? NetworkError {
            switch networkError {
            case .unknownError(let underlying):
                return shouldRetry(underlying)
            default:
                return false
            }
        }
        if let urlError = error as? URLError {
            // Retry for transient connectivity issues and timeouts
            return urlError.code == .timedOut ||
                   urlError.code == .networkConnectionLost ||
                   urlError.code == .cannotFindHost ||
                   urlError.code == .cannotConnectToHost
        }
        return false
    }
}

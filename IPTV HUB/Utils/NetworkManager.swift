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
    
    // Initialize with a custom URLSession configuration
    private init() {
        let config = URLSessionConfiguration.default
        
        // Configure caching (optional but recommended)
        // Useful for large files like M3U and EPG lists
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 50_000_000, // 50MB memory cache
                                  diskCapacity: 1_000_000_000, // 1GB disk cache
                                  diskPath: "networkCache")
        
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - 1. Fetch Raw Data
    
    /// Downloads raw 'Data' from a specific URL.
    /// Ideal for M3U and EPG parsers.
    @discardableResult // Caller doesn't have to use the returned value
    func fetchData(from url: URL, cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad) async throws -> Data {
        
        print("Starting Network Request: \(url.absoluteString)")
        
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = cachePolicy
            let (data, response) = try await session.data(for: request)
            
            // Check HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.dataNotFound // Not a valid HTTP response
            }
            
            // Check for success status (200-299)
            guard (200...299).contains(httpResponse.statusCode) else {
                print("Server Error Code: \(httpResponse.statusCode)")
                throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            }
            
            return data
            
        } catch let error as NetworkError {
            // If it's already our defined error, rethrow
            throw error
        } catch {
            // Other errors (e.g., no internet connection)
            print("Unknown Network Error: \(error.localizedDescription)")
            throw NetworkError.unknownError(error)
        }
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

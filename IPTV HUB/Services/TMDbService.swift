import Foundation

// TMDB servisine özel hataları tanımlamak için
enum TMDbError: Error {
    case invalidURL
    case noResults
    case networkError(Error) // Genel ağ hatalarını sarmalamak için
}

class TMDbService {
    
    // !!! BURAYA KENDİ TMDB API ANAHTARINIZI GİRİN !!!
    private let apiKey = "SİZİN_TMDB_API_ANAHTARINIZ"
    
    // Arama yapılacak API uç noktası (Dizi aramak için /tv)
    private let baseURL = "https://api.themoviedb.org/3/search/tv"
    // Film aramak isterseniz: "https://api.themoviedb.org/3/search/movie"
    
    // NetworkManager'ın paylaşılan (singleton) örneğini kullan
    private let networkManager = NetworkManager.shared
    
    // JSON anahtarlarını (örn: poster_path) Swift (posterPath) stiline çevir
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    /// Bir başlığa göre meta veri getiren asenkron fonksiyon
    func fetchMetadata(for title: String) async throws -> TMDbResult {
        
        // 1. URL'i ve sorgu parametrelerini oluştur
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: title),
            URLQueryItem(name: "language", value: "tr-TR"), // Türkçe sonuçlar
            URLQueryItem(name: "page", value: "1")
        ]
        
        guard let url = components?.url else {
            throw TMDbError.invalidURL
        }
        
        // 2. İsteği NetworkManager'a devret
        do {
            let response: TMDbSearchResponse = try await networkManager.fetch(
                from: url,
                decoder: decoder
            )
            
            // 3. Sonucu işle
            if let firstResult = response.results.first {
                return firstResult
            } else {
                throw TMDbError.noResults
            }
            
        } catch {
            print("TMDb Servis Hatası: \(error.localizedDescription)")
            throw TMDbError.networkError(error)
        }
    }
}

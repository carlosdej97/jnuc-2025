import Foundation
import ArgumentParser
import UniformTypeIdentifiers

// MARK: - Configuration
struct Config {
    static let apiBaseURL = "https://pyc6e7gwzd.execute-api.us-east-1.amazonaws.com/v1"
    static let sharedSecret = "your-super-secret-key-here-change-sometime"
}

// MARK: - Models
struct PresignedURLRequest: Codable {
    let file_name: String
    let content_type: String
    let file_size: Int?
}

struct PresignedURLResponse: Codable {
    let presigned_put_url: String
    let file_key: String
    let bucket: String
    let expires_in: Int
    let max_file_size: Int
    let generated_at: String
    
    struct PresignedPost: Codable {
        let url: String
        let fields: [String: String]
    }
    let presigned_post: PresignedPost
}

struct ConfirmUploadRequest: Codable {
    let file_key: String
}

struct ConfirmUploadResponse: Codable {
    let message: String
    let file_key: String
    let s3_url: String
    let bucket: String
    let file_size: Int
    let content_type: String
    let last_modified: String
    let confirmed_at: String
}

struct APIError: Codable {
    let error: String
}

// MARK: - Custom Errors
enum FileUploaderError: Error, LocalizedError {
    case fileNotFound(String)
    case fileTooLarge(Int, Int)
    case invalidURL(String)
    case apiError(String, Int)
    case networkError(String)
    case invalidResponse
    case uploadFailed(Int)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found at path: \(path)"
        case .fileTooLarge(let size, let maxSize):
            return "File size (\(size) bytes) exceeds maximum allowed size (\(maxSize) bytes)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .apiError(let message, let code):
            return "API Error (\(code)): \(message)"
        case .networkError(let message):
            return "Network Error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .uploadFailed(let code):
            return "File upload failed with HTTP status: \(code)"
        }
    }
}

// MARK: - MIME Type Detection
extension URL {
    var mimeType: String {
        if let uti = UTType(filenameExtension: self.pathExtension) {
            return uti.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }
}

// MARK: - HTTP Client
class HTTPClient {
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300 // 5 minutes for large file uploads
        self.session = URLSession(configuration: config)
    }
    
    func performRequest<T: Codable>(
        url: URL,
        method: String,
        headers: [String: String] = [:],
        body: Data? = nil,
        responseType: T.Type
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Set headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FileUploaderError.invalidResponse
            }
            
            if httpResponse.statusCode >= 400 {
                // Try to parse error response
                if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw FileUploaderError.apiError(errorResponse.error, httpResponse.statusCode)
                } else {
                    throw FileUploaderError.apiError("Unknown error", httpResponse.statusCode)
                }
            }
            
            return try JSONDecoder().decode(responseType, from: data)
            
        } catch let error as FileUploaderError {
            throw error
        } catch {
            throw FileUploaderError.networkError(error.localizedDescription)
        }
    }
    
    func uploadFile(to url: URL, fileURL: URL, contentType: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        do {
            let (_, response) = try await session.upload(for: request, fromFile: fileURL)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FileUploaderError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                throw FileUploaderError.uploadFailed(httpResponse.statusCode)
            }
            
        } catch let error as FileUploaderError {
            throw error
        } catch {
            throw FileUploaderError.networkError(error.localizedDescription)
        }
    }
}

// MARK: - File Upload Service
class FileUploadService {
    private let httpClient = HTTPClient()
    private let baseURL: String
    private let sharedSecret: String
    
    init(baseURL: String = Config.apiBaseURL, sharedSecret: String = Config.sharedSecret) {
        self.baseURL = baseURL
        self.sharedSecret = sharedSecret
    }
    
    private var authHeaders: [String: String] {
        [
            "Authorization": "Bearer \(sharedSecret)",
            "Content-Type": "application/json"
        ]
    }
    
    func uploadFile(at filePath: String) async throws -> ConfirmUploadResponse {
        let fileURL = URL(fileURLWithPath: filePath)
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw FileUploaderError.fileNotFound(filePath)
        }
        
        // Get file attributes
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: filePath)
        let fileSize = fileAttributes[.size] as? Int ?? 0
        let fileName = fileURL.lastPathComponent
        let contentType = fileURL.mimeType
        
        print("📁 File: \(fileName)")
        print("📏 Size: \(fileSize) bytes")
        print("🏷️  MIME Type: \(contentType)")
        print()
        
        // Step 1: Get presigned URL
        print("🔗 Getting presigned URL...")
        let presignedResponse = try await getPresignedURL(
            fileName: fileName,
            contentType: contentType,
            fileSize: fileSize
        )
        
        // Check file size against limit
        if fileSize > presignedResponse.max_file_size {
            throw FileUploaderError.fileTooLarge(fileSize, presignedResponse.max_file_size)
        }
        
        print("✅ Presigned URL obtained")
        print("🗝️  File key: \(presignedResponse.file_key)")
        print()
        
        // Step 2: Upload file
        print("📤 Uploading file to S3...")
        guard let uploadURL = URL(string: presignedResponse.presigned_put_url) else {
            throw FileUploaderError.invalidURL(presignedResponse.presigned_put_url)
        }
        
        try await httpClient.uploadFile(to: uploadURL, fileURL: fileURL, contentType: contentType)
        print("✅ File uploaded successfully")
        print()
        
        // Step 3: Confirm upload
        print("✅ Confirming upload...")
        let confirmResponse = try await confirmUpload(fileKey: presignedResponse.file_key)
        print("✅ Upload confirmed!")
        print()
        
        return confirmResponse
    }
    
    private func getPresignedURL(fileName: String, contentType: String, fileSize: Int) async throws -> PresignedURLResponse {
        guard let url = URL(string: "\(baseURL)/presigned-url") else {
            throw FileUploaderError.invalidURL("\(baseURL)/presigned-url")
        }
        
        let request = PresignedURLRequest(
            file_name: fileName,
            content_type: contentType,
            file_size: fileSize
        )
        
        let requestData = try JSONEncoder().encode(request)
        
        return try await httpClient.performRequest(
            url: url,
            method: "POST",
            headers: authHeaders,
            body: requestData,
            responseType: PresignedURLResponse.self
        )
    }
    
    private func confirmUpload(fileKey: String) async throws -> ConfirmUploadResponse {
        guard let url = URL(string: "\(baseURL)/confirm-upload") else {
            throw FileUploaderError.invalidURL("\(baseURL)/confirm-upload")
        }
        
        let request = ConfirmUploadRequest(file_key: fileKey)
        let requestData = try JSONEncoder().encode(request)
        
        return try await httpClient.performRequest(
            url: url,
            method: "POST",
            headers: authHeaders,
            body: requestData,
            responseType: ConfirmUploadResponse.self
        )
    }
}

// MARK: - Command Line Interface
@main
struct FileUploader: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "file-uploader",
        abstract: "Upload files to AWS S3 via API Gateway",
        version: "1.0.0"
    )
    
    @Argument(help: "Path to the file to upload")
    var filePath: String
    
    @Flag(name: .shortAndLong, help: "Show verbose output")
    var verbose = false
    
    func run() async throws {
        print("🚀 File Uploader v1.0.0")
        print("=" * 40)
        
        let service = FileUploadService()
        
        do {
            let result = try await service.uploadFile(at: filePath)
            
            print("🎉 Upload completed successfully!")
            print("📍 S3 URL: \(result.s3_url)")
            print("🗄️  Bucket: \(result.bucket)")
            print("📏 Final size: \(result.file_size) bytes")
            print("📅 Uploaded at: \(result.last_modified)")
            print("✅ Confirmed at: \(result.confirmed_at)")
            
        } catch let error as FileUploaderError {
            print("❌ Error: \(error.localizedDescription)")
            throw ExitCode.failure
        } catch {
            print("❌ Unexpected error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

// MARK: - String Extension for Repeating Characters
extension String {
    static func * (string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}

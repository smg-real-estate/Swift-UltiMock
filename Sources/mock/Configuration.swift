struct Configuration: Decodable {
    let sources: [String]
    let sdkModules: [String: [String]]?
    let output: String?
    let imports: [String]?
}

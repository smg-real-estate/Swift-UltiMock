struct Configuration: Decodable {
    let sources: [String]
    let sdkModules: [String]?
    let output: String?
    let imports: [String]?
    let testableImports: [String]?
}

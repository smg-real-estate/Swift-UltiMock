import ArgumentParser
import PathKit

struct ConfigurationPath: ExpressibleByArgument {
    let resolvedPath: Path

    init?(argument: String) {
        let path = Path(argument)
        if path.isDirectory {
            self.resolvedPath = path + configFilename
        } else {
            self.resolvedPath = path
        }
    }
}

import Foundation

let manager = FileManager.default
let root = URL(
    fileURLWithPath: manager.currentDirectoryPath,
    isDirectory: true
)
let roots = ["Package.swift", "Sources", "Tests", "script/style.swift"]
let declaration = try NSRegularExpression(
    pattern: #"^\s*(actor|class|enum|protocol|struct)\s+[A-Za-z_]"#
)
var failed = false

func swiftFiles() -> [URL]
{
    var files: [URL] = []
    for entry in roots
    {
        let url = root.appendingPathComponent(entry)
        var directory: ObjCBool = false
        guard manager.fileExists(atPath: url.path, isDirectory: &directory)
        else
        {
            continue
        }
        if !directory.boolValue
        {
            files.append(url)
            continue
        }
        guard
            let walker = manager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey]
            )
        else
        {
            continue
        }
        while let file = walker.nextObject() as? URL
        {
            if file.pathExtension == "swift"
            {
                files.append(file)
            }
        }
    }
    return files.sorted
    {
        $0.path < $1.path
    }
}

func masked(_ line: String) -> String
{
    let values = Array(line)
    var result = values
    var index = 0
    var hashes = 0
    var quoted = false
    while index < values.count
    {
        if quoted
        {
            result[index] = " "
            if values[index] == "\\" && hashes == 0
            {
                if index + 1 < values.count
                {
                    index += 1
                    result[index] = " "
                }
            }
            else if values[index] == "\""
            {
                var closes = true
                if hashes > 0
                {
                    for step in 1...hashes
                    {
                        if index + step >= values.count
                            || values[index + step] != "#"
                        {
                            closes = false
                            break
                        }
                    }
                }
                if closes
                {
                    quoted = false
                }
            }
        }
        else
        {
            var cursor = index
            while cursor < values.count && values[cursor] == "#"
            {
                cursor += 1
            }
            if cursor < values.count && values[cursor] == "\""
            {
                hashes = cursor - index
                quoted = true
                for step in index...cursor
                {
                    result[step] = " "
                }
                index = cursor
            }
        }
        index += 1
    }
    return String(result)
}

func report(_ path: String, _ line: Int, _ rule: String)
{
    print("\(path):\(line): \(rule)")
    failed = true
}

for file in swiftFiles()
{
    let source = try String(contentsOf: file, encoding: .utf8)
    let relative = file.path.replacingOccurrences(
        of: root.path + "/",
        with: ""
    )
    var declarationCount = 0
    for (offset, line) in source.split(
        separator: "\n",
        omittingEmptySubsequences: false
    ).enumerated()
    {
        let value = String(line)
        let number = offset + 1
        if value.count > 80
        {
            report(relative, number, "width")
        }
        let code = masked(value)
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        let toolsDirective = value.hasPrefix("// swift-tools-version:")
        if !toolsDirective && (code.contains("//") || code.contains("/*"))
        {
            report(relative, number, "comments")
        }
        if trimmed.count > 1 && trimmed.hasSuffix("{")
        {
            report(relative, number, "braces")
        }
        let range = NSRange(code.startIndex..<code.endIndex, in: code)
        if declaration.firstMatch(in: code, range: range) != nil
        {
            declarationCount += 1
        }
    }
    if declarationCount > 1
    {
        report(relative, 1, "one named type per file")
    }
}

exit(failed ? 1 : 0)

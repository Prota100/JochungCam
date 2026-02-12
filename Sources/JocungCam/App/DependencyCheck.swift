import AppKit

enum DependencyCheck {
    struct Dep {
        let name: String
        let brewFormula: String
        let checkPath: String
        let required: Bool
        let description: String
    }

    static let dependencies: [Dep] = [
        Dep(name: "libimagequant", brewFormula: "libimagequant", checkPath: "/opt/homebrew/lib/libimagequant.dylib", required: true, description: "GIF 양자화 엔진 (필수)"),
        Dep(name: "gifski", brewFormula: "gifski", checkPath: "/opt/homebrew/bin/gifski", required: false, description: "고화질 GIF 인코더"),
        Dep(name: "webp", brewFormula: "webp", checkPath: "/opt/homebrew/bin/cwebp", required: false, description: "WebP 출력"),
    ]

    static var missingRequired: [Dep] {
        dependencies.filter { $0.required && !FileManager.default.fileExists(atPath: $0.checkPath) }
    }

    static var missingOptional: [Dep] {
        dependencies.filter { !$0.required && !FileManager.default.fileExists(atPath: $0.checkPath) }
    }

    static var allInstalled: Bool { missingRequired.isEmpty }

    /// Homebrew 설치 여부
    static var hasHomebrew: Bool {
        FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") ||
        FileManager.default.fileExists(atPath: "/usr/local/bin/brew")
    }

    static var brewPath: String {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") { return "/opt/homebrew/bin/brew" }
        return "/usr/local/bin/brew"
    }

    /// 의존성 설치 (brew install)
    static func installAll(completion: @escaping (Bool, String) -> Void) {
        let missing = dependencies.filter { !FileManager.default.fileExists(atPath: $0.checkPath) }
        guard !missing.isEmpty else { completion(true, "모든 의존성이 설치되어 있습니다."); return }

        guard hasHomebrew else {
            completion(false, "Homebrew가 설치되어 있지 않습니다.\nhttps://brew.sh 에서 먼저 설치하세요.")
            return
        }

        let formulas = missing.map { $0.brewFormula }.joined(separator: " ")

        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: brewPath)
            proc.arguments = ["install"] + missing.map { $0.brewFormula }
            proc.environment = ProcessInfo.processInfo.environment
            // brew needs PATH
            var env = proc.environment ?? [:]
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            proc.environment = env

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            do {
                try proc.run()
                proc.waitUntilExit()

                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                DispatchQueue.main.async {
                    if proc.terminationStatus == 0 {
                        completion(true, "설치 완료: \(formulas)")
                    } else {
                        completion(false, "설치 실패:\n\(output)")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "실행 실패: \(error.localizedDescription)")
                }
            }
        }
    }
}

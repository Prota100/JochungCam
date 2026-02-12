import SwiftUI

struct DependencySheet: View {
    @Binding var isPresented: Bool
    @State private var isInstalling = false
    @State private var result: String = ""
    @State private var success = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 6) {
                Text("🍯").font(.system(size: 36))
                Text("JochungCam 초기 설정").font(.system(size: 15, weight: .bold, design: .rounded))
                Text("필요한 의존성을 설치합니다").font(.caption).foregroundColor(.secondary)
            }

            Divider().opacity(0.3)

            // Dependency list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(DependencyCheck.dependencies, id: \.name) { dep in
                    let installed = FileManager.default.fileExists(atPath: dep.checkPath)
                    HStack(spacing: 8) {
                        Image(systemName: installed ? "checkmark.circle.fill" : (dep.required ? "xmark.circle.fill" : "minus.circle"))
                            .foregroundColor(installed ? .green : (dep.required ? .red : .orange))
                            .font(.system(size: 14))

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text(dep.name).font(.system(size: 12, weight: .semibold))
                                if dep.required {
                                    Text("필수").font(.system(size: 8, weight: .bold))
                                        .padding(.horizontal, 4).padding(.vertical, 1)
                                        .background(Color.red.opacity(0.15)).foregroundColor(.red)
                                        .clipShape(Capsule())
                                }
                            }
                            Text(dep.description).font(.system(size: 10)).foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(installed ? "설치됨" : "미설치")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(installed ? .green : .secondary)
                    }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.05)))

            if !DependencyCheck.hasHomebrew {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Homebrew 미설치").font(.caption.bold())
                        Text("먼저 Homebrew를 설치하세요").font(.system(size: 10)).foregroundColor(.secondary)
                        Link("https://brew.sh", destination: URL(string: "https://brew.sh")!)
                            .font(.system(size: 10))
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.1)))
            }

            if !result.isEmpty {
                Text(result)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(success ? .green : .red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.05)))
            }

            Divider().opacity(0.3)

            // Actions
            HStack {
                Button("나중에") {
                    isPresented = false
                }.foregroundColor(.secondary)

                Spacer()

                if isInstalling {
                    ProgressView().controlSize(.small)
                    Text("설치 중...").font(.caption).foregroundColor(.secondary)
                } else if DependencyCheck.allInstalled && DependencyCheck.missingOptional.isEmpty {
                    Button("완료") { isPresented = false }
                        .buttonStyle(.borderedProminent).tint(.green)
                } else {
                    Button(action: install) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill").font(.system(size: 11))
                            Text("전체 설치").font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Color(hex: "FFD60A"))
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(!DependencyCheck.hasHomebrew)
                }
            }

            // Manual command
            VStack(spacing: 4) {
                Text("또는 터미널에서 직접 실행:").font(.system(size: 9)).foregroundColor(.secondary)
                let cmd = "brew install " + DependencyCheck.dependencies.filter {
                    !FileManager.default.fileExists(atPath: $0.checkPath)
                }.map { $0.brewFormula }.joined(separator: " ")

                HStack {
                    Text(cmd).font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                        .textSelection(.enabled)
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(cmd, forType: .string)
                        result = "클립보드에 복사됨"
                        success = true
                    }) {
                        Image(systemName: "doc.on.clipboard").font(.system(size: 9))
                    }.buttonStyle(.borderless)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.05)))
            }
        }
        .padding(20)
        .frame(minWidth: 380, maxWidth: 380)
    }

    func install() {
        isInstalling = true
        result = ""
        DependencyCheck.installAll { ok, msg in
            isInstalling = false
            success = ok
            result = msg
        }
    }
}

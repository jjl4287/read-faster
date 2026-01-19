import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultWPM") private var defaultWPM: Int = 300
    @AppStorage("fontSize") private var fontSize: Double = 48
    @AppStorage("pauseOnPunctuation") private var pauseOnPunctuation: Bool = true

    var body: some View {
        Form {
            Section("Reading Defaults") {
                VStack(alignment: .leading) {
                    Text("Default Speed: \(defaultWPM) WPM")
                    Slider(
                        value: Binding(
                            get: { Double(defaultWPM) },
                            set: { defaultWPM = Int($0) }
                        ),
                        in: 200...1000,
                        step: 25
                    )
                }

                VStack(alignment: .leading) {
                    Text("Font Size: \(Int(fontSize))")
                    Slider(value: $fontSize, in: 24...72, step: 2)
                }

                Toggle("Pause on Punctuation", isOn: $pauseOnPunctuation)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.appVersion)
                LabeledContent("Build", value: Bundle.main.buildNumber)
            }

            Section {
                Link(destination: URL(string: "https://github.com/jjl4287/read-faster")!) {
                    Label("View on GitHub", systemImage: "link")
                }
            }
        }
        .formStyle(.grouped)
        #if os(macOS)
        .frame(width: 450)
        .padding()
        #endif
    }
}

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    SettingsView()
}

import SwiftUI

struct ScenesView: View {
    @EnvironmentObject private var appState: AppState
    @State private var newSceneName = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FOHPageHeader(title: "Scenes", detail: "Choose a microphone and listening device together, then recall the setup in one click.")

                if let active = appState.activeScene {
                    HStack(spacing: 12) {
                        Image(systemName: active.symbolName)
                            .font(.title2)
                            .foregroundStyle(FOHTheme.signal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(active.name) is active").font(.headline)
                            Text("It stays in control until you leave the scene.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Leave Scene") { appState.deactivateScene() }
                    }
                    .padding(16)
                    .background(FOHTheme.signal.opacity(0.07))
                    .overlay(alignment: .bottom) { FOHSectionRule() }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                    ForEach(appState.scenes) { scene in
                        sceneCard(scene)
                    }
                }

                HStack {
                    TextField("New scene name", text: $newSceneName)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                        .onSubmit(addScene)
                    Button(action: addScene) {
                        Label("Add Scene", systemImage: "plus")
                    }
                        .controlSize(.large)
                        .disabled(newSceneName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .frame(maxWidth: 480)
            }
            .padding(32)
            .frame(maxWidth: FOHTheme.pageWidth, alignment: .leading)
        }
        .fohCanvas()
    }

    private func sceneCard(_ scene: AudioScene) -> some View {
        let isActive = appState.activeSceneID == scene.id
        let isConfigured = scene.inputDeviceID != nil || scene.outputDeviceID != nil
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: scene.symbolName)
                    .font(.title2)
                    .frame(width: 30)
                Text(scene.name).font(.title3.bold())
                Spacer()
                if isActive {
                    Text("ACTIVE")
                        .font(.caption2.bold())
                        .foregroundStyle(FOHTheme.signal)
                }
                Menu {
                    Button("Delete Scene", role: .destructive) { appState.removeScene(scene.id) }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            devicePicker("Microphone", icon: "mic.fill", direction: .input, scene: scene)
            devicePicker("Listening", icon: "headphones", direction: .output, scene: scene)

            Button {
                appState.activateScene(scene.id)
            } label: {
                Text(isActive ? "Scene Active" : isConfigured ? "Activate \(scene.name)" : "Choose a device to activate")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(FOHTheme.signal)
            .controlSize(.large)
            .disabled(isActive || !isConfigured)
        }
        .padding(20)
        .background(FOHTheme.panel)
        .overlay {
            RoundedRectangle(cornerRadius: FOHTheme.panelRadius)
                .stroke(isActive ? FOHTheme.signal : FOHTheme.rule, lineWidth: isActive ? 1.2 : 0.7)
        }
        .clipShape(RoundedRectangle(cornerRadius: FOHTheme.panelRadius))
    }

    private func devicePicker(
        _ title: String,
        icon: String,
        direction: AudioDirection,
        scene: AudioScene
    ) -> some View {
        let selection = Binding<String?>(
            get: { direction == .input ? scene.inputDeviceID : scene.outputDeviceID },
            set: { appState.updateSceneDevice(scene.id, direction: direction, deviceID: $0) }
        )
        let choices = appState.priorities(for: direction)
        return HStack(spacing: 12) {
            Label(title, systemImage: icon)
                .foregroundStyle(.secondary)
                .frame(width: FOHTheme.formLabelWidth, alignment: .leading)
            Picker(title, selection: selection) {
                Text("Choose device").tag(String?.none)
                ForEach(choices) { priority in
                    Text(appState.device(for: priority) == nil ? "\(priority.name) — unavailable" : priority.name)
                        .tag(Optional(priority.id))
                }
            }
            .labelsHidden()
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        }
    }

    private func addScene() {
        appState.addScene(named: newSceneName)
        newSceneName = ""
    }
}

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
                        .onSubmit(addScene)
                    Button("Add Scene", action: addScene)
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

            Button(isActive ? "Scene Active" : "Activate Scene") {
                appState.activateScene(scene.id)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(isActive)
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
        return HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(.secondary)
            Spacer()
            Picker(title, selection: selection) {
                Text("Choose device").tag(String?.none)
                ForEach(choices) { priority in
                    Text(appState.device(for: priority) == nil ? "\(priority.name) — unavailable" : priority.name)
                        .tag(Optional(priority.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 190)
        }
    }

    private func addScene() {
        appState.addScene(named: newSceneName)
        newSceneName = ""
    }
}

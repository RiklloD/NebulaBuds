import SceneKit
import SwiftUI
import simd

struct HeadTrackingPage: View {
    @Environment(BudsController.self) private var buds
    @State private var scene = HeadScene()

    var body: some View {
        VStack(spacing: 16) {
            SceneView(scene: scene.scene, pointOfView: scene.camera, options: [.autoenablesDefaultLighting])
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if buds.headTracking {
                        Text(String(format: "%.0f Hz", buds.poseRate))
                            .font(.caption.monospacedDigit()).padding(6)
                            .background(.thinMaterial, in: Capsule()).padding(10)
                    }
                }

            if let q = buds.pose {
                let e = eulerDegrees(q)
                HStack(spacing: 30) {
                    angle("Yaw", e.yaw); angle("Pitch", e.pitch); angle("Roll", e.roll)
                }
            }

            HStack {
                Button(buds.headTracking ? "Stop tracking" : "Start tracking") {
                    buds.headTracking ? buds.stopHeadTracking() : buds.startHeadTracking()
                }
                .buttonStyle(.borderedProminent)
                Button("Recenter") { buds.recenterHead() }.disabled(!buds.headTracking)
                Spacer()
                Text("Streams the earbuds' rotation sensor (the one used for 360 Audio). Look straight ahead and press Recenter.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .disabled(!buds.isConnected)
        .onChange(of: buds.pose) { _, q in if let q { scene.apply(q) } }
        .onDisappear { buds.stopHeadTracking() }
    }

    private func angle(_ name: String, _ v: Float) -> some View {
        VStack {
            Text(name).font(.caption).foregroundStyle(.secondary)
            Text(String(format: "%+.0f°", v)).font(.title2.monospacedDigit())
        }
    }

    private func eulerDegrees(_ q: simd_quatf) -> (yaw: Float, pitch: Float, roll: Float) {
        let (x, y, z, w) = (q.imag.x, q.imag.y, q.imag.z, q.real)
        let roll = atan2(2 * (w * x + y * z), 1 - 2 * (x * x + y * y))
        let pitch = asin(max(-1, min(1, 2 * (w * y - z * x))))
        let yaw = atan2(2 * (w * z + x * y), 1 - 2 * (y * y + z * z))
        let d: Float = 180 / .pi
        return (yaw * d, pitch * d, roll * d)
    }
}

@MainActor
final class HeadScene {
    let scene = SCNScene()
    let camera = SCNNode()
    private let head = SCNNode()

    init() {
        scene.background.contents = NSColor.windowBackgroundColor
        camera.camera = SCNCamera()
        camera.position = SCNVector3(0, 0.3, 4)
        scene.rootNode.addChildNode(camera)

        let skin = SCNMaterial()
        skin.diffuse.contents = NSColor.systemGray
        let skull = SCNNode(geometry: SCNSphere(radius: 0.8))
        skull.geometry?.materials = [skin]
        skull.scale = SCNVector3(0.9, 1.1, 1.0)
        head.addChildNode(skull)

        let nose = SCNNode(geometry: SCNCone(topRadius: 0, bottomRadius: 0.12, height: 0.35))
        nose.geometry?.firstMaterial?.diffuse.contents = NSColor.systemGray
        nose.eulerAngles.x = -.pi / 2
        nose.position = SCNVector3(0, 0, 0.9)
        head.addChildNode(nose)

        for side: CGFloat in [-1, 1] {
            let eye = SCNNode(geometry: SCNSphere(radius: 0.08))
            eye.geometry?.firstMaterial?.diffuse.contents = NSColor.black
            eye.position = SCNVector3(0.25 * side, 0.2, 0.72)
            head.addChildNode(eye)

            let bud = SCNNode(geometry: SCNCapsule(capRadius: 0.1, height: 0.35))
            bud.geometry?.firstMaterial?.diffuse.contents = NSColor.controlAccentColor
            bud.position = SCNVector3(0.78 * side, 0, 0)
            head.addChildNode(bud)
        }
        scene.rootNode.addChildNode(head)
    }

    func apply(_ q: simd_quatf) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.08
        head.simdOrientation = q
        SCNTransaction.commit()
    }
}

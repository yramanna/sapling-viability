import AVFoundation
import SwiftUI
import UIKit

private let captureFrameHorizontalInset: CGFloat = 22
private let captureFrameTopInset: CGFloat = 104
private let captureFrameBottomInset: CGFloat = 196
private let captureFrameCornerRadius: CGFloat = 38

private func captureFrameRect(in size: CGSize) -> CGRect {
    CGRect(
        x: captureFrameHorizontalInset,
        y: captureFrameTopInset,
        width: size.width - (captureFrameHorizontalInset * 2),
        height: size.height - captureFrameTopInset - captureFrameBottomInset
    )
}

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?
    @StateObject private var camera = PremiumCameraController()
    @State private var shutterPressed = false
    @State private var guidesVisible = false

    var body: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            CameraCaptureMask()
                .ignoresSafeArea()

            bottomControlFade
                .ignoresSafeArea()

            CaptureGuideFrame()
                .ignoresSafeArea()
                .opacity(guidesVisible ? 1 : 0)
                .scaleEffect(guidesVisible ? 1 : 0.985)

            CaptureGuideLabel()
                .ignoresSafeArea()
                .opacity(guidesVisible ? 1 : 0)
                .scaleEffect(guidesVisible ? 1 : 0.985)

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
            }

            if camera.authorizationDenied {
                authorizationOverlay
            }

        }
        .onAppear {
            camera.start()
            withAnimation(.easeOut(duration: 0.35)) {
                guidesVisible = true
            }
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: camera.capturedImage) { _, captured in
            guard let captured else { return }
            image = captured
            dismiss()
        }
    }

    private var topBar: some View {
        ZStack {
            HStack {
                Spacer()

                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppPalette.lightGreen)
                            .frame(width: 7, height: 7)
                            .shadow(color: AppPalette.lightGreen.opacity(0.7), radius: 6, x: 0, y: 0)

                        Text("CAPTURE")
                            .font(.system(size: 11, weight: .semibold, design: .default))
                            .tracking(1.6)
                            .foregroundStyle(AppPalette.lightGreen.opacity(0.96))
                    }

                    Text("HOLD PARALLEL TO TRAY")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .tracking(1.2)
                        .foregroundStyle(AppPalette.white.opacity(0.78))
                }

                Spacer()
            }

            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppPalette.white)
                        .frame(width: 42, height: 42)
                        .background(AppPalette.black.opacity(0.34))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        AppPalette.black.opacity(0.5),
                        AppPalette.black.opacity(0.24),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Rectangle()
                    .fill(AppPalette.white.opacity(0.04))
                    .blur(radius: 18)
            }
        )
    }

    private var bottomBar: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 0) {
                Button {
                    shutterPressed = true
                    camera.capturePhoto()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        shutterPressed = false
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(AppPalette.black.opacity(0.38))
                            .frame(width: 102, height: 102)
                        Circle()
                            .stroke(AppPalette.white.opacity(0.24), lineWidth: 2)
                            .frame(width: 102, height: 102)
                        Circle()
                            .stroke(AppPalette.lightGreen.opacity(0.18), lineWidth: 10)
                            .frame(width: 92, height: 92)
                        Circle()
                            .fill(AppPalette.white)
                            .frame(width: 76, height: 76)
                        Circle()
                            .stroke(AppPalette.white.opacity(0.58), lineWidth: 4)
                            .frame(width: 86, height: 86)
                    }
                }
                .scaleEffect(shutterPressed ? 0.94 : 1.0)
                .shadow(color: AppPalette.lightGreen.opacity(shutterPressed ? 0.26 : 0.12), radius: shutterPressed ? 8 : 18, x: 0, y: 0)
                .animation(.easeOut(duration: 0.12), value: shutterPressed)
                .disabled(!camera.isReady || camera.isCapturing)
                .opacity(camera.isReady ? 1 : 0.55)
            }
        }
        .padding(.bottom, 30)
    }

    private var bottomControlFade: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [
                    .clear,
                    AppPalette.black.opacity(0.08),
                    AppPalette.black.opacity(0.22),
                    AppPalette.black.opacity(0.38)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 300)
        }
    }

    private var authorizationOverlay: some View {
        ZStack {
                Color.black.opacity(0.72).ignoresSafeArea()
                VStack(spacing: 14) {
                    Text("Camera access needed")
                        .font(.system(size: 28, weight: .semibold, design: .default))
                        .tracking(0.8)
                        .foregroundStyle(AppPalette.white)
                    Text("Allow camera access in Settings to capture a tray image.")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .tracking(0.8)
                        .foregroundStyle(AppPalette.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
            }
            .padding(24)
        }
    }

}

private struct CameraCaptureMask: View {
    var body: some View {
        GeometryReader { geometry in
            let frameRect = captureFrameRect(in: geometry.size)

            Path { path in
                path.addRect(CGRect(origin: .zero, size: geometry.size))
                path.addRoundedRect(
                    in: frameRect,
                    cornerSize: CGSize(width: captureFrameCornerRadius, height: captureFrameCornerRadius)
                )
            }
            .fill(AppPalette.black.opacity(0.18), style: FillStyle(eoFill: true))
        }
    }
}

private struct CaptureGuideFrame: View {
    @State private var pulse = false

    var body: some View {
        GeometryReader { geometry in
            let guideRect = captureFrameRect(in: geometry.size)

            RoundedRectangle(cornerRadius: captureFrameCornerRadius, style: .continuous)
                .path(in: guideRect)
                .stroke(
                    AppPalette.lightGreen.opacity(pulse ? 0.98 : 0.84),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: captureFrameCornerRadius, style: .continuous)
                        .path(in: guideRect)
                        .stroke(AppPalette.lightGreen.opacity(pulse ? 0.82 : 0.42), lineWidth: 6)
                        .blur(radius: pulse ? 9 : 4.5)
                }
                .shadow(color: AppPalette.lightGreen.opacity(pulse ? 0.55 : 0.26), radius: pulse ? 24 : 12, x: 0, y: 0)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: pulse)
                .onAppear {
                    pulse = true
                }
        }
    }
}

private struct CaptureGuideLabel: View {
    var body: some View {
        GeometryReader { geometry in
            let guideRect = captureFrameRect(in: geometry.size)

            Text("Tray area")
                .font(.system(size: 12, weight: .semibold, design: .default))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(AppPalette.white.opacity(0.42))
                .position(x: guideRect.midX, y: guideRect.maxY - 24)
        }
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

private final class PremiumCameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var capturedImage: UIImage?
    @Published var authorizationDenied = false
    @Published var isReady = false
    @Published var isCapturing = false

    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "greenhouse.camera.session")
    private var isConfigured = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorizationDenied = false
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.authorizationDenied = !granted
                }
                guard granted else { return }
                self?.configureAndStart()
            }
        default:
            authorizationDenied = true
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
        DispatchQueue.main.async { [weak self] in
            self?.isCapturing = false
        }
    }

    func capturePhoto() {
        guard isReady, !isCapturing else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.async { [weak self] in
            self?.isCapturing = true
        }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { [weak self] in
                self?.isCapturing = false
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            self?.capturedImage = image
        }
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                defer {
                    self.session.commitConfiguration()
                    self.isConfigured = true
                }

                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: camera),
                      self.session.canAddInput(input),
                      self.session.canAddOutput(self.photoOutput) else {
                    DispatchQueue.main.async {
                        self.authorizationDenied = true
                    }
                    return
                }

                self.session.addInput(input)
                self.session.addOutput(self.photoOutput)
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.isReady = true
            }
        }
    }
}

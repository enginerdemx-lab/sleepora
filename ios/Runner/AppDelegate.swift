import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  var audioRecorder: AVAudioRecorder?
  var currentPath: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    let controller = window?.rootViewController as! FlutterViewController
    let recorderChannel = FlutterMethodChannel(
      name: "com.sleepora/recorder",
      binaryMessenger: controller.binaryMessenger
    )
    
    recorderChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "hasPermission":
        self.checkPermission(result: result)
      case "startRecording":
        if let args = call.arguments as? [String: Any],
           let path = args["path"] as? String {
          self.startRecording(path: path, result: result)
        } else {
          result(false)
        }
      case "pauseRecording":
        self.pauseRecording(result: result)
      case "resumeRecording":
        self.resumeRecording(result: result)
      case "stopRecording":
        self.stopRecording(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func checkPermission(result: @escaping FlutterResult) {
    switch AVAudioSession.sharedInstance().recordPermission {
    case .granted:
      result(true)
    case .denied:
      result(false)
    case .undetermined:
      AVAudioSession.sharedInstance().requestRecordPermission { granted in
        DispatchQueue.main.async {
          result(granted)
        }
      }
    @unknown default:
      result(false)
    }
  }

  private func startRecording(path: String, result: @escaping FlutterResult) {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
      try session.setActive(true)

      let url = URL(fileURLWithPath: path)
      let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
      ]

      audioRecorder = try AVAudioRecorder(url: url, settings: settings)
      audioRecorder?.record()
      currentPath = path
      result(true)
    } catch {
      result(false)
    }
  }

  private func pauseRecording(result: @escaping FlutterResult) {
    audioRecorder?.pause()
    result(true)
  }

  private func resumeRecording(result: @escaping FlutterResult) {
    audioRecorder?.record()
    result(true)
  }

  private func stopRecording(result: @escaping FlutterResult) {
    audioRecorder?.stop()
    audioRecorder = nil
    result(currentPath)
    currentPath = nil
  }
}

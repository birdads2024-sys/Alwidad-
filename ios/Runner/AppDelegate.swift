import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var securityChannel: FlutterMethodChannel?
  private var recordingOverlayView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      securityChannel = FlutterMethodChannel(
        name: "com.alwidad.security",
        binaryMessenger: controller.binaryMessenger
      )

      securityChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "isScreenCaptured" {
          result(UIScreen.main.isCaptured)
        } else if call.method == "setKeepScreenOn" {
          if let args = call.arguments as? [String: Any], let enable = args["enable"] as? Bool {
            UIApplication.shared.isIdleTimerDisabled = enable
            result(true)
          } else {
            result(false)
          }
        } else if call.method == "startBackgroundTask" {
          var bgTaskId: UIBackgroundTaskIdentifier = .invalid
          bgTaskId = UIApplication.shared.beginBackgroundTask(withName: "VideoDownload") {
            UIApplication.shared.endBackgroundTask(bgTaskId)
            bgTaskId = .invalid
          }
          result(bgTaskId.rawValue)
        } else if call.method == "endBackgroundTask" {
          if let args = call.arguments as? [String: Any], let id = args["id"] as? Int {
            let bgTaskId = UIBackgroundTaskIdentifier(rawValue: id)
            if bgTaskId != .invalid {
              UIApplication.shared.endBackgroundTask(bgTaskId)
            }
            result(true)
          } else {
            result(false)
          }
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureChanged),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureChanged),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )

    DispatchQueue.main.async { [weak self] in
      self?.checkScreenCapture()
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc private func screenCaptureChanged() {
    DispatchQueue.main.async { [weak self] in
      self?.checkScreenCapture()
    }
  }

  private func checkScreenCapture() {
    let isCaptured = UIScreen.main.isCaptured
    securityChannel?.invokeMethod("onScreenCaptureChanged", arguments: ["isCaptured": isCaptured])
    updateSecurityOverlay(isCaptured: isCaptured)
  }

  private func updateSecurityOverlay(isCaptured: Bool) {
    guard let keyWindow = window ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
      return
    }

    if isCaptured {
      if recordingOverlayView == nil {
        let overlay = UIView(frame: keyWindow.bounds)
        overlay.backgroundColor = .black
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.tag = 998877

        let label = UILabel()
        label.text = "عذراً، تسجيل الشاشة غير مسموح لحماية المحتوى التعليمي ⚠️"
        label.textColor = .white
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        overlay.addSubview(label)
        NSLayoutConstraint.activate([
          label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
          label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
          label.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 24),
          label.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -24)
        ])

        keyWindow.addSubview(overlay)
        keyWindow.bringSubviewToFront(overlay)
        recordingOverlayView = overlay
      } else {
        recordingOverlayView?.frame = keyWindow.bounds
        keyWindow.bringSubviewToFront(recordingOverlayView!)
      }
    } else {
      recordingOverlayView?.removeFromSuperview()
      recordingOverlayView = nil
    }
  }
}

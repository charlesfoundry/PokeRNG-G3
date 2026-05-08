import AVFoundation
import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private let timerBeepPlayer = TimerBeepPlayer()

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    timerBeepPlayer.register(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

private final class TimerBeepPlayer {
  private var player: AVAudioPlayer?

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "pokerng_g3/timer_beep",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "prepare":
        self?.prepare(result: result)
      case "play":
        self?.play(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func prepare(result: FlutterResult) {
    if player != nil {
      result(nil)
      return
    }
    do {
      player = try makePlayer()
      player?.prepareToPlay()
      result(nil)
    } catch {
      result(FlutterError(code: "load_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func play(result: FlutterResult) {
    do {
      if player == nil {
        player = try makePlayer()
        player?.prepareToPlay()
      }
      player?.currentTime = 0
      player?.play()
      result(nil)
    } catch {
      result(FlutterError(code: "play_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func makePlayer() throws -> AVAudioPlayer {
    let assetKey = FlutterDartProject.lookupKey(forAsset: "assets/audio/timer_beep.wav")
    guard let url = Bundle.main.url(forResource: assetKey, withExtension: nil) else {
      throw NSError(
        domain: "TimerBeepPlayer",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Timer beep asset was not found."]
      )
    }
    let nextPlayer = try AVAudioPlayer(contentsOf: url)
    nextPlayer.numberOfLoops = 0
    nextPlayer.volume = 1
    return nextPlayer
  }
}

import AVFoundation
import Flutter
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let timerBeepPlayer = TimerBeepPlayer()
  private let screenAwakeController = ScreenAwakeController()
  private let supportPurchaseController = SupportPurchaseController()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    timerBeepPlayer.register(messenger: engineBridge.applicationRegistrar.messenger())
    screenAwakeController.register(messenger: engineBridge.applicationRegistrar.messenger())
    supportPurchaseController.register(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

private final class SupportPurchaseController {
  private var productsResult: FlutterResult?
  private var productsById: [String: Product] = [:]
  private var purchaseInProgress = false

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "pokerng_g3/support_purchase",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "products":
        guard let ids = Self.productIds(from: call) else {
          result(FlutterError(code: "invalid_arguments", message: "Product IDs are missing.", details: nil))
          return
        }
        Task { await self?.loadProducts(ids: ids, result: result) }
      case "purchase":
        guard let id = Self.productId(from: call) else {
          result(FlutterError(code: "invalid_arguments", message: "Product ID is missing.", details: nil))
          return
        }
        Task { await self?.purchase(id: id, result: result) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @MainActor
  private func loadProducts(ids: [String], result: @escaping FlutterResult) async {
    guard productsResult == nil else {
      result(FlutterError(code: "busy", message: "A product request is already running.", details: nil))
      return
    }

    productsResult = result
    do {
      let storeProducts = try await Product.products(for: ids)
      productsById = Dictionary(uniqueKeysWithValues: storeProducts.map { ($0.id, $0) })
      let products = storeProducts
        .sorted { $0.price < $1.price }
        .map { product in
          [
            "id": product.id,
            "displayName": product.displayName,
            "description": product.description,
            "price": product.displayPrice,
          ]
        }
      productsResult?(products)
    } catch {
      productsResult?(FlutterError(code: "load_failed", message: error.localizedDescription, details: nil))
    }
    productsResult = nil
  }

  @MainActor
  private func purchase(id: String, result: @escaping FlutterResult) async {
    guard !purchaseInProgress else {
      result(FlutterError(code: "busy", message: "A purchase is already running.", details: nil))
      return
    }
    guard SKPaymentQueue.canMakePayments() else {
      result(FlutterError(code: "unavailable", message: "In-app purchases are disabled.", details: nil))
      return
    }
    guard let product = productsById[id] else {
      result(FlutterError(code: "product_not_loaded", message: "Product is not loaded.", details: nil))
      return
    }

    purchaseInProgress = true
    defer {
      purchaseInProgress = false
    }

    do {
      let purchaseResult = try await product.purchase()
      switch purchaseResult {
      case .success(let verification):
        switch verification {
        case .verified(let transaction):
          await transaction.finish()
          result("success")
        case .unverified(_, let error):
          result(FlutterError(code: "verification_failed", message: error.localizedDescription, details: nil))
        }
      case .pending:
        result("pending")
      case .userCancelled:
        result("cancelled")
      @unknown default:
        result(FlutterError(code: "purchase_failed", message: "Unknown purchase result.", details: nil))
      }
    } catch {
      result(FlutterError(code: "purchase_failed", message: error.localizedDescription, details: nil))
    }
  }

  private static func productIds(from call: FlutterMethodCall) -> [String]? {
    guard let arguments = call.arguments as? [String: Any],
          let ids = arguments["ids"] as? [String],
          !ids.isEmpty
    else {
      return nil
    }
    return ids
  }

  private static func productId(from call: FlutterMethodCall) -> String? {
    guard let arguments = call.arguments as? [String: Any],
          let id = arguments["id"] as? String,
          !id.isEmpty
    else {
      return nil
    }
    return id
  }
}

private final class ScreenAwakeController {
  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "pokerng_g3/screen_awake",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setEnabled":
        let arguments = call.arguments as? [String: Any]
        let enabled = arguments?["enabled"] as? Bool ?? false
        UIApplication.shared.isIdleTimerDisabled = enabled
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
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

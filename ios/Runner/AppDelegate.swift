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

private final class SupportPurchaseController: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
  private var productsRequest: SKProductsRequest?
  private var productsResult: FlutterResult?
  private var productsById: [String: SKProduct] = [:]
  private var purchaseResult: FlutterResult?

  override init() {
    super.init()
    SKPaymentQueue.default().add(self)
  }

  deinit {
    SKPaymentQueue.default().remove(self)
  }

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "pokerng_g3/support_purchase",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "products":
        self?.loadProducts(call: call, result: result)
      case "purchase":
        self?.purchase(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func loadProducts(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard productsResult == nil else {
      result(FlutterError(code: "busy", message: "A product request is already running.", details: nil))
      return
    }
    guard let arguments = call.arguments as? [String: Any],
          let ids = arguments["ids"] as? [String],
          !ids.isEmpty
    else {
      result(FlutterError(code: "invalid_arguments", message: "Product IDs are missing.", details: nil))
      return
    }

    productsResult = result
    let request = SKProductsRequest(productIdentifiers: Set(ids))
    productsRequest = request
    request.delegate = self
    request.start()
  }

  private func purchase(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard purchaseResult == nil else {
      result(FlutterError(code: "busy", message: "A purchase is already running.", details: nil))
      return
    }
    guard SKPaymentQueue.canMakePayments() else {
      result(FlutterError(code: "unavailable", message: "In-app purchases are disabled.", details: nil))
      return
    }
    guard let arguments = call.arguments as? [String: Any],
          let id = arguments["id"] as? String,
          let product = productsById[id]
    else {
      result(FlutterError(code: "product_not_loaded", message: "Product is not loaded.", details: nil))
      return
    }

    purchaseResult = result
    SKPaymentQueue.default().add(SKPayment(product: product))
  }

  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    productsById = Dictionary(uniqueKeysWithValues: response.products.map { ($0.productIdentifier, $0) })
    let products = response.products
      .sorted { $0.price.compare($1.price) == .orderedAscending }
      .map { product in
        [
          "id": product.productIdentifier,
          "displayName": product.localizedTitle,
          "description": product.localizedDescription,
          "price": localizedPrice(for: product),
        ]
      }
    productsResult?(products)
    productsResult = nil
    productsRequest = nil
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    productsResult?(FlutterError(code: "load_failed", message: error.localizedDescription, details: nil))
    productsResult = nil
    productsRequest = nil
  }

  func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
    for transaction in transactions {
      switch transaction.transactionState {
      case .purchased, .restored:
        SKPaymentQueue.default().finishTransaction(transaction)
        finishPurchase("success")
      case .failed:
        SKPaymentQueue.default().finishTransaction(transaction)
        if let error = transaction.error as? SKError, error.code == .paymentCancelled {
          finishPurchase("cancelled")
        } else {
          purchaseResult?(FlutterError(
            code: "purchase_failed",
            message: transaction.error?.localizedDescription,
            details: nil
          ))
          purchaseResult = nil
        }
      case .deferred:
        finishPurchase("pending")
      case .purchasing:
        break
      @unknown default:
        break
      }
    }
  }

  private func finishPurchase(_ status: String) {
    purchaseResult?(status)
    purchaseResult = nil
  }

  private func localizedPrice(for product: SKProduct) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = product.priceLocale
    return formatter.string(from: product.price) ?? product.price.stringValue
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

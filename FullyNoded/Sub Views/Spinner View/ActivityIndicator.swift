//
//  ActivityIndicator.swift
//  FullyNoded
//
//  Non-blocking progress for a screen: a small spinner and status text in the
//  navigation bar (the title comes back when done) and, optionally, a spinner inside
//  the button that started the work. Unlike ConnectingView it never covers the screen.
//  It ends on its own when the screen leaves the window (pushed past, popped or
//  dismissed), so a flow that moves on without hiding it can't leave it spinning.
//
//      showActivity("signing...", button: sender)   // start, or update the status
//      hideActivity()                               // done (any number of times)
//      guard !isShowingActivity else { return }     // ignore taps while busy
//

import UIKit

extension UIViewController {

    /// Starts the activity or, while it's running, just updates the status. The button
    /// (if given) shows a spinner and ignores taps until `hideActivity()`. A later call
    /// without a button keeps the current one, so multi-step work stays on its button.
    /// Safe from any thread.
    func showActivity(_ status: String = "", button: UIButton? = nil) {
        onMain { self.activity.show(status, button: button) }
    }

    /// Stops the activity. Deferred by a moment, so a hide immediately followed by the
    /// next step's `showActivity` keeps one continuous spinner instead of flickering.
    /// Safe from any thread; `completion` runs on the main thread.
    func hideActivity(completion: (() -> Void)? = nil) {
        onMain {
            self.activity.scheduleHide()
            completion?()
        }
    }

    /// True while an activity is running (main thread).
    var isShowingActivity: Bool {
        (objc_getAssociatedObject(self, &ActivityState.key) as? ActivityState)?.isActive ?? false
    }

    private var activity: ActivityState {
        if let state = objc_getAssociatedObject(self, &ActivityState.key) as? ActivityState {
            return state
        }
        let state = ActivityState(viewController: self)
        objc_setAssociatedObject(self, &ActivityState.key, state, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return state
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}

private final class ActivityState {
    static var key: UInt8 = 0

    private weak var viewController: UIViewController?
    private weak var button: UIButton?
    private var pendingHide: DispatchWorkItem?
    private(set) var isActive = false

    // Nav bar: spinner + status in place of the title.
    private var savedTitleView: UIView?
    private let statusLabel = UILabel()
    private lazy var navView: UIStackView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        statusLabel.font = WalletTheme.mono(13, weight: .semibold)
        statusLabel.lineBreakMode = .byTruncatingTail
        let stack = UIStackView(arrangedSubviews: [spinner, statusLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()

    // No nav bar: a small pill at the top of the view (never blocks touches).
    private var pill: UIView?

    init(viewController: UIViewController) {
        self.viewController = viewController
    }

    func show(_ status: String, button: UIButton?) {
        pendingHide?.cancel()
        pendingHide = nil

        if let button = button, button !== self.button {
            stopButton()
            self.button = button
            startButton(button)
        }

        statusLabel.text = status
        statusLabel.textColor = viewController?.navigationController?.navigationBar.tintColor ?? WalletTheme.text
        (navView.arrangedSubviews.first as? UIActivityIndicatorView)?.color = statusLabel.textColor

        guard !isActive else { return }
        isActive = true
        installWindowWatcher()

        if let item = viewController?.navigationItem, viewController?.navigationController != nil {
            savedTitleView = item.titleView
            item.titleView = navView
        } else {
            showPill()
        }
    }

    func scheduleHide() {
        guard isActive else { return }
        pendingHide?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        pendingHide = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func hide() {
        pendingHide = nil
        isActive = false
        stopButton()
        if let item = viewController?.navigationItem, item.titleView === navView {
            item.titleView = savedTitleView
        }
        savedTitleView = nil
        navView.removeFromSuperview()
        pill?.removeFromSuperview()
        pill = nil
    }

    // MARK: Button

    private func startButton(_ button: UIButton) {
        button.isUserInteractionEnabled = false
        if var config = button.configuration {
            config.showsActivityIndicator = true
            button.configuration = config
        } else {
            // Legacy (non-configuration) button: spinner over the hidden content.
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.tag = ActivityState.buttonSpinnerTag
            spinner.color = button.tintColor
            spinner.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(spinner)
            NSLayoutConstraint.activate([
                spinner.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                spinner.centerYAnchor.constraint(equalTo: button.centerYAnchor)
            ])
            spinner.startAnimating()
            button.titleLabel?.alpha = 0
            button.imageView?.alpha = 0
        }
    }

    private func stopButton() {
        guard let button = button else { return }
        self.button = nil
        button.isUserInteractionEnabled = true
        if var config = button.configuration {
            config.showsActivityIndicator = false
            button.configuration = config
        }
        if let spinner = button.viewWithTag(ActivityState.buttonSpinnerTag) {
            spinner.removeFromSuperview()
            button.titleLabel?.alpha = 1
            button.imageView?.alpha = 1
        }
    }

    private static let buttonSpinnerTag = 0xAC71

    // MARK: Leaving the screen

    private func installWindowWatcher() {
        guard let view = viewController?.view,
              !view.subviews.contains(where: { $0 is WindowWatcher }) else { return }
        let watcher = WindowWatcher()
        watcher.onLeftWindow = { [weak self] in
            guard let self = self, self.isActive else { return }
            self.pendingHide?.cancel()
            self.hide()
        }
        view.addSubview(watcher)
    }

    // MARK: Pill fallback

    private func showPill() {
        guard let view = viewController?.view else { return }
        let pill = UIView()
        pill.isUserInteractionEnabled = false
        pill.backgroundColor = WalletTheme.card
        pill.layer.cornerRadius = 16
        pill.layer.borderWidth = 1
        pill.layer.borderColor = WalletTheme.dim.withAlphaComponent(0.4).cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false
        navView.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(navView)
        view.addSubview(pill)
        NSLayoutConstraint.activate([
            pill.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            pill.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pill.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32),
            navView.topAnchor.constraint(equalTo: pill.topAnchor, constant: 7),
            navView.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -7),
            navView.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 12),
            navView.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12)
        ])
        self.pill = pill
    }
}

/// Invisible view that reports when its screen goes from on-screen to off-screen.
private final class WindowWatcher: UIView {
    var onLeftWindow: (() -> Void)?
    private var wasInWindow = false

    init() {
        super.init(frame: .zero)
        isHidden = true
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            wasInWindow = true
        } else if wasInWindow {
            wasInWindow = false
            onLeftWindow?()
        }
    }
}

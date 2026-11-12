//
//  WalletPrivacyViewController.swift
//  FullyNoded
//
//  What this wallet's own history gives away: addresses visibly linked on-chain, and addresses
//  that received more than once. Read only, from the node.
//

import UIKit

final class WalletPrivacyViewController: UIViewController {
    override var hidesBottomBarWhenPushed: Bool { get { true } set {} }

    /// Enough to see the picture, without building thousands of views for a very busy wallet.
    private static let maxRows = 100

    private let tint = WalletTheme.Tint.wallet
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let linkedStack = UIStackView()
    private let reusedStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Privacy checkup"
        WalletTheme.apply(to: self, tint: tint)

        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        scroll.addSubview(stack)
        view.addSubview(scroll)
        let refresh = UIRefreshControl()
        refresh.tintColor = tint.accent
        refresh.addTarget(self, action: #selector(load), for: .valueChanged)
        scroll.refreshControl = refresh

        for content in [linkedStack, reusedStack] {
            content.axis = .vertical
            content.spacing = 10
        }
        stack.addArrangedSubview(WalletTheme.caption("> LINKED ADDRESSES", tint: tint))
        stack.addArrangedSubview(WalletTheme.cardView([linkedStack], tint: tint))
        stack.setCustomSpacing(16, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(WalletTheme.caption("> REUSED ADDRESSES", tint: tint))
        stack.addArrangedSubview(WalletTheme.cardView([reusedStack], tint: tint))

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: guide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16)
        ])
        set(linkedStack, [note("Loading…")])
        set(reusedStack, [note("Loading…")])
        load()
    }

    @objc private func load() {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listaddressgroupings) { [weak self] response, error in
            DispatchQueue.main.async {
                self?.scroll.refreshControl?.endRefreshing()
                self?.showLinked(response as? [[[Any]]], error: error)
            }
        }
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listreceivedbyaddress(List_Received_By_Address())) { [weak self] response, error in
            DispatchQueue.main.async { self?.showReused(response as? [[String: Any]], error: error) }
        }
    }

    private func showLinked(_ response: [[[Any]]]?, error: String?) {
        guard let response = response else {
            set(linkedStack, [note(error ?? "Your node didn't answer.")])
            return
        }
        let groups = AddressGroup.linked(from: response)
        var views: [UIView] = [note("Anyone reading the chain can tell these addresses probably belong to one wallet, because they were spent together or one received the other's change. Change makes some of this normal.")]
        if groups.isEmpty { views.append(body("No linked addresses.")) }
        var rows = 0
        for (index, group) in groups.enumerated() {
            guard rows < Self.maxRows else {
                views.append(note("And \(groups.count - index) more group\(groups.count - index == 1 ? "" : "s")."))
                break
            }
            views.append(heading("Group \(index + 1) · \(group.entries.count) addresses · \(group.total.btcBalanceWithSpaces) BTC"))
            for entry in group.entries.prefix(Self.maxRows - rows) {
                views.append(addressRow(entry.address, detail: "\(entry.amount.btcBalanceWithSpaces) BTC" + (entry.label.map { " · \($0)" } ?? "")))
                rows += 1
            }
        }
        set(linkedStack, views)
    }

    private func showReused(_ response: [[String: Any]]?, error: String?) {
        guard let response = response else {
            set(reusedStack, [note(error ?? "Your node didn't answer.")])
            return
        }
        let reused = ReusedAddress.from(response: response)
        var views: [UIView] = [note("Each payment to the same address tells anyone who has paid it about the others. Use a new address each time.")]
        if reused.isEmpty { views.append(body("No address has received more than once.")) }
        for address in reused.prefix(Self.maxRows) {
            views.append(addressRow(address.address, detail: "\(address.transactions) transactions · \(address.amount.btcBalanceWithSpaces) BTC received" + (address.label.map { " · \($0)" } ?? "")))
        }
        if reused.count > Self.maxRows { views.append(note("And \(reused.count - Self.maxRows) more.")) }
        set(reusedStack, views)
    }

    // MARK: - Pieces

    private func set(_ target: UIStackView, _ views: [UIView]) {
        target.arrangedSubviews.forEach { $0.removeFromSuperview() }
        views.forEach { target.addArrangedSubview($0) }
    }

    private func label(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func note(_ text: String) -> UILabel { label(text, font: WalletTheme.mono(11), color: WalletTheme.dim) }
    private func body(_ text: String) -> UILabel { label(text, font: WalletTheme.mono(13), color: WalletTheme.text) }
    private func heading(_ text: String) -> UILabel { label(text, font: WalletTheme.mono(12, weight: .bold), color: tint.accent) }

    /// The whole address, wrapped: never truncated. Tap to copy. Plain labels, not a button: a
    /// button's rounded background cuts the corners off text that reaches its edge.
    private func addressRow(_ address: String, detail: String) -> UIView {
        let addressLabel = label(address, font: WalletTheme.mono(12), color: WalletTheme.text)
        addressLabel.lineBreakMode = .byCharWrapping
        let row = UIStackView(arrangedSubviews: [addressLabel, note(detail)])
        row.axis = .vertical
        row.spacing = 2
        row.isAccessibilityElement = true
        row.accessibilityTraits = .button
        row.accessibilityLabel = "\(address), \(detail). Copy address."
        row.addGestureRecognizer(CopyAddressTap(address: address, target: self, action: #selector(copyAddress(_:))))
        return row
    }

    @objc private func copyAddress(_ tap: CopyAddressTap) {
        UIPasteboard.general.string = tap.address
        impact()
        SuccessView.toast("Address copied", in: self)
    }
}

private final class CopyAddressTap: UITapGestureRecognizer {
    let address: String

    init(address: String, target: Any?, action: Selector?) {
        self.address = address
        super.init(target: target, action: action)
    }
}

//
//  CoreWalletsViewController.swift
//  FullyNoded
//
//  Created by Peter on 06/08/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//
//  Bitcoin Core Wallets, built in code: every wallet in the node's wallet directory, whether it's
//  loaded, active, or saved in Fully Noded. Tapping one loads it if needed, saves its descriptors
//  as a Fully Noded wallet (asking which format when it has several) and makes it the active
//  wallet. Swipe to load or unload.
//

import UIKit

final class CoreWalletsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    private struct CoreWallet {
        let name: String
        let loaded: Bool
        let active: Bool
        /// The Fully Noded wallet saved for it, if any.
        let saved: Wallet?

        var isDefault: Bool { name.isEmpty }
        var title: String { saved?.label ?? (isDefault ? "Default wallet" : name) }
    }

    private enum State {
        case loading
        case failed(String)
        case loaded
    }

    private let tint: WalletTheme.Tint = .wallet
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let refresher = UIRefreshControl()
    private var sections: [(title: String, wallets: [CoreWallet])] = []
    private var state = State.loading
    private var savedWallets: [Wallet] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Bitcoin Core Wallets"

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        tableView.sectionFooterHeight = 0
        tableView.register(ThemedRowCell.self, forCellReuseIdentifier: ThemedRowCell.reuseId)
        tableView.tableHeaderView = intro()
        refresher.addTarget(self, action: #selector(reload), for: .valueChanged)
        tableView.refreshControl = refresher
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        WalletTheme.apply(to: self, tint: tint)
        refresher.tintColor = tint.accent
        reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeHeader()
    }

    // MARK: - Loading

    /// The wallet directory, what's loaded, the active wallet and the saved Fully Noded wallets.
    @objc private func reload() {
        if sections.isEmpty { setState(.loading) }
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] saved in
            let savedWallets = (saved ?? []).map { Wallet(dictionary: $0) }
            OnchainUtils.listWalletDir { (walletDir, message) in
                guard let walletDir = walletDir else {
                    self?.finish(.failed("Couldn't list your node's wallets: \(message ?? "unknown error").\n\nPull down to try again."), sections: [], saved: savedWallets)
                    return
                }
                OnchainUtils.listWallets { (loaded, _) in
                    let loaded = Set(loaded ?? [])
                    let activeName = UserDefaults.standard.string(forKey: "walletName")
                    let wallets = walletDir.wallets.map { name in
                        CoreWallet(name: name, loaded: loaded.contains(name), active: name == activeName && !name.isEmpty,
                                   saved: savedWallets.first { $0.name == name })
                    }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
                    let sections = [
                        ("> ACTIVE", wallets.filter { $0.active }),
                        ("> LOADED ON YOUR NODE", wallets.filter { $0.loaded && !$0.active }),
                        ("> NOT LOADED", wallets.filter { !$0.loaded && !$0.active })
                    ].filter { !$0.1.isEmpty }
                    self?.finish(.loaded, sections: sections, saved: savedWallets)
                }
            }
        }
    }

    private func finish(_ state: State, sections: [(String, [CoreWallet])], saved: [Wallet]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.refresher.endRefreshing()
            self.savedWallets = saved
            self.sections = sections.map { (title: $0.0, wallets: $0.1) }
            self.setState(state)
        }
    }

    private func setState(_ state: State) {
        self.state = state
        tableView.reloadData()
        switch state {
        case .loading:
            tableView.backgroundView = message("Reading your node's wallets…", spinner: true)
        case .failed(let reason):
            tableView.backgroundView = message(reason)
        case .loaded:
            tableView.backgroundView = sections.isEmpty
                ? message("Your node has no wallets yet. Create one from the + on the wallet screen.")
                : nil
        }
    }

    // MARK: - Table

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].wallets.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ThemedRowCell.reuseId, for: indexPath) as! ThemedRowCell
        let wallet = sections[indexPath.section].wallets[indexPath.row]
        var details: [String] = []
        if let saved = wallet.saved, saved.label != wallet.name, !wallet.isDefault { details.append(wallet.name) }
        if wallet.isDefault {
            details.append("Not supported: use a named wallet")
        } else {
            details.append(wallet.saved != nil ? "Saved in Fully Noded" : "Not in Fully Noded yet: tap to add it")
        }
        if !wallet.loaded && !wallet.isDefault { details.append("loads when you use it") }
        // Picking one wallet: a radio mark, filled for the active one (none for the unsupported default).
        cell.configure(icon: wallet.saved != nil ? "square.stack.3d.up" : "cylinder",
                       title: wallet.title,
                       subtitle: details.joined(separator: " · "),
                       value: wallet.active ? "ACTIVE" : nil,
                       dimmed: !wallet.active && (!wallet.loaded || wallet.isDefault),
                       tint: tint,
                       trailingSymbol: wallet.isDefault ? nil : (wallet.active ? "checkmark.circle.fill" : "circle"),
                       trailingHighlighted: wallet.active)
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        let caption = WalletTheme.caption(sections[section].title, tint: tint)
        caption.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(caption)
        NSLayoutConstraint.activate([
            caption.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 2),
            caption.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -6)
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        40
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        WalletTheme.styleCell(cell, in: tableView, tint: tint)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let wallet = sections[indexPath.section].wallets[indexPath.row]
        guard !wallet.active else { return }
        impact()
        guard !wallet.isDefault else {
            showAlert(vc: self, title: "Default wallet", message: "Fully Noded works with named wallets only. Create a new wallet, or give this one a name on your node.", kind: .notice)
            return
        }
        activate(wallet)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let wallet = sections[indexPath.section].wallets[indexPath.row]
        guard !wallet.isDefault else { return nil }
        let action: UIContextualAction
        if wallet.loaded {
            action = UIContextualAction(style: .normal, title: "Unload") { [weak self] _, _, done in
                self?.unload(wallet)
                done(true)
            }
            action.backgroundColor = WalletTheme.pending
        } else {
            action = UIContextualAction(style: .normal, title: "Load") { [weak self] _, _, done in
                self?.load(wallet.name) { error in
                    if let error = error { showAlert(vc: self, title: "Couldn't load \(wallet.title)", message: error, kind: .error) }
                    self?.reload()
                }
                done(true)
            }
            action.backgroundColor = tint.accent.withAlphaComponent(0.6)
        }
        return UISwipeActionsConfiguration(actions: [action])
    }

    // MARK: - Activating

    /// Loads the wallet if needed, saves it in Fully Noded (its descriptors), then makes it active.
    private func activate(_ wallet: CoreWallet) {
        showActivity(wallet.loaded ? "Opening \(wallet.title)…" : "Loading \(wallet.title) on your node…")
        let proceed = { [weak self] in
            guard let self = self else { return }
            if wallet.saved != nil {
                self.finishActivation(wallet.name, label: wallet.title, note: nil)
            } else {
                self.saveDescriptors(of: wallet)
            }
        }
        guard wallet.loaded else {
            load(wallet.name) { [weak self] error in
                if let error = error {
                    self?.hideActivity()
                    showAlert(vc: self, title: "Couldn't load \(wallet.title)", message: error, kind: .error)
                    return
                }
                proceed()
            }
            return
        }
        proceed()
    }

    /// Reads the wallet's descriptors and saves one receive / change pair as a Fully Noded wallet
    /// (asking which, when it has more than one format).
    private func saveDescriptors(of wallet: CoreWallet) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listdescriptors, walletName: wallet.name) { [weak self] (response, error) in
            guard let self = self else { return }
            guard let response = response,
                  let json = try? JSONSerialization.data(withJSONObject: response),
                  let listed = try? JSONDecoder().decode(ListDescriptorsResponse.self, from: json) else {
                self.finishActivation(wallet.name, label: wallet.title,
                                      note: "Couldn't read its descriptors (\(error ?? "unknown error")), so some features are limited.")
                return
            }
            let receive = listed.descriptors.filter { $0.internal_ == false }.map { Descriptor($0.desc) }
            let change = listed.descriptors.filter { $0.internal_ == true }.map(\.desc)
            guard !receive.isEmpty else {
                self.finishActivation(wallet.name, label: wallet.title,
                                      note: "It isn't a descriptor wallet, so some features are limited.")
                return
            }
            self.hideActivity()
            self.chooseFormat(receive, change: change, wallet: wallet)
        }
    }

    private func chooseFormat(_ receive: [Descriptor], change: [String], wallet: CoreWallet) {
        let pick = { [weak self] (descriptor: Descriptor) in
            self?.save(descriptor, change: change, wallet: wallet)
        }
        guard receive.count > 1 else {
            pick(receive[0])
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let sheet = UIAlertController(title: "Which format?",
                                          message: "\(wallet.title) holds several address formats. Fully Noded uses one at a time; you can add the wallet again later to use another.",
                                          preferredStyle: .actionSheet)
            for descriptor in receive {
                sheet.addAction(UIAlertAction(title: descriptor.scriptType, style: .default) { _ in pick(descriptor) })
            }
            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            sheet.popoverPresentationController?.sourceView = self.view
            sheet.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            self.present(sheet, animated: true)
        }
    }

    private func save(_ receive: Descriptor, change: [String], wallet: CoreWallet) {
        guard let changeDescriptor = change.first(where: { Descriptor($0).scriptType == receive.scriptType }) else {
            finishActivation(wallet.name, label: wallet.title,
                             note: "It has no matching change descriptor, so some features are limited.")
            return
        }
        let dict: [String: Any] = [
            "blockheight": 0,
            "changeDescriptor": changeDescriptor,
            "id": UUID(),
            "label": wallet.name,
            "name": wallet.name,
            "receiveDescriptor": receive.string
        ]
        CoreDataService.saveEntity(dict: dict, entityName: .wallets) { [weak self] saved in
            self?.finishActivation(wallet.name, label: wallet.title,
                                   note: saved ? "Saved in Fully Noded as \(receive.scriptType)." : "Couldn't save it in Fully Noded, so some features are limited.")
        }
    }

    /// Makes `name` the active wallet and refreshes the wallet screen.
    private func finishActivation(_ name: String, label: String, note: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hideActivity()
            UserDefaults.standard.set(name, forKey: "walletName")
            NotificationCenter.default.post(name: .refreshWallet, object: nil)
            showAlert(vc: self, title: "\(label) is active", message: note ?? "The wallet screen is refreshing with it now.",
                      kind: note == nil || note!.hasPrefix("Saved") ? .success : .notice)
            self.reload()
        }
    }

    // MARK: - Load / unload

    private func load(_ name: String, completion: @escaping (String?) -> Void) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .loadwallet(Load_Wallet(["filename": name]))) { response, error in
            DispatchQueue.main.async { completion(response == nil ? (error ?? "Unknown error.") : nil) }
        }
    }

    private func unload(_ wallet: CoreWallet) {
        showActivity("Unloading \(wallet.title)…")
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .unloadwallet(param: Unload_Wallet(["wallet_name": wallet.name]))) { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.hideActivity()
                guard response != nil else {
                    showAlert(vc: self, title: "Couldn't unload \(wallet.title)", message: error ?? "Unknown error.", kind: .error)
                    return
                }
                if wallet.active {
                    UserDefaults.standard.removeObject(forKey: "walletName")
                    NotificationCenter.default.post(name: .refreshWallet, object: nil)
                }
                self.reload()
            }
        }
    }

    // MARK: - Views

    private func intro() -> UIView {
        let label = UILabel()
        label.text = "Wallets on your node. Tap one to use it: Fully Noded loads it if needed and saves its descriptors. Swipe to load or unload."
        label.font = WalletTheme.mono(11)
        label.textColor = WalletTheme.dim
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        let header = UIView()
        header.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: header.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -18),
            label.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -4)
        ])
        return header
    }

    /// The intro wraps to the table's width.
    private func sizeHeader() {
        guard let header = tableView.tableHeaderView, tableView.bounds.width > 0 else { return }
        let height = header.systemLayoutSizeFitting(CGSize(width: tableView.bounds.width, height: 0),
                                                    withHorizontalFittingPriority: .required,
                                                    verticalFittingPriority: .fittingSizeLevel).height
        guard abs(header.frame.height - height) > 0.5 || header.frame.width != tableView.bounds.width else { return }
        header.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: height)
        tableView.tableHeaderView = header
    }

    private func message(_ text: String, spinner: Bool = false) -> UIView {
        let label = UILabel()
        label.text = text
        label.font = WalletTheme.mono(12)
        label.textColor = WalletTheme.dim
        label.textAlignment = .center
        label.numberOfLines = 0
        var views: [UIView] = [label]
        if spinner {
            let indicator = UIActivityIndicatorView(style: .medium)
            indicator.color = tint.accent
            indicator.startAnimating()
            views.insert(indicator, at: 0)
        }
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = UIView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32)
        ])
        return container
    }
}

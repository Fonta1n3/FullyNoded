//
//  NodesViewController.swift
//  BitSense
//
//  Created by Peter on 29/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

/// Node Manager, built in code: every saved node with its transport (Tor / local / LAN)
/// and which one is active. Tap a node to make it active, the pencil to edit it, swipe
/// to delete, + to add one (manually or by scanning a QR).
class NodesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UINavigationControllerDelegate {

    /// A node plus what the row shows (decrypted once per load).
    private struct Row {
        let node: NodeStruct
        let host: String
        let transport: String
    }

    private var rows: [Row] = []
    private let ud = UserDefaults.standard
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var addButton = UIBarButtonItem()
    private var editButton = UIBarButtonItem()

    init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        hidesBottomBarWhenPushed = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Nodes"
        navigationController?.delegate = self

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 68
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.estimatedSectionFooterHeight = 44
        tableView.register(ThemedRowCell.self, forCellReuseIdentifier: ThemedRowCell.reuseId)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNode))
        editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editNodes))
        updateBarButtons()

        // Cypherpunk look (WalletTheme in ActiveWalletViewController.swift).
        WalletTheme.apply(to: self, tint: .settings)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        getNodes()
    }

    private func updateBarButtons() {
        addButton.tintColor = WalletTheme.Tint.settings.accent
        editButton.tintColor = WalletTheme.Tint.settings.accent
        navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
    }

    // MARK: - Data

    func getNodes() {
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }

            guard let nodes = nodes else {
                displayAlert(viewController: self, isError: true, message: "error getting nodes from core data")
                return
            }

            let rows = nodes.map { NodeStruct(dictionary: $0) }
                .filter { $0.id != nil }
                .map { Self.row(for: $0) }

            DispatchQueue.main.async {
                self.rows = rows
                self.tableView.reloadData()

                if rows.isEmpty {
                    self.addNodePrompt()
                }
            }
        }
    }

    private static func row(for node: NodeStruct) -> Row {
        var host = ""
        if let encrypted = node.onionAddress, let decrypted = Crypto.decrypt(encrypted) {
            host = decrypted.utf8String ?? ""
        }

        let transport: String
        if host.contains(".onion") {
            transport = "TOR"
        } else if host.hasPrefix("localhost:") || host.hasPrefix("127.0.0.1:") {
            transport = "LOCAL"
        } else if node.cert != nil {
            transport = "LAN · SSL"
        } else {
            transport = "LAN"
        }

        return Row(node: node, host: shortened(host), transport: transport)
    }

    /// Long onion hosts shortened in the middle: "abcdefgh…wxyz.onion:8332".
    private static func shortened(_ host: String) -> String {
        guard host.count > 30 else { return host }
        return "\(host.prefix(10))…\(host.suffix(16))"
    }

    // MARK: - Table

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ThemedRowCell.reuseId, for: indexPath) as! ThemedRowCell
        let row = rows[indexPath.row]
        let host = row.host.isEmpty ? "no address" : row.host

        cell.configure(icon: row.node.isActive ? "bolt.horizontal.circle.fill" : "server.rack",
                       title: row.node.label.isEmpty ? "Node" : row.node.label,
                       subtitle: "\(row.transport) · \(host)",
                       value: row.node.isActive ? "ACTIVE" : nil,
                       dimmed: !row.node.isActive,
                       action: ("pencil", self, #selector(editNode(_:)), indexPath.row))
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        let caption = WalletTheme.caption("> SAVED NODES", tint: .settings)
        caption.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(caption)
        NSLayoutConstraint.activate([
            caption.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 2),
            caption.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -6)
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        36
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let label = UILabel()
        label.text = rows.isEmpty
            ? "No nodes yet. Tap + to add your node manually or by scanning its QR code."
            : "Tap a node to make it active. Tap ✎ to edit, swipe left to delete."
        label.font = WalletTheme.mono(11)
        label.textColor = WalletTheme.dim
        label.numberOfLines = 0

        let footer = UIView()
        label.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: footer.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -2),
            label.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -10)
        ])
        return footer
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        WalletTheme.styleCell(cell, in: tableView, tint: .settings)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selected = rows[indexPath.row].node
        guard !selected.isActive, let selectedId = selected.id else { return }
        impact()
        activate(selectedId, label: selected.label)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, let id = rows[indexPath.row].node.id else { return }
        deleteNode(nodeId: id, indexPath: indexPath)
    }

    // MARK: - Actions

    /// Makes `id` the only active node.
    private func activate(_ id: UUID, label: String) {
        CoreDataService.update(id: id, keyToUpdate: "isActive", newValue: true, entity: .newNodes) { [weak self] success in
            guard let self = self else { return }

            guard success else {
                displayAlert(viewController: self, isError: true, message: "Error updating node.")
                return
            }

            self.ud.removeObject(forKey: "walletName")

            for row in self.rows where row.node.id != id {
                if let otherId = row.node.id {
                    CoreDataService.update(id: otherId, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                }
            }

            self.getNodes()

            DispatchQueue.main.async {
                showAlert(vc: self, title: "", message: "\(label.isEmpty ? "Node" : label) is now active. Tap the refresh button on the home view to connect to it.")
            }
        }
    }

    @objc func editNode(_ sender: UIButton) {
        guard rows.indices.contains(sender.tag) else { return }
        showDetail(for: rows[sender.tag].node)
    }

    private func showDetail(for node: NodeStruct?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let vc = NodeDetailViewController()
            vc.selectedNode = node
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func editNodes() {
        tableView.setEditing(!tableView.isEditing, animated: true)

        if tableView.isEditing {
            editButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(editNodes))
        } else {
            editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editNodes))
        }

        updateBarButtons()
    }

    private func deleteNode(nodeId: UUID, indexPath: IndexPath) {
        CoreDataService.deleteEntity(id: nodeId, entityName: .newNodes) { [weak self] success in
            guard let self = self else { return }

            guard success else {
                showAlert(vc: self, title: "", message: "We had an error trying to delete that node.")
                return
            }

            DispatchQueue.main.async {
                self.rows.remove(at: indexPath.row)
                self.tableView.deleteRows(at: [indexPath], with: .fade)
                self.tableView.reloadData()
            }
        }
    }

    private func addNodePrompt() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let alert = UIAlertController(title: "Scan QR or add manually?",
                                          message: "You can add the node credentials manually or scan a QR code.",
                                          preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "Manually", style: .default) { [weak self] _ in
                self?.showDetail(for: nil)
            })

            alert.addAction(UIAlertAction(title: "Scan QR", style: .default) { [weak self] _ in
                self?.scanNode()
            })

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.popoverPresentationController?.sourceView = self.view

            self.present(alert, animated: true, completion: nil)
        }
    }

    @objc func addNode(_ sender: Any) {
        addNodePrompt()
    }

    private func scanNode() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let vc = UIStoryboard(name: "Main", bundle: nil)
                    .instantiateViewController(withIdentifier: "QRScanner") as? QRScannerViewController else { return }

            vc.isQuickConnect = true
            vc.onDoneBlock = { [weak self] url in
                guard let self = self, let url = url else { return }
                self.addBtcRpcQr(url: url)
            }
            self.present(vc, animated: true)
        }
    }

    /// Adds a node from a quick-connect QR (it becomes the active node) and opens it.
    private func addBtcRpcQr(url: String) {
        QuickConnect.addNode(url: url) { [weak self] (success, errorMessage) in
            guard let self = self else { return }

            guard success else {
                displayAlert(viewController: self, isError: true, message: "Error adding that node: \(errorMessage ?? "unknown")")
                return
            }

            CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
                guard let self = self else { return }
                let active = (nodes ?? []).map { NodeStruct(dictionary: $0) }.first { $0.isActive && $0.id != nil }
                self.getNodes()
                self.showDetail(for: active)
            }
        }
    }
}

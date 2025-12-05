//
//  PeersDetailTableViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/11/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import UIKit

class PeersDetailTableViewController: UITableViewController {
    
    private var isRefreshing = false
    private var refreshButton: UIBarButtonItem!
    private var spinner: UIActivityIndicatorView!
    
    var peerResponse: GetPeerInfoResponse!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupRefreshButton()
        title = "Bitcoin Peers"
        
        tableView.register(PeerCell.self, forCellReuseIdentifier: PeerCell.identifier)
        setHeader()
    }
    
    // MARK: - Table View Data Source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        peerResponse.peers.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PeerCell.identifier, for: indexPath) as! PeerCell
        let peer = peerResponse.peers[indexPath.row]
        cell.configure(with: peer)
        
        cell.onBanTapped = { [weak self] in
            self?.banPeer(at: indexPath)
        }
        
        return cell
    }
    
    private func setHeader() {
        // Header
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 80))
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.text = "\(peerResponse.peers.count) Peers • \(peerResponse.outgoingCount) Outgoing • \(peerResponse.incomingCount) Incoming"
        label.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: header.centerYAnchor, constant: 10)
        ])
        tableView.tableHeaderView = header
        
        // Empty state
        if peerResponse.peers.isEmpty {
            let empty = UILabel()
            empty.text = "No peers"
            empty.textAlignment = .center
            empty.font = .systemFont(ofSize: 18, weight: .medium)
            empty.textColor = .secondaryLabel
            tableView.backgroundView = empty
        }
    }
    
    private func setupRefreshButton() {
        spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = .systemBlue
        spinner.hidesWhenStopped = true
        
        let refreshButtonView = UIButton(type: .system)
        refreshButtonView.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        refreshButtonView.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        refreshButtonView.sizeToFit()
        
        let containerView = UIView(frame: refreshButtonView.bounds.insetBy(dx: -20, dy: -10))
        containerView.addSubview(refreshButtonView)
        containerView.addSubview(spinner)
        
        refreshButtonView.center = containerView.center
        spinner.center = containerView.center
        
        refreshButton = UIBarButtonItem(customView: containerView)
        navigationItem.rightBarButtonItem = refreshButton
    }
    
    @objc private func refreshTapped() {
        guard !isRefreshing else { return }
        startRefreshing()
        refreshData()
    }
    
    private func startRefreshing() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            isRefreshing = true
            spinner.startAnimating()
            refreshButton.isEnabled = false
            (refreshButton.customView?.subviews.first(where: { $0 is UIButton }) as? UIButton)?.alpha = 0
        }
        
    }
    
    private func stopRefreshing() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            isRefreshing = false
            spinner.stopAnimating()
            refreshButton.isEnabled = true
            (refreshButton.customView?.subviews.first(where: { $0 is UIButton }) as? UIButton)?.alpha = 1.0
        }
    }
    
    private func refreshData() {
        NodeLogic.sharedInstance.getPeerInfo { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            stopRefreshing()
            
            guard let response = response else {
                showAlert(vc: self, title: "", message: errorMessage ?? "unknown error")
                return
            }
            
            peerResponse = response
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                setHeader()
                tableView.reloadData()
            }
        }
    }
    
    // MARK: - Ban
    private func banPeer(at indexPath: IndexPath) {
        let peer = peerResponse.peers[indexPath.row]
        let alert = UIAlertController(
            title: "Ban Peer",
            message: "\(peer.addr)\n\(peer.subver)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Ban for ~100 years", style: .default) { _ in
            self.runBan(addr: peer.addr, subver: peer.subver)
        })
        present(alert, animated: true)
    }
    
    private func runBan(addr: String, subver: String) {
        startRefreshing()
        let param: Set_Ban = .init(dict: ["subnet": addr])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .setban(param)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            stopRefreshing()
            
            guard errorDesc == nil else {
                showAlert(vc: self, title: "", message: errorDesc!)
                return
            }
            
            showHud(addr: addr, subver: subver)
        }
    }
    
    private func showHud(addr: String, subver: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let hud = UIViewController()
            hud.modalPresentationStyle = .overFullScreen
            hud.view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            let l = UILabel()
            l.text = "Banned\n\(addr)\n\(subver)"
            l.numberOfLines = 0
            l.textColor = .white
            l.font = .boldSystemFont(ofSize: 16)
            l.backgroundColor = .systemRed
            l.layer.cornerRadius = 12
            l.clipsToBounds = true
            l.textAlignment = .center
            l.translatesAutoresizingMaskIntoConstraints = false
            hud.view.addSubview(l)
            NSLayoutConstraint.activate([
                l.centerXAnchor.constraint(equalTo: hud.view.centerXAnchor),
                l.centerYAnchor.constraint(equalTo: hud.view.centerYAnchor),
                l.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            ])
            present(hud, animated: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                hud.dismiss(animated: true)
                refreshTapped()
            }
        }
    }
}

    // MARK: - Programmatic PeerCell (No Storyboard, No IBOutlets)
class PeerCell: UITableViewCell {
    static let identifier = "PeerCell"
    var onBanTapped: (() -> Void)?
    
    //private let icon = UIView()
    private let subverLabel = UILabel()
    private let networkBadge = UILabel()
    private let banButton = UIButton(type: .system)
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        backgroundColor = .secondarySystemGroupedBackground
        selectionStyle = .none
        
        subverLabel.font = .systemFont(ofSize: 15, weight: .medium)
        subverLabel.textColor = .label
        subverLabel.numberOfLines = 0
        
        networkBadge.font = .systemFont(ofSize: 11, weight: .bold)
        networkBadge.textColor = .white
        networkBadge.textAlignment = .center
        networkBadge.layer.cornerRadius = 10
        networkBadge.clipsToBounds = true
        
        let vStack = UIStackView(arrangedSubviews: [subverLabel, networkBadge])
        vStack.axis = .vertical
        vStack.spacing = 6
        
        banButton.setTitle("Ban", for: .normal)
        banButton.setTitleColor(.systemRed, for: .normal)
        banButton.titleLabel?.font = .boldSystemFont(ofSize: 15)
        banButton.layer.borderWidth = 1.5
        banButton.layer.borderColor = UIColor.systemRed.cgColor
        banButton.layer.cornerRadius = 14
        banButton.addTarget(self, action: #selector(ban), for: .touchUpInside)
        
        let hStack = UIStackView(arrangedSubviews: [vStack, banButton])
        hStack.axis = .horizontal
        hStack.alignment = .center
        hStack.spacing = 16
        hStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hStack)
        
        NSLayoutConstraint.activate([
            hStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            hStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            hStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            hStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            banButton.widthAnchor.constraint(equalToConstant: 80),
            banButton.heightAnchor.constraint(equalToConstant: 36),
            
            networkBadge.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with peer: PeerInfo) {
        subverLabel.text = peer.subver
            .replacingOccurrences(of: "/", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        let (text, color): (String, UIColor) = {
            switch peer.network {
            case "ipv4": return ("IPv4", .systemBlue)
            case "ipv6": return ("IPv6", .systemPurple)
            case "onion": return ("Tor", .systemOrange)
            case "i2p": return ("I2P", .systemTeal)
            case "cjdns": return ("CJDNS", .systemGreen)
            default: return (peer.network.uppercased(), .systemGray)
            }
        }()
        networkBadge.text = " \(text) "
        networkBadge.backgroundColor = color
    }
    
    @objc private func ban() {
        onBanTapped?()
    }
}

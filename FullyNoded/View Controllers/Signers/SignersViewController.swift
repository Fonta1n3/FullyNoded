//
//  SignersViewController.swift
//  BitSense
//
//  Created by Peter on 04/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

/// Signers list, built in code (purple SignerTheme). The storyboard scene is only the
/// tab's root shell: the + button and the segues to Add Signer and from Create
/// Multisig. Also used by Create Multisig to pick the signer to derive a cosigner xpub
/// from (`isCreatingMsig`).
class SignersViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    /// A signer plus what its row shows (decrypted once per load).
    private struct Row {
        let signer: SignerStruct
        let title: String
        let fingerprint: String?
        let hasPassphrase: Bool
    }

    var signers = [[String:Any]]()
    var id:UUID!
    var isCreatingMsig = false
    var signerSelected: ((SignerStruct) -> Void)?

    private var rows: [Row] = []
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let countLabel = UILabel()
    private let lockWarning = UILabel()
    private let emptyView = UIStackView()
    private let addButton = UIButton(type: .system)
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        if isCreatingMsig { title = "Choose Signer" }
        buildLayout()
        applyTheme()
    }

    /// Cypherpunk deep purple / gray look (see SignerTheme).
    private func applyTheme() {
        view.backgroundColor = SignerTheme.bg
        overrideUserInterfaceStyle = .dark
        SignerTheme.styleNavigation(navigationItem)
        navigationItem.rightBarButtonItem?.tintColor = SignerTheme.accent
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeHeaderToFit()
    }

    // MARK: - Layout

    private func buildLayout() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.indicatorStyle = .white
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.sectionHeaderHeight = 0
        tableView.sectionFooterHeight = 0
        if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 0 }
        tableView.register(ThemedRowCell.self, forCellReuseIdentifier: ThemedRowCell.reuseId)
        tableView.tableHeaderView = summaryHeader()
        tableView.tableFooterView = emptyFooter()
        view.addSubview(tableView)

        // Cards inset 5pt inside the cell (SignerTheme.cardBackground): 11 + 5 = 16pt margins.
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 11),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -11),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    /// "> SIGNERS  n" card with a line on how seeds are kept, and a warning without an
    /// app lock (adding signers needs one).
    private func summaryHeader() -> UIView {
        let tint = WalletTheme.Tint.signer

        countLabel.font = WalletTheme.mono(22, weight: .bold)
        countLabel.textColor = tint.accent
        countLabel.setContentHuggingPriority(.required, for: .horizontal)

        let caption = WalletTheme.caption(isCreatingMsig ? "> CHOOSE A SIGNER" : "> SIGNERS", tint: tint)
        let top = UIStackView(arrangedSubviews: [caption, UIView(), countLabel])
        top.axis = .horizontal
        top.alignment = .center

        let info = UILabel()
        info.text = isCreatingMsig
            ? "Pick the signer to derive this wallet's cosigner xpub from."
            : "Seed words are encrypted on this device and never sent to your node. Tap a signer for its keys, addresses and backups."
        info.font = WalletTheme.mono(11)
        info.textColor = tint.dim
        info.numberOfLines = 0

        lockWarning.text = "⚠ No app lock set. Add one (lock button on the home screen) before adding signers."
        lockWarning.font = WalletTheme.mono(11, weight: .semibold)
        lockWarning.textColor = SignerTheme.danger
        lockWarning.numberOfLines = 0

        let card = WalletTheme.cardView([top, info, lockWarning], tint: tint, spacing: 8, background: SignerTheme.card)

        // Same 5pt inset as the rows' cards.
        let container = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 5),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        return container
    }

    /// Shown when there are no signers: a short explanation and an Add Signer button.
    private func emptyFooter() -> UIView {
        let message = UILabel()
        message.text = "No signers yet. Add one by creating new seed words or importing yours."
        message.font = WalletTheme.mono(12)
        message.textColor = SignerTheme.dim
        message.numberOfLines = 0
        message.textAlignment = .center

        WalletTheme.styleHero(addButton, title: "Add signer", systemImage: "plus", tint: .signer)
        addButton.addTarget(self, action: #selector(addSignerAction(_:)), for: .touchUpInside)

        emptyView.addArrangedSubview(message)
        emptyView.addArrangedSubview(addButton)
        emptyView.axis = .vertical
        emptyView.spacing = 16
        emptyView.isHidden = true
        emptyView.frame = CGRect(x: 0, y: 0, width: 300, height: 170)
        emptyView.isLayoutMarginsRelativeArrangement = true
        emptyView.layoutMargins = UIEdgeInsets(top: 24, left: 5, bottom: 24, right: 5)
        return emptyView
    }

    /// Table header views don't size themselves.
    private func sizeHeaderToFit() {
        guard let header = tableView.tableHeaderView else { return }
        let width = tableView.bounds.width
        let size = header.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                                                  withHorizontalFittingPriority: .required,
                                                  verticalFittingPriority: .fittingSizeLevel)
        if header.frame.size != CGSize(width: width, height: size.height) {
            header.frame = CGRect(x: 0, y: 0, width: width, height: size.height)
            tableView.tableHeaderView = header
        }
    }

    @IBAction func addSignerAction(_ sender: Any) {
        guard let _ = KeyChain.getData("UnlockPassword") else {
            showAlert(vc: self, title: "You are not using the app securely...", message: "You can only add signers if the app has a lock/unlock password. Tap the lock button on the home screen to add a password.")
            
            return
        }
        
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "addSignerSegue", sender: vc)
        }
    }
    
    private func loadData() {
        signers.removeAll()
        CoreDataService.retrieveEntity(entityName: .signers) { [weak self] encryptedSigners in
            guard let self = self else { return }
            
            guard let encryptedSigners = encryptedSigners else {
                self.reload()
                return
            }
            
            self.signers = encryptedSigners
            self.reload()
            
            guard encryptedSigners.count > 0 else { return }
            
            for encryptedSigner in encryptedSigners {
                let signerStruct = SignerStruct(dictionary: encryptedSigner)
                
                var passphrase = ""
                
                if let encryptedPassphrase = signerStruct.passphrase,
                   let decryptedPassphrase = Crypto.decrypt(encryptedPassphrase),
                   let string = decryptedPassphrase.utf8String {
                    passphrase = string
                }
                                
                // Only fires off if account xpubs had not been saved before.
                if signerStruct.xfp == nil,
                   var encryptedWords = signerStruct.words,
                   var decryptedSigner = Crypto.decrypt(encryptedWords),
                   var words = decryptedSigner.utf8String,
                   let mkMain = Keys.masterKey(words: words, coinType: "0", passphrase: passphrase),
                   let xfp = Keys.fingerprint(masterKey: mkMain),
                   let encryptedXfp = Crypto.encrypt(xfp.utf8),
                   let mkTest = Keys.masterKey(words: words, coinType: "1", passphrase: passphrase),
                   let bip86xpub = Keys.bip86AccountXpub(masterKey: mkMain, coinType: "0", account: 0),
                   let bip86tpub = Keys.bip86AccountXpub(masterKey: mkTest, coinType: "1", account: 0),
                   let bip84xpub = Keys.bip84AccountXpub(masterKey: mkMain, coinType: "0", account: 0),
                   let bip84tpub = Keys.bip84AccountXpub(masterKey: mkTest, coinType: "1", account: 0),
                   let bip48xpub = Keys.xpub(path: "m/48'/0'/0'/2'", masterKey: mkMain),
                   let bip48tpub = Keys.xpub(path: "m/48'/1'/0'/2'", masterKey: mkTest),
                   let rootTpub = Keys.xpub(path: "m", masterKey: mkTest),
                   let rootXpub = Keys.xpub(path: "m", masterKey: mkMain),
                   let encryptedRootTpub = Crypto.encrypt(rootTpub.utf8),
                   let encryptedRootXpub = Crypto.encrypt(rootXpub.utf8),
                   let encryptedbip84xpub = Crypto.encrypt(bip84xpub.utf8),
                   let encryptedbip84tpub = Crypto.encrypt(bip84tpub.utf8),
                   let encryptedbip86xpub = Crypto.encrypt(bip86xpub.utf8),
                   let encryptedbip86tpub = Crypto.encrypt(bip86tpub.utf8),
                   let encryptedbip48xpub = Crypto.encrypt(bip48xpub.utf8),
                   let encryptedbip48tpub = Crypto.encrypt(bip48tpub.utf8) {
                                        
                    defer {
                        encryptedWords.secureZero()
                        decryptedSigner.secureZero()
                        words.secureWipe()
                        passphrase.secureWipe()
                    }
                    
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "bip84xpub", newValue: encryptedbip84xpub, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "bip84tpub", newValue: encryptedbip84tpub, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "bip86xpub", newValue: encryptedbip86xpub, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "bip86tpub", newValue: encryptedbip86tpub, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "bip48xpub", newValue: encryptedbip48xpub, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "bip48tpub", newValue: encryptedbip48tpub, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "xfp", newValue: encryptedXfp, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "rootTpub", newValue: encryptedRootTpub, entity: .signers) { _ in }
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "rootXpub", newValue: encryptedRootXpub, entity: .signers) { _ in }
                    
                    print("updated signer")
                }
            }
        }
    }
    
    private func reload() {
        let rows = signers.enumerated().map { index, dict -> Row in
            let signer = SignerStruct(dictionary: dict)
            var fingerprint: String?
            if let encrypted = signer.xfp, let decrypted = Crypto.decrypt(encrypted) {
                fingerprint = decrypted.utf8String
            }
            return Row(signer: signer,
                       title: signer.label == "Signer" ? "Signer #\(index + 1)" : signer.label,
                       fingerprint: fingerprint,
                       hasPassphrase: signer.passphrase != nil)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.rows = rows
            self.countLabel.text = "\(rows.count)"
            self.lockWarning.isHidden = KeyChain.getData("UnlockPassword") != nil || self.isCreatingMsig
            self.emptyView.isHidden = !rows.isEmpty || self.isCreatingMsig
            self.tableView.reloadData()
            self.view.setNeedsLayout()
        }
    }

    // MARK: - Table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ThemedRowCell.reuseId, for: indexPath) as! ThemedRowCell
        let row = rows[indexPath.row]

        var details: [String] = []
        details.append("Added \(Self.dateFormatter.string(from: row.signer.added))")
        if row.hasPassphrase { details.append("passphrase") }

        cell.configure(icon: isCreatingMsig ? "arrow.down.doc" : "signature",
                       title: row.title,
                       subtitle: details.joined(separator: " · "),
                       value: row.fingerprint.map { "[\($0)]" },
                       tint: .signer)
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Each signer as a bordered charcoal card.
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        WalletTheme.squareCorners(cell)
        if cell.backgroundView?.tag != 4242 {
            let card = SignerTheme.cardBackground()
            card.tag = 4242
            cell.backgroundView = card
        }
    }
    
    func seeDetails(_ index: Int) {
        id = rows[index].signer.id
        segueToDetail()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        impact()
        if !isCreatingMsig {
            seeDetails(indexPath.row)
        } else {
            promptToDeriveFromSigner(rows[indexPath.row].signer)
        }
    }
    
    private func promptToDeriveFromSigner(_ signer: SignerStruct) {
        
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            
            guard var encryptedWords = signer.words,
                    var words = Crypto.decrypt(encryptedWords),
                    var arr = words.utf8String?.split(separator: " ") else { return }
            
            defer {
                encryptedWords.secureZero()
                words.secureZero()
                arr.removeAll()
            }
            
            for (i, _) in arr.enumerated() {
                if i > 0 && i < arr.count - 1 {
                    arr[i] = "******"
                }
            }
            
            let alert = UIAlertController(title: "Derive xpub from this signer?", message: arr.joined(separator: " "), preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Derive xpub", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.signerSelected!(signer)
                    self.navigationController?.popViewController(animated: true)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func segueToDetail() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let id = self.id else { return }
    
            // Signer detail is built in code (no storyboard scene).
            let detail = SignerDetailViewController(id: id)
            self.navigationController?.pushViewController(detail, animated: true)
        }
    }

}

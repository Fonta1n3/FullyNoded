import UIKit

// MARK: - Delegate Protocol
protocol AddressInputViewControllerDelegate: AnyObject {
    func addressInputViewController(
        _ controller: AddressInputViewController,
        didConfirmAddress address: String
    )
}

// MARK: - Reusable Address Input Controller (Paste + Scan only)
final class AddressInputViewController: UIViewController {
    
    weak var delegate: AddressInputViewControllerDelegate?
    
    // Customization options
    var titleText: String = "Enter Bitcoin Address"
    var placeholder: String = "bc1q... or taproot address"
    var initialAddress: String?
    
    // UI Elements
    private let titleLabel = UILabel()
    private let textField = UITextField()
    private let buttonStack = UIStackView()
    private let scanButton = UIButton(type: .system)
    private let pasteButton = UIButton(type: .system)
    private let continueButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupActions()
        
        if let initial = initialAddress {
            textField.text = initial
        }
        
        updateContinueButtonState()
    }
    
    private func setupUI() {
        // Title
        titleLabel.text = titleText
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Text Field - display only (keyboard disabled)
        textField.placeholder = placeholder
        textField.borderStyle = .roundedRect
        textField.font = .systemFont(ofSize: 17)
        textField.textAlignment = .center
        textField.backgroundColor = .systemGray6
        textField.isUserInteractionEnabled = true          // still tappable for copy
        textField.isEnabled = true                         // visual feedback
        textField.tintColor = .clear                       // hides cursor
        textField.textColor = .label
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        view.addSubview(textField)
        
        // Button Stack - with spacing between buttons
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.alignment = .center
        buttonStack.spacing = 12                  // ← THIS is the key: space between buttons
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)
        
        // Scan QR Button
        scanButton.setTitle("Scan QR", for: .normal)
        scanButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        scanButton.backgroundColor = .systemGreen
        scanButton.setTitleColor(.white, for: .normal)
        scanButton.layer.cornerRadius = 12
        scanButton.clipsToBounds = true
        buttonStack.addArrangedSubview(scanButton)
        
        // Paste Button
        pasteButton.setTitle("Paste", for: .normal)
        pasteButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        pasteButton.backgroundColor = .systemBlue
        pasteButton.setTitleColor(.white, for: .normal)
        pasteButton.layer.cornerRadius = 12
        pasteButton.clipsToBounds = true
        buttonStack.addArrangedSubview(pasteButton)
        
        // Continue Button
        continueButton.setTitle("Continue", for: .normal)
        continueButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        continueButton.backgroundColor = .systemGray3
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.layer.cornerRadius = 12
        continueButton.isEnabled = false
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(continueButton)
        
        // Layout
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            textField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 36),
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            textField.heightAnchor.constraint(equalToConstant: 54),
            
            buttonStack.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 32),
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            buttonStack.heightAnchor.constraint(equalToConstant: 52),
            
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            continueButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func setupActions() {
        scanButton.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)
        pasteButton.addTarget(self, action: #selector(pasteTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
        
        // Optional: allow long-press copy from text field
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        textField.addGestureRecognizer(longPress)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began, let text = textField.text, !text.isEmpty {
            UIPasteboard.general.string = text
            showAlert(message: "Address copied")
        }
    }
    
    @objc private func scanTapped() {
        presentQRScanner(isScanningAddress: true) { [weak self] potentialAddress in
            guard let self = self else { return }
            self.textField.text = potentialAddress
            self.updateContinueButtonState()
        }
    }
    
    private func presentQRScanner(
        isScanningAddress: Bool = true,
        completion: @escaping (String) -> Void
    ) {
        let scannerVC = ScanQRViewController()
        scannerVC.isScanningAddress = isScanningAddress
        
        scannerVC.onCompletion = { resultString in
            completion(resultString)
        }
        
        scannerVC.modalPresentationStyle = .fullScreen
        present(scannerVC, animated: true)
    }
    
    @objc private func pasteTapped() {
        guard let clipboard = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboard.isEmpty else {
            showAlert(message: "Clipboard is empty")
            return
        }
        
        textField.text = clipboard
        updateContinueButtonState()
    }
    
    @objc private func continueTapped() {
        guard let address = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !address.isEmpty else { return }
        
        delegate?.addressInputViewController(self, didConfirmAddress: address)
        dismiss(animated: true)
    }
    
    @objc private func textFieldDidChange() {
        updateContinueButtonState()
    }
    
    private func updateContinueButtonState() {
        let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        guard !text.isEmpty,
              let network = WalletLogic.shared.bdkNetwork(),
              (try? WalletLogic.BDKAddress(address: text, network: network)) != nil else {
            continueButton.isEnabled = false
            continueButton.backgroundColor = .systemGray
            return
        }
        
        continueButton.isEnabled = true
        continueButton.backgroundColor = .systemOrange
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

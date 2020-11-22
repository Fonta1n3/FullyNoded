//
//  AddSignerViewController.swift
//  BitSense
//
//  Created by Peter on 05/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class AddSignerViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var wordView: UITextView!
    @IBOutlet weak var textView: UITextField!
    @IBOutlet weak var passphraseField: UITextField!
    @IBOutlet weak var addSignerOutlet: UIButton!
    
    var addedWords = [String]()
    var justWords = [String]()
    var bip39Words = [String]()
    var autoCompleteCharacterCount = 0
    var timer = Timer()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        navigationController?.delegate = self
        passphraseField.delegate = self
        textView.delegate = self
        addSignerOutlet.isEnabled = false
        wordView.layer.cornerRadius = 8
        wordView.layer.borderColor = UIColor.lightGray.cgColor
        wordView.layer.borderWidth = 0.5
        addSignerOutlet.clipsToBounds = true
        addSignerOutlet.layer.cornerRadius = 8
        bip39Words = Words.valid
        updatePlaceHolder(wordNumber: 1)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        textView.removeGestureRecognizer(tapGesture)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @IBAction func generateSignerAction(_ sender: Any) {
        guard let words = Keys.seed() else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textView.text = words
            self.processTextfieldInput()
            self.validWordsAdded()
        }
    }
    
    @IBAction func addSignerAction(_ sender: Any) {
        saveLocally()
    }
    
    @IBAction func addWordAction(_ sender: Any) {
        processTextfieldInput()
    }
    
    @IBAction func removeWordAction(_ sender: Any) {
        if justWords.count > 0 {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.wordView.text = ""
                vc.addedWords.removeAll()
                vc.justWords.remove(at: vc.justWords.count - 1)
                
                for (i, word) in vc.justWords.enumerated() {
                    vc.addedWords.append("\(i + 1). \(word)\n")
                    
                    if i == 0 {
                        vc.updatePlaceHolder(wordNumber: i + 1)
                    } else {
                        vc.updatePlaceHolder(wordNumber: i + 2)
                    }
                }
                
                vc.wordView.text = vc.addedWords.joined(separator: "")
                
                if Keys.validMnemonic(vc.justWords.joined(separator: " ")) {
                    vc.validWordsAdded()
                }
            }
        }
    }
    
    private func processTextfieldInput() {
        guard textView.text != "" else {
            shakeAlert(viewToShake: textView)
            return
        }
        
        //check if user pasted more then one word
        let processed = processedCharacters(textView.text!)
        let userAddedWords = processed.split(separator: " ")
        var multipleWords = [String]()
        
        if userAddedWords.count > 1 {
            //user add multiple words
            for (i, word) in userAddedWords.enumerated() {
                var isValid = false
                
                for bip39Word in bip39Words {
                    if word == bip39Word {
                        isValid = true
                        multipleWords.append("\(word)")
                    }
                }
                
                if i + 1 == userAddedWords.count {
                    // we finished our checks
                    if isValid {
                        // they are valid bip39 words
                        addMultipleWords(words: multipleWords)
                        textView.text = ""
                    } else {
                        //they are not all valid bip39 words
                        textView.text = ""
                        showAlert(vc: self, title: "Error", message: "At least one of those words is not a valid BIP39 word. We suggest inputting them one at a time so you can utilize our autosuggest feature which will prevent typos.")
                    }
                }
            }
        } else {
            //its one word
            let processedWord = textView.text!.replacingOccurrences(of: " ", with: "")
            
            for word in bip39Words {
                if processedWord == word {
                    addWord(word: processedWord)
                    textView.text = ""
                }
            }
        }
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        hideKeyboards()
    }
    
    private func hideKeyboards() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.textView.resignFirstResponder()
            vc.passphraseField.resignFirstResponder()
        }
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if passphraseField.isEditing {
            if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
                if self.view.frame.origin.y == 0 {
                    self.view.frame.origin.y -= keyboardSize.height
                }
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if passphraseField.isEditing {
            if self.view.frame.origin.y != 0 {
                self.view.frame.origin.y = 0
            }
        }
    }
    
    private func updatePlaceHolder(wordNumber: Int) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.textView.attributedPlaceholder = NSAttributedString(string: "add word #\(wordNumber)", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        }
    }
    
    private func saveLocally() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let words = self.justWords.joined(separator: " ")
            let mnemonicData = words.dataUsingUTF8StringEncoding
            let passphrase = self.passphraseField.text ?? ""
            
            guard let mk = Keys.masterKey(words: words, coinType: "0", passphrase: passphrase) else { return }
            guard let fingeprint = Keys.fingerprint(masterKey: mk) else { return }
            
            guard let encryptedWords = Crypto.encrypt(mnemonicData) else {
                self.showError(error: "error encrypting your seed")
                
                return
            }
                        
            if passphrase != "" {
                guard let encryptedPassphrase = Crypto.encrypt(passphrase.dataUsingUTF8StringEncoding) else {
                    self.showError(error: "error encrypting your passphrase")
                    
                    return
                }
                
                self.saveSignerAndPassphrase(encryptedWords, encryptedPassphrase, fingeprint)
            } else {
                
                self.saveSigner(encryptedWords, fingeprint)
            }
        }
    }
    
    private func saveSignerAndPassphrase(_ encryptedSigner: Data, _ encryptedPassphrase: Data, _ fingerprint: String) {
        let dict = ["id":UUID(), "words":encryptedSigner, "passphrase":encryptedPassphrase, "added":Date(), "label":fingerprint] as [String:Any]
        CoreDataService.saveEntity(dict: dict, entityName: .signers) { [unowned vc = self] success in
            if success {
                vc.signerAdded()
            } else {
                vc.showError(error: "error saving encrypted seed")
            }
        }
    }
    
    private func saveSigner(_ encryptedSigner: Data, _ fingerprint: String) {
        let dict = ["id":UUID(), "words":encryptedSigner, "added":Date(), "label":fingerprint] as [String:Any]
        CoreDataService.saveEntity(dict: dict, entityName: .signers) { [unowned vc = self] success in
            if success {
                vc.signerAdded()
            } else {
                vc.showError(error: "error saving encrypted seed")
            }
        }
    }
    
    private func showError(error:String) {
        DispatchQueue.main.async { [unowned vc = self] in
            showAlert(vc: vc, title: "Error", message: error)
        }
    }

    private func formatSubstring(subString: String) -> String {
        let formatted = String(subString.dropLast(autoCompleteCharacterCount)).lowercased()
        return formatted
    }
    
    private func resetValues() {
        textView.textColor = .white
        autoCompleteCharacterCount = 0
        textView.text = ""
    }
    
    func searchAutocompleteEntriesWIthSubstring(substring: String) {
        
        let userQuery = substring
        let suggestions = getAutocompleteSuggestions(userText: substring)
        self.textView.textColor = .white
        
        if suggestions.count > 0 {
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { (timer) in
                let autocompleteResult = self.formatAutocompleteResult(substring: substring, possibleMatches: suggestions)
                self.putColorFormattedTextInTextField(autocompleteResult: autocompleteResult, userQuery : userQuery)
                self.moveCaretToEndOfUserQueryPosition(userQuery: userQuery)
            })
            
        } else {
            timer = .scheduledTimer(withTimeInterval: 0.01, repeats: false, block: { [unowned vc = self] (timer) in //7
                vc.textView.text = substring
                
                if Keys.validMnemonic(vc.processedCharacters(vc.textView.text!)) {
                    vc.processTextfieldInput()
                    vc.textView.textColor = .systemGreen
                    vc.validWordsAdded()
                } else {
                    vc.textView.textColor = .systemRed
                }
            })
            autoCompleteCharacterCount = 0
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField != passphraseField {
            var subString = (textField.text!.capitalized as NSString).replacingCharacters(in: range, with: string)
            subString = formatSubstring(subString: subString)
            if subString.count == 0 {
                resetValues()
            } else {
                searchAutocompleteEntriesWIthSubstring(substring: subString)
            }
        }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField != passphraseField {
            processTextfieldInput()
        }
        return true
    }
    
    func getAutocompleteSuggestions(userText: String) -> [String]{
        var possibleMatches: [String] = []
        for item in bip39Words {
            let myString:NSString! = item as NSString
            let substringRange:NSRange! = myString.range(of: userText)
            if (substringRange.location == 0) {
                possibleMatches.append(item)
            }
        }
        return possibleMatches
    }
    
    func putColorFormattedTextInTextField(autocompleteResult: String, userQuery : String) {
        let coloredString: NSMutableAttributedString = NSMutableAttributedString(string: userQuery + autocompleteResult)
        coloredString.addAttribute(NSAttributedString.Key.foregroundColor,
                                   value: UIColor.systemGreen,
                                   range: NSRange(location: userQuery.count,length:autocompleteResult.count))
        self.textView.attributedText = coloredString
    }
    
    func moveCaretToEndOfUserQueryPosition(userQuery : String) {
        if let newPosition = self.textView.position(from: self.textView.beginningOfDocument, offset: userQuery.count) {
            self.textView.selectedTextRange = self.textView.textRange(from: newPosition, to: newPosition)
        }
        let selectedRange: UITextRange? = textView.selectedTextRange
        textView.offset(from: textView.beginningOfDocument, to: (selectedRange?.start)!)
    }
    
    func formatAutocompleteResult(substring: String, possibleMatches: [String]) -> String {
        var autoCompleteResult = possibleMatches[0]
        autoCompleteResult.removeSubrange(autoCompleteResult.startIndex..<autoCompleteResult.index(autoCompleteResult.startIndex, offsetBy: substring.count))
        autoCompleteCharacterCount = autoCompleteResult.count
        return autoCompleteResult
    }
    
    private func addMultipleWords(words: [String]) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.wordView.text = ""
            vc.addedWords.removeAll()
            vc.justWords = words
            
            for (i, word) in vc.justWords.enumerated() {
                vc.addedWords.append("\(i + 1). \(word)\n")
                vc.updatePlaceHolder(wordNumber: i + 2)
            }
            
            vc.wordView.text = vc.addedWords.joined(separator: "")
        }
    }
    
    private func addWord(word: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.wordView.text = ""
            vc.addedWords.removeAll()
            vc.justWords.append(word)
            
            for (i, word) in vc.justWords.enumerated() {
                vc.addedWords.append("\(i + 1). \(word)\n")
                vc.updatePlaceHolder(wordNumber: i + 2)
                
            }
            
            vc.wordView.text = vc.addedWords.joined(separator: "")
            
            if Keys.validMnemonic(vc.justWords.joined(separator: " ")) {
                vc.validWordsAdded()
            }
            
            vc.textView.becomeFirstResponder()
        }
    }
    
    private func processedCharacters(_ string: String) -> String {
        var result = string.filter("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ ".contains)
        result = result.condenseWhitespace()
        return result
    }
    
    private func validWordsAdded() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.textView.resignFirstResponder()
            vc.addSignerOutlet.isEnabled = true
        }
        showAlert(vc: self, title: "Valid Words ✓", message: "That is a valid recovery phrase, tap \"add signer\" to encrypt it and save it securely to the device so that it may sign your psbt's.")
    }
    
    private func signerAdded() {
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Signer successfully encrypted and saved securely to your device.", message: "Tap done", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.navigationController?.popViewController(animated: true)
                }
            }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

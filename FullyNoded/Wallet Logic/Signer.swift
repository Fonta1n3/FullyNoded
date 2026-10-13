//
//  Signer.swift
//  BitSense
//
//  Created by Peter on 28/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

class Signer {

    static let shared = Signer()

    private init(){}

    /// Signs `psbt` with every stored signer whose fingerprint appears in `utxoParentDesc`.
    ///
    /// - `passphrase`: the passphrase typed at signing time (passphrase prompt). If nil, no
    ///   passphrase is used. The signer's stored passphrase is never looked up.
    /// - Signatures are CHAINED: each signer signs the psbt produced by the previous one,
    ///   so a multisig wallet with several hot signers gets all their signatures.
    /// - Completion: rawTx if finalized; otherwise the (partially) signed psbt; otherwise
    ///   an error message explaining why nothing was signed.
    func attemptToSignPsbt(fnWallet: Wallet,
                           psbt: String,
                           passphrase: String?,
                           utxoParentDesc: String,
                           completion: @escaping ((psbt: String?, rawTx: String?, errorMessage: String?)) -> Void) {

        guard let bdkNetwork = WalletLogic.shared.bdkNetwork() else {
            completion((nil, nil, "Failed getting bdkNetwork."))
            return
        }

        // Only the typed passphrase is ever used; nil means no passphrase.
        let typedPassphrase = passphrase ?? ""

        CoreDataService.retrieveEntity(entityName: .signers) { [weak self] signers in
            guard let self = self else { return }

            guard let signers = signers, signers.count > 0 else {
                completion((nil, nil, "No signers."))
                return
            }

            #if DEBUG
            print("utxoParentDesc: \(utxoParentDesc)")
            #endif

            let fnDesc = Descriptor(utxoParentDesc)
            var signerArray: [SignerStruct] = []

            for signer in signers {
                let signerStr = SignerStruct(dictionary: signer)

                // Only signers that hold seed words can sign.
                guard signerStr.words != nil else { continue }

                if let xfp = self.fingerprint(of: signerStr, typedPassphrase: typedPassphrase),
                   fnDesc.fingerprint.contains(xfp) {
                    signerArray.append(signerStr)
                }
            }

            guard !signerArray.isEmpty else {
                completion((nil, nil, "None of your signers match this wallet's fingerprints, so nothing was signed."))
                return
            }

            self.sign(fnWallet: fnWallet,
                      psbt: psbt,
                      passphrase: typedPassphrase,
                      signers: signerArray,
                      network: bdkNetwork,
                      parentDesc: utxoParentDesc,
                      completion: completion)
        }
    }

    /// The signer's master key fingerprint: the stored (encrypted) one if present,
    /// otherwise derived from the seed words with the TYPED passphrase. The signer's
    /// stored passphrase is never read. A fingerprint derived here isn't saved, so a
    /// mistyped passphrase can't permanently record the wrong fingerprint.
    private func fingerprint(of signer: SignerStruct, typedPassphrase: String) -> String? {
        if let encryptedXfp = signer.xfp,
           let decryptedXfp = Crypto.decrypt(encryptedXfp),
           let xfp = decryptedXfp.utf8String {
            return xfp
        }

        guard var encryptedWords = signer.words,
              var decryptedWords = Crypto.decrypt(encryptedWords),
              var words = decryptedWords.utf8String else {
            return nil
        }

        defer {
            decryptedWords.secureZero()
            encryptedWords.secureZero()
            words.secureWipe()
        }

        guard let mk = Keys.masterKey(words: words, coinType: "0", passphrase: typedPassphrase),
              let xfp = Keys.fingerprint(masterKey: mk) else {
            return nil
        }

        return xfp
    }

    func sign(fnWallet: Wallet,
              psbt: String,
              passphrase: String?,
              signers: [SignerStruct],
              network: WalletLogic.BDKNetwork,
              parentDesc: String,
              completion: @escaping ((psbt: String?, rawTx: String?, errorMessage: String?)) -> Void) {

        // Each signer signs the output of the previous one.
        var currentPsbt = psbt
        var signedAny = false
        var errors: [String] = []

        var receiveDesc = parentDesc
        var changeDesc = fnWallet.changeDescriptor

        // if its change the parent desc will be the change desc...
        if parentDesc.contains("/1/") {
            changeDesc = parentDesc.replacingOccurrences(of: "/1/", with: "/0/")
        }

        // combo() (Bitcoin Core only; BDK can't parse it): sign through the BDK descriptors of
        // the same key that match the coins being spent.
        if Self.isCombo(parentDesc) {
            switch Self.comboSigningDescriptors(parentDesc, psbt: psbt) {
            case .success(let pair):
                receiveDesc = pair.receive
                changeDesc = pair.change
            case .failure(let error):
                completion((nil, nil, error.message))
                return
            }
        }

        for signerStruct in signers {
            guard var encryptedWords = signerStruct.words,
                  var decryptedData = Crypto.decrypt(encryptedWords),
                  var words = String(bytes: decryptedData, encoding: .utf8) else {
                errors.append("Unable to decrypt the seed words of signer \"\(signerStruct.label)\".")
                continue
            }

            defer {
                decryptedData.secureZero()
                words.secureWipe()
                encryptedWords.secureZero()
            }

            guard let bdkMnemonic = try? WalletLogic.BDKMnemonic.fromString(mnemonic: words) else {
                errors.append("Signer \"\(signerStruct.label)\" has invalid seed words.")
                continue
            }

            // WalletLogic.wallet(...) completes synchronously. If it never calls back,
            // treat that as a failure instead of silently skipping the signer.
            var walletResult: (bdkWallet: WalletLogic.BDKWallet?, errorMessage: String?)?

            // Only ever the passphrase the user typed.
            WalletLogic.shared.wallet(passphrase: passphrase ?? "",
                                      network: network,
                                      mnemonic: bdkMnemonic,
                                      recDescStr: receiveDesc,
                                      changeDesStr: changeDesc,
                                      completion: { result in
                walletResult = result
            })

            guard let result = walletResult, let bdkWallet = result.bdkWallet else {
                // Usually: this signer's keys (with this passphrase) aren't in the wallet's
                // descriptor. Not fatal while other signers can still sign.
                #if DEBUG
                print("bdkWallet creation failed for signer \(signerStruct.label): \(walletResult?.errorMessage ?? "no result")")
                #endif
                errors.append(walletResult?.errorMessage ?? "Signer \"\(signerStruct.label)\" couldn't produce keys for this wallet (wrong passphrase?).")
                continue
            }

            let (signedPsbt, signedRawTx, errorMessage) = WalletLogic.shared.signPsbt(wallet: bdkWallet, psbtBase64: currentPsbt)
            #if DEBUG
            print("rawTx: \(signedRawTx ?? "")")
            #endif

            if let signedRawTx = signedRawTx {
                // Fully signed and finalized: nothing more to do.
                completion((nil, signedRawTx, nil))
                return
            } else if let signedPsbt = signedPsbt {
                currentPsbt = signedPsbt
                signedAny = true
            } else {
                errors.append(errorMessage ?? "Signer \"\(signerStruct.label)\" failed to sign.")
            }
        }

        if signedAny {
            completion((currentPsbt, nil, nil))
        } else {
            completion((nil, nil, errors.first ?? "No signatures were added."))
        }
    }

    // MARK: combo()

    struct ComboError: Error { let message: String }

    static func isCombo(_ desc: String) -> Bool {
        desc.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("combo(")
    }

    /// combo(K) is pk(K), pkh(K), wpkh(K) and sh(wpkh(K)). BDK can't parse it, and it decides
    /// legacy vs segwit signing from the descriptor, so the pair follows the PSBT's inputs:
    /// wpkh(K) + sh(wpkh(K)) for segwit coins, pkh(K) + sh(pkh(K)) for legacy ones (a BDK wallet
    /// needs two different descriptors; these are the same key, signed the same way). Coins of
    /// both kinds can't share one signing pass, and bare P2PK isn't supported (BDK crashes on
    /// pk()).
    static func comboSigningDescriptors(_ desc: String, psbt: String) -> Result<(receive: String, change: String), ComboError> {
        let checksumless = desc.components(separatedBy: "#")[0].trimmingCharacters(in: .whitespaces)
        guard checksumless.hasSuffix(")"), checksumless.count > "combo()".count else {
            return .failure(ComboError(message: "Unrecognised combo descriptor."))
        }
        let key = String(checksumless.dropFirst("combo(".count).dropLast())

        guard let raw = Data(base64Encoded: psbt.trimmingCharacters(in: .whitespacesAndNewlines)),
              let parsed = try? SPPsbt(raw) else {
            return .failure(ComboError(message: "Unable to read the psbt's inputs."))
        }
        var segwit = false, legacy = false
        for i in parsed.tx.inputs.indices {
            guard let prevout = try? parsed.prevout(input: i) else {
                return .failure(ComboError(message: "Input \(i) has no UTXO data, so its script type is unknown."))
            }
            let spk = prevout.script.map { String(format: "%02x", $0) }.joined()
            if SPDetect.isP2WPKH(spk) || SPDetect.isP2SH(spk) {
                segwit = true
            } else if SPDetect.isP2PKH(spk) {
                legacy = true
            } else if (spk.count == 70 && spk.hasPrefix("21") || spk.count == 134 && spk.hasPrefix("41")) && spk.hasSuffix("ac") {
                return .failure(ComboError(message: "Input \(i) is a bare P2PK output, which can't be signed here."))
            }
        }
        if segwit && legacy {
            return .failure(ComboError(message: "This transaction spends both segwit and legacy coins of a combo() wallet. Spend them in separate transactions."))
        }
        return .success(legacy ? ("pkh(\(key))", "sh(pkh(\(key)))") : ("wpkh(\(key))", "sh(wpkh(\(key)))"))
    }
}

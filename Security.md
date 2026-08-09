Security.md

SECURITY.md for Fully Noded
# Security Policy

## Overview

Fully Noded is a self-sovereign Bitcoin wallet (iOS/macOS, Swift) that uses the user’s own Bitcoin Core (or compatible) node as backend. It emphasizes privacy, offline signing, and local key control. Private keys / BIP39 signers never leave the device unencrypted and are never sent to the node. The node operates in a watch-only capacity. Communications preferably occur over Tor (with optional Tor v3 client authentication, https is possible but only recommended for LAN). PSBTs are constructed via the node and signed locally using Bitcoin Dev Kit.

This document describes the project’s security posture, supported versions, vulnerability reporting process, and recommended practices for users and contributors.

## Supported Versions

Security updates and vulnerability fixes are applied to the latest stable release and the current development branch (`master`).

| Version          | Supported          |
|------------------|--------------------|
| Latest release   | ✅                 |
| Previous releases| ❌ (upgrade recommended) |
| master branch    | ✅ (development)   |

Users should always run the newest App Store or source-built version. Older releases may contain unpatched issues.

## Reporting a Vulnerability

**Do not open public GitHub issues for security vulnerabilities.**

Please report suspected security issues privately and responsibly:

- **Preferred contact**: dentondevelopment@protonmail.com
- Include a clear description, steps to reproduce (if possible), affected version(s), impact assessment, and any proof-of-concept.
- Encrypt sensitive details with the project PGP key when possible:
297D 3AA6 F231 4CD0 E023 CD9B 7C85 7452 1475 38F5
- Allow reasonable time for acknowledgment and remediation before any public disclosure.

The maintainer will acknowledge valid reports, coordinate fixes, and credit reporters (unless anonymity is requested). Critical issues affecting key material, signing, or remote code execution receive highest priority.

## Security Architecture Highlights

### Key & Secret Management
- BIP39 mnemonics / signers and sensitive data are stored **double-encrypted** on-device.
- Encryption uses **ChaChaPoly** (AEAD) via CryptoKit.
- Symmetric keys are retrieved from the iOS/macOS Keychain (`KeyChain` helper).
- Signing occurs offline; private keys are never exposed to network requests or the node.
- Randomness source is `SecRandomCopyBytes`.
- Bitcoin Dev Kit handles BIP39, HD derivation, and PSBT signing.
- Duress PIN will erase all of the apps data but will still function normally.

### Network & Node Communication
- Preferred path: Tor hidden service (onion) to the user’s Bitcoin Core RPC.
- Optional **Tor v3 client authentication** (x25519) for strong mutual authentication.
- RPC credentials are stored encrypted and used only for authenticated calls.
- Localhost / LAN connections are supported but reduce privacy guarantees, SSL cert can be added in node credentials for this purpose.
- No third-party servers, indexers, or remote wallets are required.

### Application-Level Protections
- Optional strong **app unlock password** (persists across reinstalls; Keychain-backed with anti-bruteforce timeout).
- Biometrics can be disabled (recommended for threat models involving physical access).
- Wallet export files and QR codes deliberately exclude private keys.

### Dependencies & Build
- Core crypto: CryptoKit + Bitcoin Dev Kit.
- Tor: Tor.framework.
- Other: Base32, Base58, Blockchain Commons UR components (licensed separately).
- Releases and source are PGP-signed.
- License: GPL-3.0 (App Store redistribution requires separate relicensing arrangement).

### Known Design Considerations
- Keychain usage relies on system defaults for accessibility attributes in some paths; users should combine with device passcode + unlock password.
- Full security depends on correct node + Tor configuration (firewall, hidden service isolation, RPC authentication, pruned vs full node considerations).
- The app is defensive by design but is not formally audited in the public record at the time of this writing. Independent review is encouraged.

## User Security Recommendations

Follow the project’s existing documentation (especially `Docs/Security-Best-Practices.md` and `Docs/Backup-Recovery-Best-Practices.md`):

1. Run your own node and connect via Tor + v3 authentication whenever possible.
2. Enable the strong unlock password.
3. Prefer disabling biometrics under elevated threat models.
4. Back up signers offline (paper/metal) in multiple secure locations. Test recovery.
5. Use a strong, offline-saved passphrase for iCloud encryption; consider a dedicated 12-word dummy signer.
6. Encrypt any exported wallet files (GPG or equivalent).
7. Keep the device OS and the app updated.
8. Verify release signatures and hashes.
9. Treat the node machine with high care (dedicated hardware, minimal services, firewall).
10. Never enter seed phrases into untrusted environments.
11. Utilize the duress PIN.

## Dependency & Supply-Chain Notes

- No npm/Node.js runtime is involved in the core app (pure native Swift + frameworks).

## Acknowledgments & Continuous Improvement

Security is a process. Reports, independent audits, reproducible-build verification, and hardening contributions are welcome. Past support from organizations such as OpenSats and the Human Rights Foundation is gratefully acknowledged.

For non-security questions see the repository README, Docs/, and existing issues.

---



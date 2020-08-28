//
//  PSBTTests.swift
//  PSBTTests 
//
//  Created by Sjors Provoost on 16/12/2019.
//  Copyright © 2019 Sjors Provoost. Distributed under the MIT software
//  license, see the accompanying file LICENSE.md

import XCTest
@testable import LibWally
import CLibWally

class PSBTTests: XCTestCase {
    // Test vectors from https://github.com/bitcoin/bips/blob/master/bip-0174.mediawiki
    let fingerprint = Data("d90c6a4f")!
    
    let validPSBT = "cHNidP8BAHUCAAAAASaBcTce3/KF6Tet7qSze3gADAVmy7OtZGQXE8pCFxv2AAAAAAD+////AtPf9QUAAAAAGXapFNDFmQPFusKGh2DpD9UhpGZap2UgiKwA4fUFAAAAABepFDVF5uM7gyxHBQ8k0+65PJwDlIvHh7MuEwAAAQD9pQEBAAAAAAECiaPHHqtNIOA3G7ukzGmPopXJRjr6Ljl/hTPMti+VZ+UBAAAAFxYAFL4Y0VKpsBIDna89p95PUzSe7LmF/////4b4qkOnHf8USIk6UwpyN+9rRgi7st0tAXHmOuxqSJC0AQAAABcWABT+Pp7xp0XpdNkCxDVZQ6vLNL1TU/////8CAMLrCwAAAAAZdqkUhc/xCX/Z4Ai7NK9wnGIZeziXikiIrHL++E4sAAAAF6kUM5cluiHv1irHU6m80GfWx6ajnQWHAkcwRAIgJxK+IuAnDzlPVoMR3HyppolwuAJf3TskAinwf4pfOiQCIAGLONfc0xTnNMkna9b7QPZzMlvEuqFEyADS8vAtsnZcASED0uFWdJQbrUqZY3LLh+GFbTZSYG2YVi/jnF6efkE/IQUCSDBFAiEA0SuFLYXc2WHS9fSrZgZU327tzHlMDDPOXMMJ/7X85Y0CIGczio4OFyXBl/saiK9Z9R5E5CVbIBZ8hoQDHAXR8lkqASECI7cr7vCWXRC+B3jv7NYfysb3mk6haTkzgHNEZPhPKrMAAAAAAAAA"
    
    let finalizedPSBT = "cHNidP8BAJoCAAAAAljoeiG1ba8MI76OcHBFbDNvfLqlyHV5JPVFiHuyq911AAAAAAD/////g40EJ9DsZQpoqka7CwmK6kQiwHGyyng1Kgd5WdB86h0BAAAAAP////8CcKrwCAAAAAAWABTYXCtx0AYLCcmIauuBXlCZHdoSTQDh9QUAAAAAFgAUAK6pouXw+HaliN9VRuh0LR2HAI8AAAAAAAEAuwIAAAABqtc5MQGL0l+ErkALaISL4J23BurCrBgpi6vucatlb4sAAAAASEcwRAIgWPb8fGoz4bMVSNSByCbAFb0wE1qtQs1neQ2rZtKtJDsCIEoc7SYExnNbY5PltBaR3XiwDwxZQvufdRhW+qk4FX26Af7///8CgPD6AgAAAAAXqRQPuUY0IWlrgsgzryQceMF9295JNIfQ8gonAQAAABepFCnKdPigj4GZlCgYXJe12FLkBj9hh2UAAAABB9oARzBEAiB0AYrUGACXuHMyPAAVcgs2hMyBI4kQSOfbzZtVrWecmQIgc9Npt0Dj61Pc76M4I8gHBRTKVafdlUTxV8FnkTJhEYwBSDBFAiEA9hA4swjcHahlo0hSdG8BV3KTQgjG0kRUOTzZm98iF3cCIAVuZ1pnWm0KArhbFOXikHTYolqbV2C+ooFvZhkQoAbqAUdSIQKVg785rgpgl0etGZrd1jT6YQhVnWxc05tMIYPxq5bgfyEC2rYf9JoU22p9ArDNH7t4/EsYMStbTlTa5Nui+/71NtdSrgABASAAwusLAAAAABepFLf1+vQOPUClpFmx2zU18rcvqSHohwEHIyIAIIwjUxc3Q7WV37Sge3K6jkLjeX2nTof+fZ10l+OyAokDAQjaBABHMEQCIGLrelVhB6fHP0WsSrWh3d9vcHX7EnWWmn84Pv/3hLyyAiAMBdu3Rw2/LwhVfdNWxzJcHtMJE+mWzThAlF2xIijaXwFHMEQCIGX0W6WZi1mif/4ae+0BavHx+Q1Us6qPdFCqX1aiUQO9AiB/ckcDrR7blmgLKEtW1P/LiPf7dZ6rvgiqMPKbhROD0gFHUiEDCJ3BDHrG21T5EymvYXMz2ziM6tDCMfcjN50bmQMLAtwhAjrdkE89bc9Z3bkGsN7iNSm3/7ntUOXoYVGSaGAiHw5zUq4AIgIDqaTDf1mW06ol26xrVwrwZQOUSSlCRgs1R1Ptnuylh3EQ2QxqTwAAAIAAAACABAAAgAAiAgJ/Y5l1fS7/VaE2rQLGhLGDi2VW5fG2s0KCqUtrUAUQlhDZDGpPAAAAgAAAAIAFAACAAA=="

    // Test vector at "An updater which adds SIGHASH_ALL to the above PSBT must create this PSBT"
    let unsignedPSBT = "cHNidP8BAJoCAAAAAljoeiG1ba8MI76OcHBFbDNvfLqlyHV5JPVFiHuyq911AAAAAAD/////g40EJ9DsZQpoqka7CwmK6kQiwHGyyng1Kgd5WdB86h0BAAAAAP////8CcKrwCAAAAAAWABTYXCtx0AYLCcmIauuBXlCZHdoSTQDh9QUAAAAAFgAUAK6pouXw+HaliN9VRuh0LR2HAI8AAAAAAAEAuwIAAAABqtc5MQGL0l+ErkALaISL4J23BurCrBgpi6vucatlb4sAAAAASEcwRAIgWPb8fGoz4bMVSNSByCbAFb0wE1qtQs1neQ2rZtKtJDsCIEoc7SYExnNbY5PltBaR3XiwDwxZQvufdRhW+qk4FX26Af7///8CgPD6AgAAAAAXqRQPuUY0IWlrgsgzryQceMF9295JNIfQ8gonAQAAABepFCnKdPigj4GZlCgYXJe12FLkBj9hh2UAAAABAwQBAAAAAQRHUiEClYO/Oa4KYJdHrRma3dY0+mEIVZ1sXNObTCGD8auW4H8hAtq2H/SaFNtqfQKwzR+7ePxLGDErW05U2uTbovv+9TbXUq4iBgKVg785rgpgl0etGZrd1jT6YQhVnWxc05tMIYPxq5bgfxDZDGpPAAAAgAAAAIAAAACAIgYC2rYf9JoU22p9ArDNH7t4/EsYMStbTlTa5Nui+/71NtcQ2QxqTwAAAIAAAACAAQAAgAABASAAwusLAAAAABepFLf1+vQOPUClpFmx2zU18rcvqSHohwEDBAEAAAABBCIAIIwjUxc3Q7WV37Sge3K6jkLjeX2nTof+fZ10l+OyAokDAQVHUiEDCJ3BDHrG21T5EymvYXMz2ziM6tDCMfcjN50bmQMLAtwhAjrdkE89bc9Z3bkGsN7iNSm3/7ntUOXoYVGSaGAiHw5zUq4iBgI63ZBPPW3PWd25BrDe4jUpt/+57VDl6GFRkmhgIh8OcxDZDGpPAAAAgAAAAIADAACAIgYDCJ3BDHrG21T5EymvYXMz2ziM6tDCMfcjN50bmQMLAtwQ2QxqTwAAAIAAAACAAgAAgAAiAgOppMN/WZbTqiXbrGtXCvBlA5RJKUJGCzVHU+2e7KWHcRDZDGpPAAAAgAAAAIAEAACAACICAn9jmXV9Lv9VoTatAsaEsYOLZVbl8bazQoKpS2tQBRCWENkMak8AAACAAAAAgAUAAIAA"
    
    let signedPSBT = "cHNidP8BAJoCAAAAAljoeiG1ba8MI76OcHBFbDNvfLqlyHV5JPVFiHuyq911AAAAAAD/////g40EJ9DsZQpoqka7CwmK6kQiwHGyyng1Kgd5WdB86h0BAAAAAP////8CcKrwCAAAAAAWABTYXCtx0AYLCcmIauuBXlCZHdoSTQDh9QUAAAAAFgAUAK6pouXw+HaliN9VRuh0LR2HAI8AAAAAAAEAuwIAAAABqtc5MQGL0l+ErkALaISL4J23BurCrBgpi6vucatlb4sAAAAASEcwRAIgWPb8fGoz4bMVSNSByCbAFb0wE1qtQs1neQ2rZtKtJDsCIEoc7SYExnNbY5PltBaR3XiwDwxZQvufdRhW+qk4FX26Af7///8CgPD6AgAAAAAXqRQPuUY0IWlrgsgzryQceMF9295JNIfQ8gonAQAAABepFCnKdPigj4GZlCgYXJe12FLkBj9hh2UAAAAiAgKVg785rgpgl0etGZrd1jT6YQhVnWxc05tMIYPxq5bgf0cwRAIgdAGK1BgAl7hzMjwAFXILNoTMgSOJEEjn282bVa1nnJkCIHPTabdA4+tT3O+jOCPIBwUUylWn3ZVE8VfBZ5EyYRGMASICAtq2H/SaFNtqfQKwzR+7ePxLGDErW05U2uTbovv+9TbXSDBFAiEA9hA4swjcHahlo0hSdG8BV3KTQgjG0kRUOTzZm98iF3cCIAVuZ1pnWm0KArhbFOXikHTYolqbV2C+ooFvZhkQoAbqAQEDBAEAAAABBEdSIQKVg785rgpgl0etGZrd1jT6YQhVnWxc05tMIYPxq5bgfyEC2rYf9JoU22p9ArDNH7t4/EsYMStbTlTa5Nui+/71NtdSriIGApWDvzmuCmCXR60Zmt3WNPphCFWdbFzTm0whg/GrluB/ENkMak8AAACAAAAAgAAAAIAiBgLath/0mhTban0CsM0fu3j8SxgxK1tOVNrk26L7/vU21xDZDGpPAAAAgAAAAIABAACAAAEBIADC6wsAAAAAF6kUt/X69A49QKWkWbHbNTXyty+pIeiHIgIDCJ3BDHrG21T5EymvYXMz2ziM6tDCMfcjN50bmQMLAtxHMEQCIGLrelVhB6fHP0WsSrWh3d9vcHX7EnWWmn84Pv/3hLyyAiAMBdu3Rw2/LwhVfdNWxzJcHtMJE+mWzThAlF2xIijaXwEiAgI63ZBPPW3PWd25BrDe4jUpt/+57VDl6GFRkmhgIh8Oc0cwRAIgZfRbpZmLWaJ//hp77QFq8fH5DVSzqo90UKpfVqJRA70CIH9yRwOtHtuWaAsoS1bU/8uI9/t1nqu+CKow8puFE4PSAQEDBAEAAAABBCIAIIwjUxc3Q7WV37Sge3K6jkLjeX2nTof+fZ10l+OyAokDAQVHUiEDCJ3BDHrG21T5EymvYXMz2ziM6tDCMfcjN50bmQMLAtwhAjrdkE89bc9Z3bkGsN7iNSm3/7ntUOXoYVGSaGAiHw5zUq4iBgI63ZBPPW3PWd25BrDe4jUpt/+57VDl6GFRkmhgIh8OcxDZDGpPAAAAgAAAAIADAACAIgYDCJ3BDHrG21T5EymvYXMz2ziM6tDCMfcjN50bmQMLAtwQ2QxqTwAAAIAAAACAAgAAgAAiAgOppMN/WZbTqiXbrGtXCvBlA5RJKUJGCzVHU+2e7KWHcRDZDGpPAAAAgAAAAIAEAACAACICAn9jmXV9Lv9VoTatAsaEsYOLZVbl8bazQoKpS2tQBRCWENkMak8AAACAAAAAgAUAAIAA"
    
    let masterKeyXpriv = "tprv8ZgxMBicQKsPd9TeAdPADNnSyH9SSUUbTVeFszDE23Ki6TBB5nCefAdHkK8Fm3qMQR6sHwA56zqRmKmxnHk37JkiFzvncDqoKmPWubu7hDF"
    
    // Paths
    let path0 = BIP32Path("m/0'/0'/0'")!
    let path1 = BIP32Path("m/0'/0'/1'")!
    let path2 = BIP32Path("m/0'/0'/2'")!
    let path3 = BIP32Path("m/0'/0'/3'")!
    let path4 = BIP32Path("m/0'/0'/4'")!
    let path5 = BIP32Path("m/0'/0'/5'")!
    
    // Private keys (testnet)
    let WIF_0 = "cP53pDbR5WtAD8dYAW9hhTjuvvTVaEiQBdrz9XPrgLBeRFiyCbQr" // m/0'/0'/0'
    let WIF_1 = "cT7J9YpCwY3AVRFSjN6ukeEeWY6mhpbJPxRaDaP5QTdygQRxP9Au" // m/0'/0'/1'
    let WIF_2 = "cR6SXDoyfQrcp4piaiHE97Rsgta9mNhGTen9XeonVgwsh4iSgw6d" // m/0'/0'/2'
    let WIF_3 = "cNBc3SWUip9PPm1GjRoLEJT6T41iNzCYtD7qro84FMnM5zEqeJsE" // m/0'/0'/3'
    
    // Public keys
    let pubKey0 = PubKey(Data("029583bf39ae0a609747ad199addd634fa6108559d6c5cd39b4c2183f1ab96e07f")!, .testnet)!
    let pubKey1 = PubKey(Data("02dab61ff49a14db6a7d02b0cd1fbb78fc4b18312b5b4e54dae4dba2fbfef536d7")!, .testnet)!
    let pubKey2 = PubKey(Data("03089dc10c7ac6db54f91329af617333db388cead0c231f723379d1b99030b02dc")!, .testnet)!
    let pubKey3 = PubKey(Data("023add904f3d6dcf59ddb906b0dee23529b7ffb9ed50e5e86151926860221f0e73")!, .testnet)!
    let pubKey4 = PubKey(Data("03a9a4c37f5996d3aa25dbac6b570af0650394492942460b354753ed9eeca58771")!, .testnet)!
    let pubKey5 = PubKey(Data("027f6399757d2eff55a136ad02c684b1838b6556e5f1b6b34282a94b6b50051096")!, .testnet)!
    
    // Singed with keys m/0'/0'/0' and m/0'/0'/2'
    let signedPSBT_0_2 = "cHNidP8BAJoCAAAAAljoeiG1ba8MI76OcHBFbDNvfLqlyHV5JPVFiHuyq911AAAAAAD/////g40EJ9DsZQpoqka7CwmK6kQiwHGyyng1Kgd5WdB86h0BAAAAAP////8CcKrwCAAAAAAWABTYXCtx0AYLCcmIauuBXlCZHdoSTQDh9QUAAAAAFgAUAK6pouXw+HaliN9VRuh0LR2HAI8AAAAAAAEAuwIAAAABqtc5MQGL0l+ErkALaISL4J23BurCrBgpi6vucatlb4sAAAAASEcwRAIgWPb8fGoz4bMVSNSByCbAFb0wE1qtQs1neQ2rZtKtJDsCIEoc7SYExnNbY5PltBaR3XiwDwxZQvufdRhW+qk4FX26Af7///8CgPD6AgAAAAAXqRQPuUY0IWlrgsgzryQceMF9295JNIfQ8gonAQAAABepFCnKdPigj4GZlCgYXJe12FLkBj9hh2UAAAAiAgKVg785rgpgl0etGZrd1jT6YQhVnWxc05tMIYPxq5bgf0cwRAIgdAGK1BgAl7hzMjwAFXILNoTMgSOJEEjn282bVa1nnJkCIHPTabdA4+tT3O+jOCPIBwUUylWn3ZVE8VfBZ5EyYRGMAQEDBAEAAAABBEdSIQKVg785rgpgl0etGZrd1jT6YQhVnWxc05tMIYPxq5bgfyEC2rYf9JoU22p9ArDNH7t4/EsYMStbTlTa5Nui+/71NtdSriIGApWDvzmuCmCXR60Zmt3WNPphCFWdbFzTm0whg/GrluB/ENkMak8AAACAAAAAgAAAAIAiBgLath/0mhTban0CsM0fu3j8SxgxK1tOVNrk26L7/vU21xDZDGpPAAAAgAAAAIABAACAAAEBIADC6wsAAAAAF6kUt/X69A49QKWkWbHbNTXyty+pIeiHIgIDCJ3BDHrG21T5EymvYXMz2ziM6tDCMfcjN50bmQMLAtxHMEQCIGLrelVhB6fHP0WsSrWh3d9vcHX7EnWWmn84Pv/3hLyyAiAMBdu3Rw2/LwhVfdNWxzJcHtMJE+mWzThAlF2xIijaXwEBAwQBAAAAAQQiACCMI1MXN0O1ld+0oHtyuo5C43l9p06H/n2ddJfjsgKJAwEFR1IhAwidwQx6xttU+RMpr2FzM9s4jOrQwjH3IzedG5kDCwLcIQI63ZBPPW3PWd25BrDe4jUpt/+57VDl6GFRkmhgIh8Oc1KuIgYCOt2QTz1tz1nduQaw3uI1Kbf/ue1Q5ehhUZJoYCIfDnMQ2QxqTwAAAIAAAACAAwAAgCIGAwidwQx6xttU+RMpr2FzM9s4jOrQwjH3IzedG5kDCwLcENkMak8AAACAAAAAgAIAAIAAIgIDqaTDf1mW06ol26xrVwrwZQOUSSlCRgs1R1Ptnuylh3EQ2QxqTwAAAIAAAACABAAAgAAiAgJ/Y5l1fS7/VaE2rQLGhLGDi2VW5fG2s0KCqUtrUAUQlhDZDGpPAAAAgAAAAIAFAACAAA=="
    
    // Singed with keys m/0'/0'/1' (test vector modified for EC_FLAG_GRIND_R) and m/0'/0'/3'
    let signedPSBT_1_3 = "cHNidP8BAJoCAAAAAljoeiG1ba8MI76OcHBFbDNvfLqlyHV5JPVFiHuyq911AAAAAAD/////g40EJ9DsZQpoqka7CwmK6kQiwHGyyng1Kgd5WdB86h0BAAAAAP////8CcKrwCAAAAAAWABTYXCtx0AYLCcmIauuBXlCZHdoSTQDh9QUAAAAAFgAUAK6pouXw+HaliN9VRuh0LR2HAI8AAAAAAAEAuwIAAAABqtc5MQGL0l+ErkALaISL4J23BurCrBgpi6vucatlb4sAAAAASEcwRAIgWPb8fGoz4bMVSNSByCbAFb0wE1qtQs1neQ2rZtKtJDsCIEoc7SYExnNbY5PltBaR3XiwDwxZQvufdRhW+qk4FX26Af7///8CgPD6AgAAAAAXqRQPuUY0IWlrgsgzryQceMF9295JNIfQ8gonAQAAABepFCnKdPigj4GZlCgYXJe12FLkBj9hh2UAAAAiAgLath/0mhTban0CsM0fu3j8SxgxK1tOVNrk26L7/vU210cwRAIgYxqYn+c4qSrQGYYCMxLBkhT+KAKznly8GsNniAbGksMCIDnbbDh70mdxbf2z1NjaULjoXSEzJrp8faqkwM5B65IjAQEDBAEAAAABBEdSIQKVg785rgpgl0etGZrd1jT6YQhVnWxc05tMIYPxq5bgfyEC2rYf9JoU22p9ArDNH7t4/EsYMStbTlTa5Nui+/71NtdSriIGApWDvzmuCmCXR60Zmt3WNPphCFWdbFzTm0whg/GrluB/ENkMak8AAACAAAAAgAAAAIAiBgLath/0mhTban0CsM0fu3j8SxgxK1tOVNrk26L7/vU21xDZDGpPAAAAgAAAAIABAACAAAEBIADC6wsAAAAAF6kUt/X69A49QKWkWbHbNTXyty+pIeiHIgICOt2QTz1tz1nduQaw3uI1Kbf/ue1Q5ehhUZJoYCIfDnNHMEQCIGX0W6WZi1mif/4ae+0BavHx+Q1Us6qPdFCqX1aiUQO9AiB/ckcDrR7blmgLKEtW1P/LiPf7dZ6rvgiqMPKbhROD0gEBAwQBAAAAAQQiACCMI1MXN0O1ld+0oHtyuo5C43l9p06H/n2ddJfjsgKJAwEFR1IhAwidwQx6xttU+RMpr2FzM9s4jOrQwjH3IzedG5kDCwLcIQI63ZBPPW3PWd25BrDe4jUpt/+57VDl6GFRkmhgIh8Oc1KuIgYCOt2QTz1tz1nduQaw3uI1Kbf/ue1Q5ehhUZJoYCIfDnMQ2QxqTwAAAIAAAACAAwAAgCIGAwidwQx6xttU+RMpr2FzM9s4jOrQwjH3IzedG5kDCwLcENkMak8AAACAAAAAgAIAAIAAIgIDqaTDf1mW06ol26xrVwrwZQOUSSlCRgs1R1Ptnuylh3EQ2QxqTwAAAIAAAACABAAAgAAiAgJ/Y5l1fS7/VaE2rQLGhLGDi2VW5fG2s0KCqUtrUAUQlhDZDGpPAAAAgAAAAIAFAACAAA=="

    // Mainnet multisig wallet based on BIP32 test vectors.
    // To import into Bitcoin Core (experimental descriptor wallet branch) use:
    // importdescriptors '[{"range":1000,"timestamp":"now","watchonly":true,"internal":false,"desc":"wsh(sortedmulti(2,[3442193e\/48h\/0h\/0h\/2h]xpub6E64WfdQwBGz85XhbZryr9gUGUPBgoSu5WV6tJWpzAvgAmpVpdPHkT3XYm9R5J6MeWzvLQoz4q845taC9Q28XutbptxAmg7q8QPkjvTL4oi\/0\/*,[bd16bee5\/48h\/0h\/0h\/2h]xpub6DwQ4gBCmJZM3TaKogP41tpjuEwnMH2nWEi3PFev37LfsWPvjZrh1GfAG8xvoDYMPWGKG1oBPMCfKpkVbJtUHRaqRdCb6X6o1e9PQTVK88a\/0\/*))#75z63vc9","active":true},{"range":1000,"timestamp":"now","watchonly":true,"internal":true,"desc":"wsh(sortedmulti(2,[3442193e\/48h\/0h\/0h\/2h]xpub6E64WfdQwBGz85XhbZryr9gUGUPBgoSu5WV6tJWpzAvgAmpVpdPHkT3XYm9R5J6MeWzvLQoz4q845taC9Q28XutbptxAmg7q8QPkjvTL4oi\/1\/*,[bd16bee5\/48h\/0h\/0h\/2h]xpub6DwQ4gBCmJZM3TaKogP41tpjuEwnMH2nWEi3PFev37LfsWPvjZrh1GfAG8xvoDYMPWGKG1oBPMCfKpkVbJtUHRaqRdCb6X6o1e9PQTVK88a\/1\/*))#8837llds","active":true}]'
    let fingerprint1 = Data("3442193e")!
    let fingerprint2 = Data("bd16bee5")!
    let master1 = "xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi"
    let master2 = "xprv9s21ZrQH143K31xYSDQpPDxsXRTUcvj2iNHm5NUtrGiGG5e2DtALGdso3pGz6ssrdK4PFmM8NSpSBHNqPqm55Qn3LqFtT2emdEXVYsCzC2U"
     let multiUnsignedPSBTWithoutChange = "cHNidP8BAFICAAAAAV/0Rj8kmS/ZB5NjsQvCKM1LTtovmhuQu2GITtz/XUFnAAAAAAD9////Af4SAAAAAAAAFgAUgPiTflaS1yPZmZleFfTq7fUwdIYAAAAAAAEBK4gTAAAAAAAAIgAg+GCObltTf4/IGC6xE89A9WS5nPmdhxcMTxrCWQdO6P0BBUdSIQIRWymltMLmSLuvwQBG3wDoMRcQlj79Fah1NMZw3Q6w+iEDkxPICphGAQSk6avIbx9z0fqYLssxciadkXQV5q7uJnVSriIGAhFbKaW0wuZIu6/BAEbfAOgxFxCWPv0VqHU0xnDdDrD6HL0WvuUwAACAAAAAgAAAAIACAACAAAAAAAAAAAAiBgOTE8gKmEYBBKTpq8hvH3PR+pguyzFyJp2RdBXmru4mdRw0Qhk+MAAAgAAAAIAAAACAAgAAgAAAAAAAAAAAAAA="
    
    let multiPSBTWithoutChangeHex = "020000000001015ff4463f24992fd9079363b10bc228cd4b4eda2f9a1b90bb61884edcff5d41670000000000fdffffff01fe1200000000000016001480f8937e5692d723d999995e15f4eaedf5307486040047304402204f54c5c049e74f06f04ded90ad25e487505fd50eca9a48fbd820f7c046c7141002205f7fec16da5bf495a3991d71c90d8131e386f3c259f664eef1dd7e84496265d3014730440220528bfc7f495c853994ff15c46da50c6874dc197c177945af1a42332e73b372d702203a940c4c2dd2946127a41ce15a1c594aaf1a131c654eadcf911c9d72d499c8b10147522102115b29a5b4c2e648bbafc10046df00e8311710963efd15a87534c670dd0eb0fa21039313c80a98460104a4e9abc86f1f73d1fa982ecb3172269d917415e6aeee267552ae00000000"
    
    let multiUnsignedPSBTWithChange = "cHNidP8BAH0CAAAAAV/0Rj8kmS/ZB5NjsQvCKM1LTtovmhuQu2GITtz/XUFnAAAAAAD9////AqAPAAAAAAAAIgAg2SAanVpF/Lx6c7mjRV2xL95PrYeO1kq+yERNnuQ5oBYzAwAAAAAAABYAFID4k35Wktcj2ZmZXhX06u31MHSGAAAAAAABASuIEwAAAAAAACIAIPhgjm5bU3+PyBgusRPPQPVkuZz5nYcXDE8awlkHTuj9AQVHUiECEVsppbTC5ki7r8EARt8A6DEXEJY+/RWodTTGcN0OsPohA5MTyAqYRgEEpOmryG8fc9H6mC7LMXImnZF0Feau7iZ1Uq4iBgIRWymltMLmSLuvwQBG3wDoMRcQlj79Fah1NMZw3Q6w+hy9Fr7lMAAAgAAAAIAAAACAAgAAgAAAAAAAAAAAIgYDkxPICphGAQSk6avIbx9z0fqYLssxciadkXQV5q7uJnUcNEIZPjAAAIAAAACAAAAAgAIAAIAAAAAAAAAAAAABAUdSIQMROfTTVvMRvdrTpGn+pMYvCLB/78Bc/PK8qqIYwgg1diEDUb/gzEHWzqIxfhWictWQ+Osk5XiRlQCzWIzI+0xHd11SriICAxE59NNW8xG92tOkaf6kxi8IsH/vwFz88ryqohjCCDV2HL0WvuUwAACAAAAAgAAAAIACAACAAQAAAAIAAAAiAgNRv+DMQdbOojF+FaJy1ZD46yTleJGVALNYjMj7TEd3XRw0Qhk+MAAAgAAAAIAAAACAAgAAgAEAAAACAAAAAAA="
    
    let multiSignedPSBTWithChange = "cHNidP8BAH0CAAAAAV/0Rj8kmS/ZB5NjsQvCKM1LTtovmhuQu2GITtz/XUFnAAAAAAD9////AqAPAAAAAAAAIgAg2SAanVpF/Lx6c7mjRV2xL95PrYeO1kq+yERNnuQ5oBYzAwAAAAAAABYAFID4k35Wktcj2ZmZXhX06u31MHSGAAAAAAABASuIEwAAAAAAACIAIPhgjm5bU3+PyBgusRPPQPVkuZz5nYcXDE8awlkHTuj9IgIDkxPICphGAQSk6avIbx9z0fqYLssxciadkXQV5q7uJnVHMEQCIA5I8rmEi/j3Tllb7IJHfR0CpjYXaeEgCEM4Cf8QUGhfAiB46seQHLvXAK8UygrITTSNb55+fwzeamYkuJ2MVmdvhgEiAgIRWymltMLmSLuvwQBG3wDoMRcQlj79Fah1NMZw3Q6w+kcwRAIgfHMQFlEGknsHeUdN7qQCAMmrt3Y7jvvXRLPiSCVOg44CIDlsbA6Aldhz/LX1FnrTBlZ0k38OUTziYa2gkUTQ1PltAQEFR1IhAhFbKaW0wuZIu6/BAEbfAOgxFxCWPv0VqHU0xnDdDrD6IQOTE8gKmEYBBKTpq8hvH3PR+pguyzFyJp2RdBXmru4mdVKuIgYCEVsppbTC5ki7r8EARt8A6DEXEJY+/RWodTTGcN0OsPocvRa+5TAAAIAAAACAAAAAgAIAAIAAAAAAAAAAACIGA5MTyAqYRgEEpOmryG8fc9H6mC7LMXImnZF0Feau7iZ1HDRCGT4wAACAAAAAgAAAAIACAACAAAAAAAAAAAAAAQFHUiEDETn001bzEb3a06Rp/qTGLwiwf+/AXPzyvKqiGMIINXYhA1G/4MxB1s6iMX4VonLVkPjrJOV4kZUAs1iMyPtMR3ddUq4iAgMROfTTVvMRvdrTpGn+pMYvCLB/78Bc/PK8qqIYwgg1dhy9Fr7lMAAAgAAAAIAAAACAAgAAgAEAAAACAAAAIgIDUb/gzEHWzqIxfhWictWQ+Osk5XiRlQCzWIzI+0xHd10cNEIZPjAAAIAAAACAAAAAgAIAAIABAAAAAgAAAAAA"
    
    let multiPSBTWithChangeHex = "020000000001015ff4463f24992fd9079363b10bc228cd4b4eda2f9a1b90bb61884edcff5d41670000000000fdffffff02a00f000000000000220020d9201a9d5a45fcbc7a73b9a3455db12fde4fad878ed64abec8444d9ee439a016330300000000000016001480f8937e5692d723d999995e15f4eaedf5307486040047304402207c7310165106927b0779474deea40200c9abb7763b8efbd744b3e248254e838e0220396c6c0e8095d873fcb5f5167ad3065674937f0e513ce261ada09144d0d4f96d0147304402200e48f2b9848bf8f74e595bec82477d1d02a6361769e12008433809ff1050685f022078eac7901cbbd700af14ca0ac84d348d6f9e7e7f0cde6a6624b89d8c56676f860147522102115b29a5b4c2e648bbafc10046df00e8311710963efd15a87534c670dd0eb0fa21039313c80a98460104a4e9abc86f1f73d1fa982ecb3172269d917415e6aeee267552ae00000000"
    
    let changeIndex999999 = "cHNidP8BAH0CAAAAAUJTCRglAyBzBJKy8g6IQZOs6mW/TAcZQBAwZ1+0nIM2AAAAAAD9////AgMLAAAAAAAAIgAgCrk8USQ4V1PTbvmbC1d4XF6tE0FHxg4DYjSyZ+v36CboAwAAAAAAABYAFMQKYgtvMZZKBJaRRzu2ymKmITLSIkwJAAABASugDwAAAAAAACIAINkgGp1aRfy8enO5o0VdsS/eT62HjtZKvshETZ7kOaAWAQVHUiEDETn001bzEb3a06Rp/qTGLwiwf+/AXPzyvKqiGMIINXYhA1G/4MxB1s6iMX4VonLVkPjrJOV4kZUAs1iMyPtMR3ddUq4iBgMROfTTVvMRvdrTpGn+pMYvCLB/78Bc/PK8qqIYwgg1dhy9Fr7lMAAAgAAAAIAAAACAAgAAgAEAAAACAAAAIgYDUb/gzEHWzqIxfhWictWQ+Osk5XiRlQCzWIzI+0xHd10cNEIZPjAAAIAAAACAAAAAgAIAAIABAAAAAgAAAAABAUdSIQJVEmEwhGKa0JX96JPOEz0ksJ7/7ogUteBmZsuzy8uRRiEC1V/QblpSYPxOd6UP4ufuL2dIy7LAn3MbVmE7q5+FXj5SriICAlUSYTCEYprQlf3ok84TPSSwnv/uiBS14GZmy7PLy5FGHDRCGT4wAACAAAAAgAAAAIACAACAAQAAAD9CDwAiAgLVX9BuWlJg/E53pQ/i5+4vZ0jLssCfcxtWYTurn4VePhy9Fr7lMAAAgAAAAIAAAACAAgAAgAEAAAA/Qg8AAAA="
    
    let changeIndex1000000 = "cHNidP8BAH0CAAAAAUJTCRglAyBzBJKy8g6IQZOs6mW/TAcZQBAwZ1+0nIM2AAAAAAD9////AugDAAAAAAAAFgAUxApiC28xlkoElpFHO7bKYqYhMtIDCwAAAAAAACIAIJdT/Bk+sg3L4UXNnCMQ+76c531xAF4pGWkhztn4evpsIkwJAAABASugDwAAAAAAACIAINkgGp1aRfy8enO5o0VdsS/eT62HjtZKvshETZ7kOaAWAQVHUiEDETn001bzEb3a06Rp/qTGLwiwf+/AXPzyvKqiGMIINXYhA1G/4MxB1s6iMX4VonLVkPjrJOV4kZUAs1iMyPtMR3ddUq4iBgMROfTTVvMRvdrTpGn+pMYvCLB/78Bc/PK8qqIYwgg1dhy9Fr7lMAAAgAAAAIAAAACAAgAAgAEAAAACAAAAIgYDUb/gzEHWzqIxfhWictWQ+Osk5XiRlQCzWIzI+0xHd10cNEIZPjAAAIAAAACAAAAAgAIAAIABAAAAAgAAAAAAAQFHUiEC1/v7nPnBRo1jlhIyjJPwMaBdjZhiYYVxQu52lLXNDeAhA4NzKqUnt/XjzyTC7BzuKiGV96QPVF151rJuX4ZV59vNUq4iAgLX+/uc+cFGjWOWEjKMk/AxoF2NmGJhhXFC7naUtc0N4Bw0Qhk+MAAAgAAAAIAAAACAAgAAgAEAAABAQg8AIgIDg3MqpSe39ePPJMLsHO4qIZX3pA9UXXnWsm5fhlXn280cvRa+5TAAAIAAAACAAAAAgAIAAIABAAAAQEIPAAA="
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testInvalidPSBT(_ psbt: String, _ expectedError: Error) {
        XCTAssertThrowsError(try PSBT(psbt, .testnet)) {error in
            XCTAssertEqual(String(describing: error), String(describing: expectedError))
        }
    }
    
    func testParseTooShortPSBT() {
        testInvalidPSBT("", PSBT.ParseError.tooShort)
    }
    
    func testInvalidCharacters() {
        testInvalidPSBT("💩", PSBT.ParseError.invalidBase64)
    }

    func testParseBase64() {
        let psbt = try! PSBT(validPSBT, .testnet)
        XCTAssertEqual(psbt.description, validPSBT)
    }
    
    func testParseBinary() {
        let psbtData = Data(base64Encoded: validPSBT)!
        let psbt = try! PSBT(psbtData, .testnet)
        XCTAssertEqual(psbt.description, validPSBT)
        XCTAssertEqual(psbt.data, psbtData)
    }
    
    func testInvalidPSBT() {
    testInvalidPSBT("AgAAAAEmgXE3Ht/yhek3re6ks3t4AAwFZsuzrWRkFxPKQhcb9gAAAABqRzBEAiBwsiRRI+a/R01gxbUMBD1MaRpdJDXwmjSnZiqdwlF5CgIgATKcqdrPKAvfMHQOwDkEIkIsgctFg5RXrrdvwS7dlbMBIQJlfRGNM1e44PTCzUbbezn22cONmnCry5st5dyNv+TOMf7///8C09/1BQAAAAAZdqkU0MWZA8W6woaHYOkP1SGkZlqnZSCIrADh9QUAAAAAF6kUNUXm4zuDLEcFDyTT7rk8nAOUi8eHsy4TAA==", PSBT.ParseError.invalid)
    }
    
    func testComplete() {
        let incompletePSBT = try! PSBT(validPSBT, .testnet)
        let completePSBT = try! PSBT(finalizedPSBT, .testnet)
        XCTAssertFalse(incompletePSBT.complete)
        XCTAssertFalse(try! PSBT(unsignedPSBT, .testnet).complete)
        XCTAssertFalse(try! PSBT(signedPSBT_0_2, .testnet).complete)
        XCTAssertTrue(completePSBT.complete)
    }
    
    func testExtractTransaction() {
        let incompletePSBT = try! PSBT(validPSBT, .testnet)
        XCTAssertNil(incompletePSBT.transactionFinal)
        
        let completePSBT = try! PSBT(finalizedPSBT, .testnet)
        if let transaction = completePSBT.transactionFinal {
            XCTAssertEqual(transaction.description, "0200000000010258e87a21b56daf0c23be8e7070456c336f7cbaa5c8757924f545887bb2abdd7500000000da00473044022074018ad4180097b873323c0015720b3684cc8123891048e7dbcd9b55ad679c99022073d369b740e3eb53dcefa33823c8070514ca55a7dd9544f157c167913261118c01483045022100f61038b308dc1da865a34852746f015772934208c6d24454393cd99bdf2217770220056e675a675a6d0a02b85b14e5e29074d8a25a9b5760bea2816f661910a006ea01475221029583bf39ae0a609747ad199addd634fa6108559d6c5cd39b4c2183f1ab96e07f2102dab61ff49a14db6a7d02b0cd1fbb78fc4b18312b5b4e54dae4dba2fbfef536d752aeffffffff838d0427d0ec650a68aa46bb0b098aea4422c071b2ca78352a077959d07cea1d01000000232200208c2353173743b595dfb4a07b72ba8e42e3797da74e87fe7d9d7497e3b2028903ffffffff0270aaf00800000000160014d85c2b71d0060b09c9886aeb815e50991dda124d00e1f5050000000016001400aea9a2e5f0f876a588df5546e8742d1d87008f000400473044022062eb7a556107a7c73f45ac4ab5a1dddf6f7075fb1275969a7f383efff784bcb202200c05dbb7470dbf2f08557dd356c7325c1ed30913e996cd3840945db12228da5f01473044022065f45ba5998b59a27ffe1a7bed016af1f1f90d54b3aa8f7450aa5f56a25103bd02207f724703ad1edb96680b284b56d4ffcb88f7fb759eabbe08aa30f29b851383d20147522103089dc10c7ac6db54f91329af617333db388cead0c231f723379d1b99030b02dc21023add904f3d6dcf59ddb906b0dee23529b7ffb9ed50e5e86151926860221f0e7352ae00000000")
        } else { XCTFail() }
        
    }
    
    func testSignWithKey() {
        let privKey0 = Key(WIF_0, .testnet)
        let privKey1 = Key(WIF_1, .testnet)
        let privKey2 = Key(WIF_2, .testnet)
        let privKey3 = Key(WIF_3, .testnet)
        var psbt1 = try! PSBT(unsignedPSBT, .testnet)
        var psbt2 = try! PSBT(unsignedPSBT, .testnet)
        let expectedPSBT_0_2 = try! PSBT(signedPSBT_0_2, .testnet)
        let expectedPSBT_1_3 = try! PSBT(signedPSBT_1_3, .testnet)

        psbt1.sign(privKey0!)
        psbt1.sign(privKey2!)
        XCTAssertEqual(psbt1.description, expectedPSBT_0_2.description)
        psbt2.sign(privKey1!)
        psbt2.sign(privKey3!)
        XCTAssertEqual(psbt2.description, expectedPSBT_1_3.description)
    }
    
    func testInputs() {
        let psbt = try! PSBT(unsignedPSBT, .testnet)
        XCTAssertEqual(psbt.inputs.count, 2)
    }
    
    func testOutput() {
        let psbt = try! PSBT(unsignedPSBT, .testnet)
        XCTAssertEqual(psbt.outputs.count, 2)
    }
    
    func testKeyPaths() {
        let expectedOrigin0 = KeyOrigin(fingerprint: fingerprint, path: path0)
        let expectedOrigin1 = KeyOrigin(fingerprint: fingerprint, path: path1)
        let expectedOrigin2 = KeyOrigin(fingerprint: fingerprint, path: path2)
        let expectedOrigin3 = KeyOrigin(fingerprint: fingerprint, path: path3)
        let expectedOrigin4 = KeyOrigin(fingerprint: fingerprint, path: path4)
        let expectedOrigin5 = KeyOrigin(fingerprint: fingerprint, path: path5)
        let psbt = try! PSBT(unsignedPSBT, .testnet)
        // Check inputs
        XCTAssertEqual(psbt.inputs.count, 2)
        XCTAssertNotNil(psbt.inputs[0].origins)
        XCTAssertEqual(psbt.inputs[0].origins!.count, 2)
        XCTAssertEqual(psbt.inputs[0].origins![pubKey0], expectedOrigin0)
        XCTAssertEqual(psbt.inputs[0].origins![pubKey1], expectedOrigin1)
        XCTAssertEqual(psbt.inputs[1].origins!.count, 2)
        XCTAssertEqual(psbt.inputs[1].origins![pubKey3], expectedOrigin3)
        XCTAssertEqual(psbt.inputs[1].origins![pubKey2], expectedOrigin2)
        // Check outputs
        XCTAssertEqual(psbt.outputs.count, 2)
        XCTAssertNotNil(psbt.outputs[0].origins)
        XCTAssertEqual(psbt.outputs[0].origins!.count, 1)
        XCTAssertEqual(psbt.outputs[0].origins![pubKey4], expectedOrigin4)
        XCTAssertEqual(psbt.outputs[1].origins!.count, 1)
        XCTAssertEqual(psbt.outputs[1].origins![pubKey5], expectedOrigin5)
    }
   
    func testCanSign() {
        let masterKey = HDKey(masterKeyXpriv)!
        let psbt = try! PSBT(unsignedPSBT, .testnet)
        for input in psbt.inputs {
            XCTAssertTrue(input.canSign(masterKey))
        }
    }

    func testFinalize() {
        var psbt = try! PSBT(signedPSBT, .testnet)
        let expected = try! PSBT(finalizedPSBT, .testnet)
        XCTAssertTrue(psbt.finalize())
        XCTAssertEqual(psbt, expected)
    }
    
    func testSignWithHDKey() {
        var psbt = try! PSBT(unsignedPSBT, .testnet)
        let masterKey = HDKey(masterKeyXpriv)!
        psbt.sign(masterKey)
        XCTAssertTrue(psbt.finalize())
        XCTAssertTrue(psbt.complete)
    }
    
    // In the previous example all inputs were part of the same BIP32 master key.
    // In this example we sign with seperate keys, more representative of a real
    // setup with multiple wallets.
    func testCanSignNeutered() {
        let us = HDKey("xpub6E64WfdQwBGz85XhbZryr9gUGUPBgoSu5WV6tJWpzAvgAmpVpdPHkT3XYm9R5J6MeWzvLQoz4q845taC9Q28XutbptxAmg7q8QPkjvTL4oi", masterKeyFingerprint:Data("3442193e")!)!
        let psbt = try! PSBT(multiUnsignedPSBTWithChange, .mainnet)
        for input in psbt.inputs {
            XCTAssertTrue(input.canSign(us))
        }
    }
    
    func testSignRealMultisigWithHDKey() {
        let keySigner1 = HDKey(master1)!
        let keySigner2 = HDKey(master2)!
        var psbtWithoutChange = try! PSBT(multiUnsignedPSBTWithoutChange, .mainnet)
        var psbtWithChange = try! PSBT(multiUnsignedPSBTWithChange, .mainnet)
        
        psbtWithoutChange.sign(keySigner1)
        psbtWithoutChange.sign(keySigner2)
        XCTAssertTrue(psbtWithoutChange.finalize())
        XCTAssertTrue(psbtWithoutChange.complete)
        XCTAssertEqual(psbtWithoutChange.transactionFinal?.description, multiPSBTWithoutChangeHex)
        
        psbtWithChange.sign(keySigner1)
        psbtWithChange.sign(keySigner2)
        XCTAssertEqual(psbtWithChange.description, multiSignedPSBTWithChange)
        XCTAssertTrue(psbtWithChange.finalize())
        XCTAssertEqual(psbtWithChange.transactionFinal?.description, multiPSBTWithChangeHex)
        
        XCTAssertEqual(psbtWithChange.outputs[0].txOutput.amount, 4000)
        XCTAssertEqual(psbtWithChange.outputs[0].txOutput.address, "bc1qmysp4826gh7tc7nnhx352hd39l0yltv83mty40kgg3xeaepe5qtq4c50qe")

        XCTAssertEqual(psbtWithChange.outputs[1].txOutput.amount, 819)
        XCTAssertEqual(psbtWithChange.outputs[1].txOutput.address, "bc1qsrufxljkjttj8kven90pta82ah6nqayxfr8p9h")

    }
    
    func testIsChange() {
        let us = HDKey(master1)!
        let cosigner = HDKey(master2)!
        var psbt = try! PSBT(multiUnsignedPSBTWithChange, .mainnet)
        XCTAssertTrue(psbt.outputs[0].isChange(signer: us, inputs: psbt.inputs, cosigners: [cosigner], threshold: 2))
        XCTAssertFalse(psbt.outputs[1].isChange(signer: us, inputs: psbt.inputs, cosigners: [cosigner], threshold: 2))
        
        // Test maximum permitted change index
        psbt = try! PSBT(changeIndex999999, .mainnet)
        XCTAssertTrue(psbt.outputs[0].isChange(signer: us, inputs: psbt.inputs, cosigners: [cosigner], threshold: 2))
        XCTAssertFalse(psbt.outputs[1].isChange(signer: us, inputs: psbt.inputs, cosigners: [cosigner], threshold: 2))

        // Test out of bounds change index
        psbt = try! PSBT(changeIndex1000000, .mainnet)
        XCTAssertFalse(psbt.outputs[0].isChange(signer: us, inputs: psbt.inputs, cosigners: [cosigner], threshold: 2))
        XCTAssertFalse(psbt.outputs[1].isChange(signer: us, inputs: psbt.inputs, cosigners: [cosigner], threshold: 2))
    }
    
    func testIsChangeWithNeuteredCosignerKey() {
        let us = HDKey(master1)!
        let cosigner = HDKey("xpub6DwQ4gBCmJZM3TaKogP41tpjuEwnMH2nWEi3PFev37LfsWPvjZrh1GfAG8xvoDYMPWGKG1oBPMCfKpkVbJtUHRaqRdCb6X6o1e9PQTVK88a", masterKeyFingerprint:Data("bd16bee5")!)!
        let psbt = try! PSBT(multiUnsignedPSBTWithChange, .mainnet)
        XCTAssertTrue(psbt.outputs[0].isChange(signer: us, inputs: psbt.inputs, cosigners: [cosigner], threshold: 2))
        XCTAssertFalse(psbt.outputs[1].isChange(signer: us, inputs: psbt.inputs, cosigners: [cosigner], threshold: 2))
    }
    
    func testIsChangeWithNeuteredAllKeys() {
        let us = HDKey("xpub6E64WfdQwBGz85XhbZryr9gUGUPBgoSu5WV6tJWpzAvgAmpVpdPHkT3XYm9R5J6MeWzvLQoz4q845taC9Q28XutbptxAmg7q8QPkjvTL4oi", masterKeyFingerprint:Data("3442193e")!)!
        let cosigner = HDKey("xpub6DwQ4gBCmJZM3TaKogP41tpjuEwnMH2nWEi3PFev37LfsWPvjZrh1GfAG8xvoDYMPWGKG1oBPMCfKpkVbJtUHRaqRdCb6X6o1e9PQTVK88a", masterKeyFingerprint:Data("bd16bee5")!)!
        let psbt = try! PSBT(multiUnsignedPSBTWithChange, .mainnet)
        XCTAssertTrue(psbt.outputs[0].isChange(signer: us, inputs: psbt.inputs, cosigners: [cosigner], threshold: 2))
        XCTAssertFalse(psbt.outputs[1].isChange(signer: us, inputs: psbt.inputs, cosigners: [cosigner], threshold: 2))
    }
    
    func testGetTransactionFee() {
        let psbt = try! PSBT(multiUnsignedPSBTWithChange, .mainnet)
        XCTAssertEqual(psbt.fee, 181)
    }

}


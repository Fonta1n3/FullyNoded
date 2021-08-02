# Lifehashes

Fully Noded uses @BlockchainCommons [lifehashes](https://github.com/BlockchainCommons/LifeHash) to display 
unique visual representations of your addresses.

The lifehash function takes as input the raw string representaion of the address:
```
func image(input: String) -> UIImage? {
    return LifeHashGenerator.generateSync(input, version: .version2)
}
    
```

Each utxo can be visually identified by the address it contains prior to being spent.

When constructing transactions with Fully Noded it will display each input & output and their respective address & lifehash.
This makes it much easier to recognize your utxos in psbts or perhaps more importantly to confirm receipt addresses.


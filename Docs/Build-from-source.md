# Build From Source

- Install `Xcode command line tools`, in terminal: `xcode-select --install`
- Ensure you have Homebrew installed:
  - `brew --version`, if you get a valid response you have brew installed already. If not, install brew:
  ```
  cd /usr/local
  mkdir homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C homebrew
  ```
- Install carthage and libwally dependencies:  `brew install automake autoconf libtool gnu-sed carthage`
- Install [Xcode](https://itunes.apple.com/id/app/xcode/id497799835?mt=12)
- Create a free Apple developer account [here](https://developer.apple.com/programs/enroll/)
- In Terminal:
  - `git clone https://github.com/Fonta1n3/FullyNoded.git`
  - `cd FullyNoded`
  - `carthage build --platform iOS`, let it finish.
- That's it, you can now open `FullyNoded.xcodeproj` in Xcode and run it in a simulator or on your device.

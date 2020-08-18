## Connecting over Tor 
 - [macOS](#Connecting-over-Tor-macOS)
 - [Windows 10](#Connecting-over-Tor-Windows-10)
 - [Debian 10](#Connecting-over-Tor-Linux-Debian-10)
 
#### Optional Tor v3
## Connecting over Tor macOS
Run `brew --version` in a terminal, if you get a valid response you have brew installed already. If not, install brew:

```cd /usr/local
mkdir homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C homebrew
```
### On the device running your node:
- run `brew install tor` in a terminal
- Once Tor is installed you will need to create a Hidden Service.
- Now first locate your `torrc` file, this is Tor's configuration file. Open Finder and type `shift command h` to navigate to your home folder and  `shift command .` to show hidden files.
-  If you've not been able to locate the torrc file, you might have to create the torrc file manually first. Do this by copying the torrc.sample -file: `cp /usr⁩/local⁩/etc⁩/tor⁩/torrc.sample /usr⁩/local⁩/etc⁩/tor⁩/torrc` and give the file it's right permission `chmod 700 /usr⁩/local⁩/etc⁩/tor⁩/torrc`
- The torrc file should be located at `‎⁨/usr⁩/local⁩/etc⁩/tor⁩/torrc`, to edit it you can open terminal and run `sudo nano /usr⁩/local⁩/etc⁩/tor⁩/torrc`
- Locate the section that looks like:

```
## Once you have configured a hidden service, you can look at the
## contents of the file ".../hidden_service/hostname" for the address
## to tell people.
##
## HiddenServicePort x y:z says to redirect requests on port x to the
## address y:z.

```

- And below it add one Hidden Service for each port:

```
HiddenServiceDir /usr/local/var/lib/tor/fullynoded/main
HiddenServiceVersion 3
HiddenServicePort 8332 127.0.0.1:8332

HiddenServiceDir /usr/local/var/lib/tor/fullynoded/test
HiddenServiceVersion 3
HiddenServicePort 18332 127.0.0.1:18332

HiddenServiceDir /usr/local/var/lib/tor/fullynoded/regtest
HiddenServiceVersion 3
HiddenServicePort 18443 127.0.0.1:18443

HiddenServiceDir /usr/local/var/lib/tor/fullynoded/lightning
HiddenServiceVersion 3
HiddenServicePort 1312 127.0.0.1:1312
```

The syntax is `HiddenServicePort xxxx 127.0.0.1:18332`, `xxxx` represents a synthetic port (virtual port), that means it doesn't matter what number you assign to `xxxx`. However, to make it simple just keep the ports the same.


- Save and close nano with `ctrl x` + `y` + `enter` to save and exit nano (follow the prompts)
- Start Tor by opening a terminal and running `brew services start tor`
- Tor should start and you should be able to open Finder and **navigate to** your onion address(es) you need for Fully Noded:
    * `/usr/local/var/lib/tor/fullynoded/main` (the directory for *mainnet* we added to the torrc file) and see a file called `hostname`, open it and copy the onion address, that you need for Fully Noded.
    * `/usr/local/var/lib/tor/fullynoded/test` (the directory for *testnet* we added to the torrc file), same: there is file called `hostname`, open it etc.
    * `/usr/local/var/lib/tor/fullynoded/regtest` (the directory for *regtest net* we added to the torrc file); same as `main` and `test`.

- The `HiddenServicePort` needs to control your nodes rpcport, by default for mainnet that is 8332, for testnet 18332 and for regtest 18443.

- All three `HiddenServiceDir`'s in `main`, `test` and `regtest` subdirectories of `/usr/local/var/lib/tor/fullynoded` need to have permission 700, You can check this yourself ([How to interpret file permissions](https://askubuntu.com/a/528433))If not, they must be changed to 700 with `chmod 700` command:
    * `chmod 700 /usr/local/var/lib/tor/fullynoded/main`
    * `chmod 700 /usr/local/var/lib/tor/fullynoded/test`
    * `chmod 700 /usr/local/var/lib/tor/fullynoded/regtest`
	* `chmod 700  /usr/local/var/lib/tor/fullynoded/lightning`

- A ready to use `torrc` file that conforms to the guidelines above is available [here](./Docs/torrc-tailored.md).
- Check that your node is **on**, that it's really running.

Find the suggested Authentication settings on the device running FN [here](./Authentication.md/#On-the-device-running-FN).<br/>
Find the suggested `bitcoin.conf` settings for FN [here](./Howto.md/#Bitcoin-Core-settings).<br/>
Find the suggested `lightning.conf` settings for FN [here](./Lightning.md/#Create-lightning-config).

## Connecting over Tor Windows 10
If you already have the Tor Expert Bundle installed you can skip the first 3 steps.

### On the device running your node
- Download the Tor Expert Bundle [here](https://www.torproject.org/download/tor/)
- Unpack the "Tor" folder onto your C: drive.
- Open PowerShell as admin (Press Windows Key + X and then select PowerShell (Admin))

Now we have Tor on our drive, but we still have configure and install it.

Let's enter the directory in Powershell:
`cd C:\Tor`
Now we're in the Tor directory.
In order to configure Tor we'll have to generate a configuration file:
`echo > torrc`
Now we launch notepad and edit the file to fit our needs:
`notepad torrc`
Enter the following into the file:
```
HiddenServiceDir "C:/Tor/fullynoded/main/"
HiddenServiceVersion 3
HiddenServicePort 8332 127.0.0.1:8332

HiddenServiceDir "C:/Tor/fullynoded/test/"
HiddenServiceVersion 3
HiddenServicePort 18332 127.0.0.1:18332

HiddenServiceDir "C:/Tor/fullynoded/regtest/"
HiddenServiceVersion 3
HiddenServicePort 18443 127.0.0.1:18443

HiddenServiceDir "C:/Tor/fullynoded/lightning/"
HiddenServiceVersion 3
HiddenServicePort 1312 127.0.0.1:1312
```

Save and exit the file.

Now we have to create the directories:
```
cd C:\Tor
mkdir fullynoded
mkdir fullynoded\main
mkdir fullynoded\test
mkdir fullynoded\regtest
mkdir fullynoded\lightning
```

Save and exit the file.
Now we install Tor as a service:
`C:\Tor\tor.exe --service install -options -f "C:\Tor\torrc"`

Now we can enable the service by typing:
`C:\Tor\tor.exe --service start`

After you start the service the hostname files will be generated in `C:\Tor\fullynoded\main`, `C:\Tor\fullynoded\test`, `C:\Tor\fullynoded\regtest` and `C:\Tor\fullynoded\lightning`, you can view them by typing:<br/>
`cat C:\Tor\fullynoded\main`<br/>
`cat C:\Tor\fullynoded\test`<br/>
`cat C:\Tor\fullynoded\regtest`<br/>
`cat C:\Tor\fullynoded\lightning`<br/>

Next you need to ensure your `bitcoin.conf` has rpc credentials added (see next section).

Once you have rpc credentials added to your `bitcoin.conf` you can reboot Bitcoin-Core.

Find the suggested Authentication settings on the device running FN [here](./Authentication.md/#On-the-device-running-FN).<br/>
Find the suggested `bitcoin.conf` settings for FN [here](./Howto.md/#Bitcoin-Core-settings).<br/>
Find the suggested `lightning.conf` settings for FN [here](./Lightning.md/#Create-lightning-config).

## Connecting over Tor Linux Debian 10

Install tor on linux: `sudo apt install tor` works

### On the device running your node:

Boot tor as a service:
Linux: `systemctl start tor`

Once Tor is installed (and started) you will be able to create a Hidden Service.

On Linux:<br/>
`nano /etc/tor/torrc`<br/>

Find the hidden services section:<br/>
```
############### This section is just for location-hidden services ###

## Once you have configured a hidden service, you can look at the
## contents of the file ".../hidden_service/hostname" for the address
## to tell people.
##
## HiddenServicePort x y:z says to redirect requests on port x to the
## address y:z.
```

Below it add the hidden service we will use to control our Bitcoin node and lightning node:<br/>
```
HiddenServiceDir /usr/local/var/lib/tor/fullynoded/main
HiddenServiceVersion 3
HiddenServicePort 8332 127.0.0.1:8332

HiddenServiceDir /usr/local/var/lib/tor/fullynoded/test
HiddenServiceVersion 3
HiddenServicePort 18332 127.0.0.1:18332

HiddenServiceDir /usr/local/var/lib/tor/fullynoded/regtest
HiddenServiceVersion 3
HiddenServicePort 18443 127.0.0.1:18443

HiddenServiceDir /usr/local/var/lib/tor/fullynoded/lightning/
HiddenServiceVersion 3
HiddenServicePort 1312 127.0.0.1:1312
```
`ctlr x` > `y` > `return` to save the changes and quit nano text editor

You will then need to create the hidden service directory:<br/>
`cd /usr/local/var/lib/tor/`<br/>
`mkdir fullynoded`<br/>
`mkdir fullynoded/main`<br/>
`mkdir fullynoded/test`<br/>
`mkdir fullynoded/regtest`<br/>
`mkdir fullynoded/lightning/`

On linux assign the owner for every *subdirectory* above, here example *lightning*:<br/>
`chown -R debian-tor:debian-tor /usr/local/var/lib/tor/fullynoded/lightning/`

Then:<br/>
`chmod 700 /usr/local/var/lib/tor/fullynoded/lightning/`

Restart Tor:<br/>
linux `systemctl restart tor`

Tor should start and you should be able to **navigate to** your onion address(es) you need for Fully Noded, the example is for subdirectory *main* but it should be done for all subdirectories if relevant for you:<br/>
    * `/usr/local/var/lib/tor/fullynoded/main` (the directory for *mainnet* we added to the torrc file) and see a file called `hostname`, **open it and copy the onion address, that you need for Fully Noded**. 
    * Or `cat /usr/local/var/lib/tor/fullynoded/lightning/hostname`. If it prints something like `ndfiuhfh2fu23ufh21u3bfd.onion` then all is well, if not message me on the Fully Noded Telegram and some group member can help (maybe).
    * Do the same for `test`, `regtest` and `lightning`

Find the suggested Authentication settings on the device running FN [here](./Authentication.md/#On-the-device-running-FN).<br/>
Find the suggested `bitcoin.conf` settings for FN [here](./Howto.md/#Bitcoin-Core-settings).<br/>
Find the suggested `lightning.conf` settings for FN [here](./Lightning.md/#Create-lightning-config).


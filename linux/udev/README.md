# TL866CS USB access on Ubuntu

The portable archive does not install system configuration.  To let the active
desktop user open a TL866A/CS (`04d8:e11c`) without running the app as root,
install the included narrowly scoped rule once:

```sh
sudo install -m 0644 linux/udev/60-mushagaeshi-tl866.rules /etc/udev/rules.d/60-mushagaeshi-tl866.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=usb
```

Unplug and reconnect the programmer. On a standard Ubuntu desktop, `uaccess`
grants the active local session access. On installations without logind's
`uaccess` support, use the fallback group and sign out/in afterwards:

```sh
sudo groupadd -f plugdev
sudo usermod -aG plugdev "$USER"
```

The rule is copied from the pinned minipro rule, keeps its GPL-3.0-or-later
license, and applies only to the TL866A/CS VID/PID. It does not install a
driver, grant world-writable USB access, or make the programmer usable by a
remote session. The app's probe only enumerates descriptors; an enumerated
device can still fail to open if the rule/session setup is missing.

# Bundled libusb

The macOS build bundles libusb 1.0.29 for the arm64-only initial release.
`UPSTREAM.toml` records the official release URL and source SHA-256.

Run `tool/fetch_native_sources.sh` to place and verify the source archive in
the ignored `.tooling/native-src/` cache, then run
`tool/build_native_macos.sh`. The final app bundles the shared library in
`Contents/Frameworks` beside a minipro helper that links to it through
`@rpath`.

libusb is LGPL-2.1-or-later. Its unmodified license is copied from the pinned
source archive to `LICENSE` and is bundled in the app resources. Distribution
must keep the matching source archive and rebuild instructions available so a
recipient can relink the helper with a modified compatible libusb.

# v0.2.1 release preparation

The user requested moving the README update to `release/0.2.1`, restoring
`release/0.2.0` to the published v0.2.0 commit, and publishing v0.2.1.

- v0.2.0 tag and restored branch: `12ae22631dc8e86d9168fde39c01fdf646fe066c`.
- README commit retained on the new branch: `0118094ae8fbff3550a4c111844d0e92eb047cb8`.
- Include pending README references, Windows packaging and source-bundle updates.
- Application version: `0.2.1+3`; five target names remain unchanged.
- The release workflow builds the new tag and uploads all five archives after validation.
- v0.2.0 Release/tag/assets remain unchanged. No main-branch merge is requested.

The scope is bilingual documentation, setup guidance and matching application
messages/package contents. The existing programming workflow and USB transport
remain unchanged. Windows ARM64 normal-restart success in the reported
Parallels environment is documented separately from automated validation.

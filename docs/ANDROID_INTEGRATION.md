# Android integration contract

The PiperOS installer must treat runtime data as untrusted until verification
completes.

## Required installation flow

1. Detect `Build.SUPPORTED_ABIS` and select the first supported manifest ABI.
2. Require Android API 24 or newer.
3. Download the signed manifest over HTTPS.
4. Verify the Ed25519 signature using `keys/manifest-public.pem`.
5. Verify application id, prefix, runtime version, archive size and SHA-256.
6. Download into the app cache directory.
7. Validate every ZIP path and reject absolute paths, traversal, duplicates,
   special files, or an excessive expanded size.
8. Extract into a private staging directory.
9. Restore symbolic links from the bootstrap `SYMLINKS.txt` format without
   allowing targets outside `$PREFIX`.
10. Complete the Termux bootstrap second stage.
11. Atomically activate the runtime and retain the previous version for
    rollback.

Expected paths:

```text
/data/data/com.piper.os.tool/files/home
/data/data/com.piper.os.tool/files/usr
```

The foreground terminal service should own sessions and wake locks. A wake
lock must be user-controlled and held only while a user-started command needs
it. Closing an Activity must not destroy active sessions.


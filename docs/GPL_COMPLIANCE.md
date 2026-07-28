# GPLv3 compliance checklist

This checklist applies whenever a PiperOS APK or runtime archive containing
GPL-3.0-only code is distributed.

## Every release

- Publish the complete corresponding source for the exact distributed
  binaries, including PiperOS patches.
- Keep the pinned upstream revision and all build scripts used for the
  release.
- Publish source with access no more difficult than access to the binaries.
- Include `LICENSE`, copyright notices, and third-party license exceptions.
- Mark modified upstream files and describe significant changes.
- Do not impose additional restrictions that conflict with GPLv3 rights.
- Keep source available for as long as the object code is distributed.

GitHub tags should identify exact release source:

```text
runtime-v2.5.0-beta.1
```

The Android app's About/Licenses screen should show:

```text
PiperOS Termux Runtime
Licensed under GNU GPL version 3 only
Source: https://github.com/Phi574/Piperos_termux
```

Publishing this runtime repository under GPLv3 does not automatically add a
license file to the separate PiperOS Android repository. When GPL-covered
Termux application code is linked into the APK, the Android source repository
must also publish the corresponding source and licensing notices for that APK.


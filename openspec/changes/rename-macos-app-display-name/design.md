## Context

The Flutter package identifier must remain lowercase and underscore-separated,
while the macOS product name controls the visible `.app` bundle name and is
also used by the default Flutter window metadata.

## Design

Use `PRODUCT_NAME = Mobile Matrix` in the shared macOS application config and
reference `$(PRODUCT_NAME)` for `CFBundleName` and `CFBundleDisplayName`. Keep
the Xcode product reference, shared scheme buildable names, test host paths,
and release packaging script defaults aligned with `Mobile Matrix.app`.

The Dart package remains `mobile_matrix`; no source imports or package metadata
are renamed.

## Verification

- Validate the Info.plist syntax.
- Check Xcode's resolved macOS product settings.
- Build the macOS app and confirm the output bundle is `Mobile Matrix.app`.
- Confirm the existing release packaging script accepts the renamed bundle.

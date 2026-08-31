# Improve GitHub discoverability

## Why

The repository is public and already has a macOS arm64 release, but its README still contains the default Flutter template text and the GitHub repository has no description or Topics. Search visitors cannot quickly identify that Mobile Matrix is an Android device control and ADB workspace for macOS.

## What Changes

- Replace the template README with an English product overview, feature list, download instructions, requirements, platform status, development notes, and a link to a separate Chinese README.
- Add `README-ZH.md` as the complete Chinese version, linked from both README files.
- Add a maintainable GitHub discoverability guide with keyword clusters, metadata recommendations, release naming, measurement guidance, and claim boundaries.
- Set a concise GitHub repository description and relevant Topics based only on implemented capabilities.

## Scope Boundary

- This change covers GitHub repository SEO and general web discoverability.
- It does not create Google Play or App Store metadata.
- It does not add an Android client, Windows/Linux release, analytics integration, or new application functionality.
- It does not rename the repository or replace the existing macOS release artifact.

## Impact

- Documentation: `README.md`, `README-ZH.md`, `docs/seo/github-discovery.md`
- Change governance: this OpenSpec change
- GitHub metadata: repository description and Topics

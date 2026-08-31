# Design: GitHub discoverability

## Context

The product is a macOS desktop control console for Android devices. The current public release is an Apple Silicon package, while the repository also contains desktop platform scaffolding that has not been validated as distributable releases. Search content must therefore make the supported product clear without overstating platform coverage.

## Design decisions

### 1. One canonical product sentence

The repository description and README opening use the same concise positioning: Flutter desktop workspace, Android device control, macOS, ADB, screen mirroring, input, clipboard, screenshots, and STF Lite. This gives search engines and readers a consistent topic signal.

### 2. Separate English and Chinese README files

`README.md` remains the default English entry because the repository is public and the target search vocabulary is primarily represented by English technical terms. `README-ZH.md` contains the complete Chinese version. Both files link to each other and to the same macOS release, so each language can remain readable without making one page unnecessarily long.

### 3. Evidence-bounded platform language

The current macOS arm64 release is presented as downloadable. Windows and Linux are described as unvalidated project targets, and Android is described as the controlled device. This prevents repository SEO from creating false expectations.

### 4. Natural keyword placement

Keywords are distributed across the title, opening paragraph, feature headings, requirements, architecture notes, and metadata. A maintainer-only guide records the clusters and placement rules, but the README does not include a spam-like keyword block.

### 5. GitHub-native conversion paths

The README links visitors to the latest release, the current artifact, and Issues. The guide points maintainers to Traffic insights, release download counts, and user terminology as the evidence for future revisions.

## Verification

- README contains the real product category, platform, key capabilities, download link, and support boundaries.
- The repository description is within GitHub's normal description length and matches the README positioning.
- Topics are lowercase, relevant, and limited to implemented capabilities.
- OpenSpec validates in strict mode.
- Markdown links point to the repository's existing releases and Issues routes.

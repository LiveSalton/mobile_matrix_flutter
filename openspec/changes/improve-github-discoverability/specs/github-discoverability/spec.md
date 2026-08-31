# GitHub discoverability

## ADDED Requirements

### Requirement: The public README must identify the product and supported platform

The repository README MUST describe Mobile Matrix as a Flutter desktop workspace for controlling Android devices from macOS, and MUST identify the current macOS Apple Silicon release without presenting unvalidated platforms as released products.

#### Scenario: A search visitor opens the repository

- **WHEN** a visitor lands on the repository README
- **THEN** the first section identifies the product category, macOS host platform, Android/ADB domain, and key control capabilities
- **AND** the visitor can reach the current macOS arm64 release from the README

### Requirement: English and Chinese documentation must be separate linked pages

The repository MUST provide `README.md` as the English default entry and `README-ZH.md` as the complete Chinese version. Each file MUST provide a visible link to the other language version.

#### Scenario: A reader selects a preferred language

- **WHEN** a reader opens either README file
- **THEN** the reader can switch to the other language from a link near the top of the page
- **AND** the selected page contains the same product scope, release information, and platform boundaries in that language

### Requirement: Public documentation must use evidence-bounded feature language

The README and discoverability guide MUST use only capabilities currently implemented in the repository, and MUST explicitly distinguish the desktop host, the controlled Android device, and unvalidated platform scaffolding.

#### Scenario: A visitor checks platform support

- **WHEN** the visitor looks for Windows, Linux, or Android support
- **THEN** the documentation states whether a validated distributable exists
- **AND** it does not imply that a separate Android client or an official Windows/Linux package is available when none has been published

### Requirement: Repository metadata must reinforce the canonical product positioning

The GitHub repository description and Topics MUST use concise, relevant terms for Flutter desktop Android device control, ADB, screen mirroring, input, clipboard, screenshots, and STF Lite without unrelated keyword stuffing.

#### Scenario: GitHub indexes repository metadata

- **WHEN** GitHub or an external search engine reads the repository metadata
- **THEN** the description and Topics reinforce the same product category and supported platform as the README
- **AND** each Topic maps to a real repository capability or platform

### Requirement: Discoverability content must provide a maintenance path

The repository MUST contain maintainer guidance for keyword placement, release naming, claim boundaries, and traffic/release measurement so future SEO changes remain consistent and evidence-based.

#### Scenario: A maintainer prepares a future release

- **WHEN** a maintainer updates the README, repository metadata, or release notes
- **THEN** the maintainer can use the discoverability guide to select relevant terms and describe the artifact accurately
- **AND** the maintainer can inspect GitHub Traffic and release download data without relying on invented targets

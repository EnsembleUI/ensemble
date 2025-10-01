# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2025-10-01

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.2.8`](#ensemble---v128)
 - [`ensemble_stripe` - `v1.0.1`](#ensemble_stripe---v101)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_stripe` - `v1.0.1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.2.8`

 - **REFACTOR**: enhance navigation logic by evaluating payloads and improving menu item visibility handling. ([9992099b](https://github.com/ensembleUI/ensemble/commit/9992099b36504db84662eb7e2c4e51157b78d105))
 - **REFACTOR**: update color handling in various widget files to use withValues for opacity adjustments. ([47affb3a](https://github.com/ensembleUI/ensemble/commit/47affb3a3b8e84c092c9d912b85ed8987b828e19))
 - **REFACTOR**: update color handling in widget files to use withValues for opacity adjustments. ([562d8e9e](https://github.com/ensembleUI/ensemble/commit/562d8e9e5247d56362a783f6752a3c801016d1a6))
 - **REFACTOR**: replace MaterialState with WidgetState in theme and widget files for improved state management. ([77ece02f](https://github.com/ensembleUI/ensemble/commit/77ece02fecf121320e5f62e042ec993e5f7fd178))
 - **REFACTOR**: streamline caching mechanism in CdnDefinitionProvider by consolidating persistent cache keys and improving state management. ([9be858b0](https://github.com/ensembleUI/ensemble/commit/9be858b0265fc8c197c08d61d269b9bfdbd7a3ce))


## 2025-09-28

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.2.7`](#ensemble---v127)
 - [`ensemble_stripe` - `v1.0.1`](#ensemble_stripe---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_stripe` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`

---

#### `ensemble` - `v1.2.7`

 - **REFACTOR**: update CdnDefinitionProvider documentation and clean up comment formatting for improved readability. ([59ae2e98](https://github.com/ensembleUI/ensemble/commit/59ae2e98ffae67e1e3d7d638d9c6fb8a3056a33e))
 - **REFACTOR**: enhance CdnDefinitionProvider by improving error messages, simplifying asset parsing, and refining translation handling. ([f58353c9](https://github.com/ensembleUI/ensemble/commit/f58353c960eedd8eeb1f1edbe14492c54acbc59a))
 - **REFACTOR**: update CdnDefinitionProvider to use a base URL and improve URL construction; change configuration to support CDN hosting. ([3c783cb5](https://github.com/ensembleUI/ensemble/commit/3c783cb5004a2123a8f8e448e30665fd6efa7038))
 - **REFACTOR**: update _parseTheme method to accept a Map and improve theme data handling. ([86110ff9](https://github.com/ensembleUI/ensemble/commit/86110ff9e619e88765b04a31cde0fab2683f0b0e))
 - **REFACTOR**: simplify lastUpdatedAt extraction in CdnDefinitionProvider. ([83f34d09](https://github.com/ensembleUI/ensemble/commit/83f34d097632009811482a2bae70902e991f3d37))
 - **FEAT**: implement XChaCha20-Poly1305 decryption for secrets in CdnDefinitionProvider, enhancing security and payload handling. ([94ec0b19](https://github.com/ensembleUI/ensemble/commit/94ec0b1905ae903d83618c50a828238ba65f6a05))
 - **FEAT**: add CDN definition provider. ([c1746d87](https://github.com/ensembleUI/ensemble/commit/c1746d87bd7886a6a20a087f772c5a5efd363804))


## 2025-09-22

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.2.6`](#ensemble---v126)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_stripe` - `v1.0.1`](#ensemble_stripe---v101)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_stripe` - `v1.0.1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.2.6`

 - **FIX**: converted Date objects to Timestamps. ([f59d69d3](https://github.com/ensembleUI/ensemble/commit/f59d69d37154e82a7e195275def76c0f69b19da9))
 - **FEAT**: added firebase analytics rest of unsupported functions. ([04f34898](https://github.com/ensembleUI/ensemble/commit/04f34898dd4a033a130084c0656b769de99e20f1))


## 2025-09-05

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.2.5`](#ensemble---v125)
 - [`ensemble_stripe` - `v1.0.1`](#ensemble_stripe---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_stripe` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.2.5`

 - **FIX**: storage updates to page group as well. ([ab6e3c61](https://github.com/ensembleUI/ensemble/commit/ab6e3c613e4e33b7f5f12fe2c4cb517c75cba25c))


## 2025-08-27

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.2.4`](#ensemble---v124)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_stripe` - `v1.0.1`](#ensemble_stripe---v101)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_stripe` - `v1.0.1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`

---

#### `ensemble` - `v1.2.4`

 - **FEAT**(page): add collapsible header support and dynamic title bar height updates. ([d35eba01](https://github.com/ensembleUI/ensemble/commit/d35eba015c0a26429aa4201504bed7c686ed096b))


## 2025-08-21

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.2.3`](#ensemble---v123)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_stripe` - `v1.0.1`](#ensemble_stripe---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_stripe` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.2.3`

 - **FIX**(page-group): notify selected page on ViewGroup resume. ([ff4cbfc4](https://github.com/ensembleUI/ensemble/commit/ff4cbfc4321635db54cf70bfc4650005fb9aa1de))


## 2025-08-20

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.2.2`](#ensemble---v122)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_stripe` - `v1.0.1`](#ensemble_stripe---v101)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_stripe` - `v1.0.1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`

---

#### `ensemble` - `v1.2.2`


## 2025-08-19

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.2.1`](#ensemble---v121)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_stripe` - `v1.0.1`](#ensemble_stripe---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_stripe` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.2.1`

 - **FIX**: correct typo in calendar widget tooltip property. ([dc6d7312](https://github.com/ensembleUI/ensemble/commit/dc6d7312fe0712f41b81dd3c0888215146c6d173))


## 2025-08-15

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.2.0`](#ensemble---v120)
 - [`ensemble_stripe` - `v1.0.1`](#ensemble_stripe---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_stripe` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.2.0`

 - **FEAT**(widget): enhance semantics label retrieval logic. ([7ddb5d55](https://github.com/ensembleUI/ensemble/commit/7ddb5d55634fe7aa0c4a3000671e37dc8f9b9e73))


## 2025-08-07

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.80`](#ensemble---v1180)
 - [`ensemble_stripe` - `v1.0.1`](#ensemble_stripe---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_stripe` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.80`

 - Bump "ensemble" to `1.1.80`.


## 2025-08-05

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.79`](#ensemble---v1179)
 - [`ensemble_stripe` - `v1.0.1`](#ensemble_stripe---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_stripe` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.79`

 - **FIX**: evaluating the saveFile action properties. ([dedb9658](https://github.com/ensembleUI/ensemble/commit/dedb9658a8ba16c443de6abce0f3130256f19ad9))


## 2025-07-31

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.78`](#ensemble---v1178)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_stripe` - `v1.0.1`](#ensemble_stripe---v101)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_stripe` - `v1.0.1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.78`

 - **FIX**(stripe): correct onSuccess callback reference in ShowPaymentSheetAction. ([60ce6612](https://github.com/ensembleUI/ensemble/commit/60ce661276fadee0d8ae863680d4a28c603597ca))


## 2025-07-31

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.77`](#ensemble---v1177)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_stripe` - `v1.0.1`](#ensemble_stripe---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_stripe` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`

---

#### `ensemble` - `v1.1.77`

 - **FEAT**(stripe): add initializeStripe action and update payment sheet functionality. ([5622bd40](https://github.com/ensembleUI/ensemble/commit/5622bd40b4b21a21b55154444e2dbe2802b1dc68))


## 2025-07-30

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.76`](#ensemble---v1176)
 - [`ensemble_stripe` - `v1.0.1`](#ensemble_stripe---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_stripe` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.76`

 - **REFACTOR**(stripe): rename onComplete to onSuccess in ShowPaymentSheetAction. ([deddd07c](https://github.com/ensembleUI/ensemble/commit/deddd07cd498d249aca5b15f33319b981adace47))
 - **FEAT**(stripe): add Stripe payment integration module. ([1f29b783](https://github.com/ensembleUI/ensemble/commit/1f29b783f640e4cd6227c8bd36fd328b0b3f3f57))


## 2025-07-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.75`](#ensemble---v1175)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`

---

#### `ensemble` - `v1.1.75`

 - **FIX**(widget): improve semantics label handling in EWidgetState. ([24fe4bd9](https://github.com/ensembleUI/ensemble/commit/24fe4bd914a98f3cf10bd3113bd2d0fd599f067b))


## 2025-07-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.74`](#ensemble---v1174)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.74`

 - **FIX**(page_group): ensure default value for switchScreen in condition. ([eb222828](https://github.com/ensembleUI/ensemble/commit/eb222828e52f61c144db05a4cdb6c74f8ab52521))


## 2025-07-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.73`](#ensemble---v1173)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.73`

 - **FIX**(page_group): ensure default value for switchScreen in condition. ([eb222828](https://github.com/ensembleUI/ensemble/commit/eb222828e52f61c144db05a4cdb6c74f8ab52521))


## 2025-07-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.73`](#ensemble---v1173)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.73`

 - **FIX**(page_group): ensure default value for switchScreen in condition. ([eb222828](https://github.com/ensembleUI/ensemble/commit/eb222828e52f61c144db05a4cdb6c74f8ab52521))


## 2025-07-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.73`](#ensemble---v1173)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.73`

 - **FIX**: semantics handling for aria-label. ([1ef42542](https://github.com/ensembleUI/ensemble/commit/1ef42542757da00f3f86b449764a94d7badb9eba))
 - **FIX**: refine route change subscription logic in PageGroupState. ([02e03f33](https://github.com/ensembleUI/ensemble/commit/02e03f3321539a01e8dafa776060395f8106a6bd))


## 2025-07-24

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.72`](#ensemble---v1172)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.72`

 - **FIX**: update ensemble_app_badger dependency to version 1.6.1. ([9df43b5f](https://github.com/ensembleUI/ensemble/commit/9df43b5fb063b9dcafb25d571267b6799980965c))


## 2025-07-11

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.71`](#ensemble---v1171)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.71`


## 2025-07-01

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.70`](#ensemble---v1170)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.70`

 - n


## 2025-07-01

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.69`](#ensemble---v1169)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.69`


## 2025-07-01

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.68`](#ensemble---v1168)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.68`


## 2025-06-29

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.67`](#ensemble---v1167)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.67`

 - 1.1.67


## 2025-06-16

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.66`](#ensemble---v1166)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.66`

 - updating


## 2025-06-13

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.65`](#ensemble---v1165)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.65`

 - **REFACTOR**(adobe_analytics): streamline initialization and remove redundant checks. ([5714a3fc](https://github.com/ensembleUI/ensemble/commit/5714a3fc1820bb7522f3f08183d46dc727c300df))


## 2025-06-13

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.64`](#ensemble---v1164)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.64`

 - **REFACTOR**(adobe_analytics): streamline initialization and remove redundant checks. ([5714a3fc](https://github.com/ensembleUI/ensemble/commit/5714a3fc1820bb7522f3f08183d46dc727c300df))


## 2025-06-12

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.64`](#ensemble---v1164)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.64`

 - version build => enabling adobe analytics for build system


## 2025-06-12

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.63`](#ensemble---v1163)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.63`

 - **REFACTOR**: remove redundant event name checks in LogEvent class. ([09001583](https://github.com/ensembleUI/ensemble/commit/09001583522736c3c6876500ce24041ef47c8438))
 - **REFACTOR**: streamline Adobe Analytics event tracking and remove unused methods. ([d22e3aa8](https://github.com/ensembleUI/ensemble/commit/d22e3aa818a96b8b836ca88fde991b687eb2248c))
 - **FEAT**: integrate Assurance functionality into Adobe Analytics module. ([7e16c4e9](https://github.com/ensembleUI/ensemble/commit/7e16c4e9e7b7795e3b9517f264096601c32c1f69))
 - **FEAT**: integrate user profile management into Adobe Analytics module. ([e30660ee](https://github.com/ensembleUI/ensemble/commit/e30660ee8f201db10ad1a30e5c3e94c7a08e585b))
 - **FEAT**: add consent management to Adobe Analytics module. ([9a8a750f](https://github.com/ensembleUI/ensemble/commit/9a8a750f94699a20ada3d1606184df57dbee3720))
 - **FEAT**: enhance Adobe Analytics module with core, edge, and identity functionalities. ([a49e1224](https://github.com/ensembleUI/ensemble/commit/a49e1224f322b4780467d6e9b794e3896a0958fa))
 - **FEAT**: update Adobe Analytics methods to return dynamic results. ([3a9caf08](https://github.com/ensembleUI/ensemble/commit/3a9caf08fa37c03484ff3c04be4bf18bb6bd4d68))
 - **FEAT**: add setupAssurance method to Adobe Analytics module for session management. ([9d01e220](https://github.com/ensembleUI/ensemble/commit/9d01e2201f97baf1320ace14271ee70ceae3255e))
 - **FEAT**: enhance Adobe Analytics event tracking with timeout handling and parameter type adjustments. ([48d4880c](https://github.com/ensembleUI/ensemble/commit/48d4880c3138e463665b704681eec3d5f57188b7))
 - **FEAT**: add Adobe Analytics module for Ensemble integration. ([77fadddb](https://github.com/ensembleUI/ensemble/commit/77fadddb913ed20834f977db0fe78ee79c93005b))


## 2025-06-11

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.62`](#ensemble---v1162)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.62`


## 2025-06-06

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.61`](#ensemble---v1161)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.61`

 - Updating ensemble version to 1.1.61


## 2025-06-04

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.60`](#ensemble---v1160)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.60`


## 2025-06-03

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.59`](#ensemble---v1159)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.59`


## 2025-06-02

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.58`](#ensemble---v1158)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.58`

 - n

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2025-06-02

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.57`](#ensemble---v1157)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.57`

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2025-05-29

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.56`](#ensemble---v1156)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.56`


## 2025-05-27

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.55`](#ensemble---v1155)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.55`

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2025-05-26

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.54`](#ensemble---v1154)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.54`


## 2025-05-17

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.53`](#ensemble---v1153)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.53`

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2025-05-15

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.52`](#ensemble---v1152)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.52`


## 2025-05-15

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.51`](#ensemble---v1151)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.51`

 - n

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2025-05-09

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.50`](#ensemble---v1150)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.50`

 - **FIX**: add Bluetooth action types to ActionInvokable. ([8e662847](https://github.com/ensembleUI/ensemble/commit/8e662847ced9033b8cdbffebfec14dcb98e55f18))
 - **FIX**: firebase phone auth actions invokable. ([fe94ae21](https://github.com/ensembleUI/ensemble/commit/fe94ae21627c8460028860a8452b71dd99c18cf6))
 - **FIX**: CheckPermission action execution logic. ([b0af7e40](https://github.com/ensembleUI/ensemble/commit/b0af7e406e5504dc45443091a9657723242f363c))
 - **FIX**: add ActionType.getNetworkInfo to ActionInvokable. ([c7091665](https://github.com/ensembleUI/ensemble/commit/c7091665da2b933cab6aca8161c46ca16760c621))
 - **FEAT**: add new action types for badge management. ([71c98763](https://github.com/ensembleUI/ensemble/commit/71c987631dbc0d82f1f206e8607cc9abc5a5df34))
 - **FEAT**: implement PlaidLinkAction execution logic. ([0db8e85a](https://github.com/ensembleUI/ensemble/commit/0db8e85af03ec8275b1d30137789230518a2dedd))


## 2025-05-06

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.49`](#ensemble---v1149)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.49`

 - CHnaging to 1.1.49


## 2025-04-22

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.48`](#ensemble---v1148)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.48`

 - **FIX**: enhance package name and signature validation in DeviceSecurity class. ([1cecfd8e](https://github.com/ensembleUI/ensemble/commit/1cecfd8ee3f94f071eb292e1b450166f8244ba22))


## 2025-04-22

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.47`](#ensemble---v1147)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.47`

 - Ensemble to 1.1.47


## 2025-04-18

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.45`](#ensemble---v1145)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.45`


## 2025-04-18

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.44`](#ensemble---v1144)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.44`

 - **REFACTOR**: replace root_jailbreak_sniffer with safe_device for enhanced device security checks. ([2b873f56](https://github.com/ensembleUI/ensemble/commit/2b873f56083dc7c16e79efabe4addc25e66ea327))


## 2025-04-11

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.43`](#ensemble---v1143)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.43`


## 2025-04-09

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.42`](#ensemble---v1142)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.42`

 - **REFACTOR**: update validateJsCode method to include DataContext parameter. ([cfee0493](https://github.com/ensembleUI/ensemble/commit/cfee049346da5a82528360b37bbbeb4ce0ff9cd2))
 - **REFACTOR**: update validateJsCode method to remove DataContext parameter. ([ab6bc651](https://github.com/ensembleUI/ensemble/commit/ab6bc651ad44cc07954cd408d72a1f19d977f384))
 - **FEAT**: simplify EnsembleStorage method mappings and enhance JSValidator property access error handling. ([05661a5e](https://github.com/ensembleUI/ensemble/commit/05661a5e0d132cbc0342a88f90d8da5521185ec6))
 - **FEAT**: update EnsembleStorage methods to accept dynamic values for setProperty and implement property access checks. ([1e3373a5](https://github.com/ensembleUI/ensemble/commit/1e3373a50185a2732c8468c4f4743da25e72a279))
 - **FEAT**: refactor JSInterpreter validation logic into JSValidator for improved error handling and context-aware checks. ([b47d93ac](https://github.com/ensembleUI/ensemble/commit/b47d93ac1db79e65dc77082c127ca867c5f437a4))
 - **FEAT**: enhance JS code validation in DevMode and add detailed error handling. ([00d0f617](https://github.com/ensembleUI/ensemble/commit/00d0f6172ff96eb2368aca85c6199da12d937db5))
 - **FEAT**: add JS code validation method in DevMode class. ([6006ffcb](https://github.com/ensembleUI/ensemble/commit/6006ffcbd1e10044d25109f0574bd858a1db43dd))


## 2025-04-09

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.41`](#ensemble---v1141)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.41`

 - Updating Ensemble to 1.1.41


## 2025-04-03

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.40`](#ensemble---v1140)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.40`


## 2025-03-26

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.39`](#ensemble---v1139)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.39`

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2025-03-24

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.38`](#ensemble---v1138)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.38`

 - Bump "ensemble" to `1.1.38`.


## 2025-03-24

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.37`](#ensemble---v1137)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.37`

 - Bump "ensemble" to `1.1.37`.

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2025-03-22

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.36`](#ensemble---v1136)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.36`


## 2025-03-14

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.35`](#ensemble---v1135)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.35`


## 2025-03-13

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.34`](#ensemble---v1134)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.34`

 - Bump "ensemble" to `1.1.34`.


## 2025-03-12

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.33`](#ensemble---v1133)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.33`

 - **FIX**: keep the focus sensitive field focused on dialog open. ([efc94638](https://github.com/ensembleUI/ensemble/commit/efc94638254ed69c55f8bf8d1192cd5d2c51d6ba))


## 2025-03-06

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.31`](#ensemble---v1131)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.31`

 - Changing version


## 2025-03-03

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.30`](#ensemble---v1130)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.30`


## 2025-03-03

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.29`](#ensemble---v1129)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.29`

 - **FIX**(notification_manager): initialize message handling on startup. ([9ca35acb](https://github.com/ensembleUI/ensemble/commit/9ca35acbd9b868198acb29fa618841b362ac8d19))


## 2025-02-28

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.28`](#ensemble---v1128)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.28`


## 2025-02-24

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.27`](#ensemble---v1127)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.27`

 - **FIX**: handle exceptions in getLocalAssetFullPath. ([8844d487](https://github.com/ensembleUI/ensemble/commit/8844d4874ddde3e7a3244e663c5cdcf0ee6520b7))


## 2025-02-21

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.26`](#ensemble---v1126)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.26`

 - **FIX**: ensure EnsembleConfigService is initialized before accessing config. ([1f8df899](https://github.com/ensembleUI/ensemble/commit/1f8df8997f7a9ab2dffae88ad96ac898cb49fa0a))


## 2025-02-21

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.25`](#ensemble---v1125)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.25`


## 2025-02-20

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.24`](#ensemble---v1124)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.24`

 - Bump "ensemble" to `1.1.24`.


## 2025-02-19

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.23`](#ensemble---v1123)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.23`


## 2025-02-13

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.22`](#ensemble---v1122)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.22`

 - **REFACTOR**: remove no internet widget. ([e03359b2](https://github.com/ensembleUI/ensemble/commit/e03359b2dd6b1290bea39c71c69e2a3d5ad27c13))
 - **REFACTOR**: replace offline widget with error screen for no internet connection. ([b0163a1b](https://github.com/ensembleUI/ensemble/commit/b0163a1ba20eb72c7a459afb3dfa59e1729cf9bf))
 - **FIX**: auto complete dropdown selected label. ([80b9c8f5](https://github.com/ensembleUI/ensemble/commit/80b9c8f54c753aca7884fd12ed449c5f019d981b))
 - **FEAT**: reinitialize app state when internet connectivity is restored. ([e914e337](https://github.com/ensembleUI/ensemble/commit/e914e337e54bbe539f08aa192b0a50b118708a00))
 - **FEAT**: implement internet connectivity check in runtime. ([30204d3b](https://github.com/ensembleUI/ensemble/commit/30204d3bb29324d9ae44380fc919b450cf30cfd0))


## 2025-02-07

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.21`](#ensemble---v1121)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.21`


## 2025-02-07

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.20`](#ensemble---v1120)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.20`

 - Bump "ensemble" to `1.1.20`.


## 2025-02-06

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.19`](#ensemble---v1119)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.19`


## 2025-01-30

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.18`](#ensemble---v1118)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.18`


## 2025-01-23

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.17`](#ensemble---v1117)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.17`

 - **FIX**: bad state no element on scrollabletabbar. ([f45b71e6](https://github.com/ensembleUI/ensemble/commit/f45b71e67caef2fc7753a837a7c1f27db0eeb4a2))


## 2025-01-23

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.16`](#ensemble---v1116)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.16`

 - **REFACTOR**: make phoneNumber optional and handle empty values in verification actions. ([49810b31](https://github.com/ensembleUI/ensemble/commit/49810b315fb461964d8839b5b619538611f63cbb))
 - **REFACTOR**: simplify payload handling in verification code actions. ([0441b40c](https://github.com/ensembleUI/ensemble/commit/0441b40c7e355eae9e7960f9ea15b41571d5d19d))
 - **REFACTOR**: rename otp verification methods. ([7e3408e0](https://github.com/ensembleUI/ensemble/commit/7e3408e01a1006700be01e1f4403395eebd13f32))
 - **FEAT**: update validateVerificationCode to return user and idToken, enhance onSuccess callback. ([33abb106](https://github.com/ensembleUI/ensemble/commit/33abb10689de2fcb5328194a44097a6757e0298d))
 - **FEAT**: add onVerificationFailure callback to handle verification errors more effectively. ([08bc0ac6](https://github.com/ensembleUI/ensemble/commit/08bc0ac676139b543e24694f290df58dd57d4f13))
 - **FEAT**: add method parameter to verification code actions for improved method handling. ([976adb71](https://github.com/ensembleUI/ensemble/commit/976adb7154ac3a8007828a6bf74e8d9c6c7d5a3c))
 - **FEAT**: add provider parameter to verification code actions for enhanced flexibility. ([440e1f32](https://github.com/ensembleUI/ensemble/commit/440e1f323706ac47243950cdceef441cc00b8694))
 - **FEAT**: implement phone verification actions with firebase phone auth. ([5927c37c](https://github.com/ensembleUI/ensemble/commit/5927c37c9b636f7acf7c480d26db9c8d0217c90e))


## 2025-01-16

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.15`](#ensemble---v1115)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.15`

 - **FIX**: type comma. ([f0749e36](https://github.com/ensembleUI/ensemble/commit/f0749e36da3e1f3e39866039b1062bd8f81319ee))
 - **FIX**: typo missing semi-colon. ([76d0d99a](https://github.com/ensembleUI/ensemble/commit/76d0d99a8a7f0a2b0f583cb7888c649cfd0b3282))


## 2025-01-07

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.14`](#ensemble---v1114)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.14`

# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2025-01-03

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.13`](#ensemble---v1113)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.13`

 - Moengage Module Release

 - **FIX**: unreliable showpreview. ([2365d35e](https://github.com/ensembleUI/ensemble/commit/2365d35e5b44743d1924ce5c6e7875676858296b))


## 2024-12-16

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.12`](#ensemble---v1112)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.12`

 - **FIX**: fluttertoast breaking changes. ([d29696d3](https://github.com/ensembleUI/ensemble/commit/d29696d3a4869ce0837c1f200e5ccfe7aa1449f7))


## 2024-12-11

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.11`](#ensemble---v1111)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.11`


## 2024-12-09

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.10`](#ensemble---v1110)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.10`

 - **FIX**: multiple navigator key. ([7ae53f25](https://github.com/ensembleUI/ensemble/commit/7ae53f2542790c5fe0ec616d98f7aba69f277e3b))


## 2024-11-28

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.8`](#ensemble---v118)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.8`

 - Bump "ensemble" to `1.1.8`.


## 2024-11-27

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.6`](#ensemble---v116)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.6`

 - Bump "ensemble" to `1.1.6`.


## 2024-11-26

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.5`](#ensemble---v115)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.5`

 - **FIX**: uninitialized getIt and handle externalKey properly. ([9b46738a](https://github.com/ensembleUI/ensemble/commit/9b46738a4a9cde57f09db7f40d174baed9e57550))


## 2024-11-18

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.4`](#ensemble---v114)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.4`

 - Ensemble version with flutter 3.24.3 support


## 2024-11-18

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.3`](#ensemble---v113)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.3`

 - last ensemble version to support flutter 3.19.5

 - **FEAT**: Add reactive orientation support to Device class. ([47fc9314](https://github.com/ensembleUI/ensemble/commit/47fc93148c1eeaea7e87c4eb4131aa368726e9f7))


## 2024-11-14

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.2`](#ensemble---v112)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.2`

 - last ensemble support for 3.19.5


## 2024-11-08

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.1`](#ensemble---v111)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_bluetooth` - `v0.0.1+1`](#ensemble_bluetooth---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_bluetooth` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.1`


## 2024-10-08

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.1.0`](#ensemble---v110)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.1.0`


## 2024-10-03

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.0.9`](#ensemble---v109)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.0.9`


## 2024-10-01

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.0.8`](#ensemble---v108)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`

---

#### `ensemble` - `v1.0.8`


## 2024-10-01

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.0.7`](#ensemble---v107)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`

---

#### `ensemble` - `v1.0.7`


## 2024-10-01

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.0.7`](#ensemble---v107)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`

---

#### `ensemble` - `v1.0.7`


## 2024-10-01

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.0.7`](#ensemble---v107)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.0.7`

 - Bump "ensemble" to `1.0.7`.


## 2024-10-01

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.0.7`](#ensemble---v107)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`

---

#### `ensemble` - `v1.0.7`

 - moving to 1.0.7 to fix the version issue with firebase analytics


## 2024-09-28

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.0.6`](#ensemble---v106)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`

---

#### `ensemble` - `v1.0.6`


## 2024-09-13

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.0.5`](#ensemble---v105)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.0.5`

 - Bump "ensemble" to `1.0.5`.


## 2024-09-13

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.0.4`](#ensemble---v104)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.0.4`


## 2024-08-28

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.0.3`](#ensemble---v103)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.0.3`

 - Unified theme


## 2024-08-28

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.0.2`](#ensemble---v102)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_auth` - `v1.0.1`
 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`

---

#### `ensemble` - `v1.0.2`


## 2024-08-27

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`ensemble` - `v1.0.1`](#ensemble---v101)
 - [`ensemble_chat` - `v0.0.1+1`](#ensemble_chat---v0011)
 - [`ensemble_camera` - `v0.0.1+1`](#ensemble_camera---v0011)
 - [`ensemble_auth` - `v1.0.1`](#ensemble_auth---v101)
 - [`ensemble_location` - `v0.0.1+1`](#ensemble_location---v0011)
 - [`ensemble_file_manager` - `v0.0.1+1`](#ensemble_file_manager---v0011)
 - [`ensemble_deeplink` - `v0.0.1+1`](#ensemble_deeplink---v0011)
 - [`ensemble_contacts` - `v0.0.1+1`](#ensemble_contacts---v0011)
 - [`ensemble_network_info` - `v0.0.1+1`](#ensemble_network_info---v0011)
 - [`ensemble_connect` - `v0.0.1+1`](#ensemble_connect---v0011)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `ensemble_chat` - `v0.0.1+1`
 - `ensemble_camera` - `v0.0.1+1`
 - `ensemble_auth` - `v1.0.1`
 - `ensemble_location` - `v0.0.1+1`
 - `ensemble_file_manager` - `v0.0.1+1`
 - `ensemble_deeplink` - `v0.0.1+1`
 - `ensemble_contacts` - `v0.0.1+1`
 - `ensemble_network_info` - `v0.0.1+1`
 - `ensemble_connect` - `v0.0.1+1`

---

#### `ensemble` - `v1.0.1`


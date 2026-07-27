# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - 2026-07-26

### Changed

- The startup enable no longer emits an info notification; `setup()` is now
  silent. The `:Aperture*` commands still confirm enable/disable (gated by
  `quiet`), and `enable`/`disable`/`toggle` accept `{ silent = true }`.

### Fixed

- The `termguicolors` warning is deferred until after startup, so a config that
  enables `termguicolors` later in init is no longer flagged as a false
  positive.

## [1.1.0] - 2026-07-26

### Added

- `:checkhealth aperture` support, reporting Neovim version, `termguicolors`
  state, whether `setup()` ran, the active feature state, and the number of
  captured highlight groups.
- Autosize and dimming now re-run when a window is closed (`WinClosed`), so the
  remaining layout updates immediately instead of waiting for the next focus
  change.
- A warning is emitted when dimming is enabled while `termguicolors` is off,
  since dimming relies on true-color highlights to render.

### Fixed

- List options (`excluded_filetypes`, `excluded_buftypes`,
  `excluded_highlight_patterns`) now replace their defaults wholesale instead of
  being merged element-by-element, so a user list can shrink or clear a
  non-empty default.
- Highlight groups whose only styling is an attribute (reverse, undercurl,
  strikethrough, standout, etc.) are no longer dropped and now get dimmed.
- Refresh timer lifecycle is cleaned up so the libuv handle is stopped and
  released on disable.
- Disabling dimming no longer tears down the shared autocmd group while autosize
  still needs it.
- Removed an inconsistent `dim_amount` fallback.

## [1.0.0]

- Initial release.

[1.1.1]: https://github.com/gigacrat/aperture.nvim/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/gigacrat/aperture.nvim/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/gigacrat/aperture.nvim/releases/tag/v1.0.0

# Release media fonts

Unmodified static Japanese fonts from [Google Fonts](https://github.com/google/fonts),
downloaded on 2026-10-16. They are bundled so screenshot and video generation does
not depend on a CDN being available during a release.

- `ofl/zenkakugothicnew`: Zen Kaku Gothic New, Bold and Medium.
- `ofl/zenoldmincho`: Zen Old Mincho, Bold and Regular (optional `STORE_FONT=mincho`).

Each family includes its SIL Open Font License. `scripts/verify_store_fonts.py`
records and verifies the SHA-256 of each font. These files are only used by the
release media scripts; they are not bundled into the iOS app.

# SBC codec

Unmodified portable C implementation from [google/libsbc](https://github.com/google/libsbc), commit `6e505650145c9973d08a0bdd5e5f5e1914305e40`.

Copyright 2022 Google LLC. Apache-2.0; see [LICENSE](LICENSE). The App bundles that license. No ARM-specific assembly is included.

Used by the YK-8E00 HID voice adapter. The Swift boundary accepts only the observed 60-byte, 16 kHz mono SBC profile and validates CRCs. This is ordinary SBC, not mSBC.

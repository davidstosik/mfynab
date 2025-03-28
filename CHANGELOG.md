# CHANGELOG.md

## (unreleased)

## 0.3.0 (2025-03-26)

- Credentials can now be stored in the config file.
  (This change is backwards compatible.)
  ([eda0358](eda03587c39bfbe55d3b83a5d7dce21a61a38d2c))
- The configuration YAML file does not need a top-level key anymore.
  (This change is backwards compatible.)
  ([f03bf24](f03bf24303cd9c89f1147a0071474067f9b0afa8))

## 0.2.0 (2025-03-25)

- Refresh accounts on Money Forward before syncing transactions to YNAB.
  ([6d0a5e4](6d0a5e4288d0b45424485e2396e6399637a14eef))
- (Fix) Handle scenario where multiple YNAB accounts may match the partial string passed in the config file.
  ([3a34c29](3a34c29682228e9b080e2db25ffb48b1a92e8ee2))
- Increase memo and payee max lengths, following changes in YNAB's API
  ([cc0ffcf](cc0ffcf3879efaa748ee31af9c35cb49d94a47c8))

## 0.1.4 (2024-08-25)

- Fix `months_to_sync` configuration key not being used
  ([889d241](889d241ce5a56672e2fd9dac639fc29b78aea168))
- Log how many transactions were actually imported vs duplicates
  ([a7d21de](a7d21de7b26319c362d3dda0119de3167042cc9b))

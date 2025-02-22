# CHANGELOG.md

## (unreleased)

- (Fix) Handle scenario where multiple YNAB accounts may match the partial string passed in the config file.
  ([TBD]())
- Increase memo and payee max lengths, following changes in YNAB's API
  ([243b60b](243b60b90efe2e70e50156d1a9cc4330f81cb563))

## 0.1.4 (2024-08-25)

- Fix `months_to_sync` configuration key not being used
  ([889d241](889d241ce5a56672e2fd9dac639fc29b78aea168))
- Log how many transactions were actually imported vs duplicates
  ([a7d21de](a7d21de7b26319c362d3dda0119de3167042cc9b))

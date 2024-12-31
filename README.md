# MoneyForward to YNAB migrator

This Ruby script downloads transaction history from Money Forward then uploads
it to YNAB.

## Principle

- Use [Ferrum](https://github.com/rubycdp/ferrum) to browse to the Money Forward
  website, log in and save a session cookie.
- Craft HTTP requests to Money Forward including the session cookie above to
  retrieve transactions in CSV files.
- Parse the CSV files and convert the data to a format that works with YNAB.
- Use [YNAB API Ruby library](https://github.com/ynab/ynab-sdk-ruby) to post
  transactions to your YNAB budget.
- Budget and account mappings are set in a configuration file (see `config/example.yml`).

## Setup

You'll need Ruby 3.3.0 or above.

```sh
# Install gem
gem install mfynab

# Start a config YAML file
wget https://raw.githubusercontent.com/davidstosik/moneyforward_ynab/main/config/example.yml -O mfynab-david.yml
```

The script currently looks for credentials in environment variables:

- `MONEYFORWARD_USERNAME`
- `MONEYFORWARD_PASSWORD`
- `YNAB_ACCESS_TOKEN`

You can for example use [dotenv](https://github.com/bkeepers/dotenv)
to store your secrets in a `.env` file:

```
MONEYFORWARD_USERNAME=david@example.com
MONEYFORWARD_PASSWORD=Passw0rd!
YNAB_ACCESS_TOKEN=abunchofcharacters
```

Alternatively, you can also use something [1Password's CLI](https://developer.1password.com/docs/cli/)
to avoid storing clear secrets:

```
MONEYFORWARD_USERNAME=op://Private/Moneyforward/username
MONEYFORWARD_PASSWORD=op://Private/Moneyforward/password
YNAB_ACCESS_TOKEN=op://Private/YNAB/secrets/API token
```

## Running

To run, you'll simply need to set the environment variables.

Using `dotenv`, that'll look like this:

```sh
dotenv mfynab mfynab-david.yml
```

Using 1Password's CLI, that would look like this:

```sh
op run --env-file=.env -- mfynab mfynab-david.yml
```

## Development

After checking out the repo, run `bundle install` to install dependencies.
Then, run `bin/rake test` to run the tests.

## Todo

- Force MoneyForward to sync all accounts before downloading data. (Can take a while.)
- Use Thor to manage the CLI. (And/or TTY?)
- Implement `Transaction` model to extract some logic from existing classes.
- Handle the Amazon account differently (use account name as payee instead of content?)
- Implement CLI to setup config.
  - Save/update session_id so browser is only needed once.
- Generate new configuration file with the command line.
- Make reusable fixtures instead of setting up every test
- Improve secrets handling:
  - Store config/credentials in `~/.config/`?
  - Encrypt config, use Keyring or other OS-level secure storage?
    - Possible to write a gem with native extension based on <https://github.com/hrantzsch/keychain>? (or <https://github.com/hwchen/keyring-rs>?)
  - Open browser, ask user to log into MoneyForward and store cookie? (Does it expire though?)
    - Or prompt user from credentials in terminal and fill in form in headless browser
    - Need to handle case when cookie has expired:
      > セキュリティ設定	最終利用時間から[30日]後に自動ログアウト

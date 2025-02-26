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

## Roadmap

### Refresh bank accounts in Money Forward

Using the browser, log in, then press the 更新 button for each account declared in the config file.

Tricky parts:
- Refreshing can take some time, so we should also implement a way to check progess. (Does it show 更新中 and a loading spinner for that account?)
- Sometimes, Money Forward needs to fill a captcha or one-time password. How can I pass that to mfynab and have it fill it?

### Better session management

- If Money Forward username/password is not passed in the environment, open a browser and ask the user to log in.
- Save cookie for reuse. Every request to Money Forward refreshes the `_moneybook_session` cookie with a new expiry date. (Appears to be a full year.) If we save that cookie every time it is refreshed, then use it in future requests, we can keep the session active for a long time (for ever?).

Previous notes:
- Open browser, ask user to log into MoneyForward and store cookie? (Does it expire though?)
  - Or prompt user from credentials in terminal and fill in form in headless browser
  - Need to handle case when cookie has expired:
    > セキュリティ設定	最終利用時間から[30日]後に自動ログアウト

### Deploy/Automate

I'd like to be able to deploy something to a server, that would run the sync on a schedule (eg. every hour or day).
I could for example use Kamal to produce a Docker image that includes all needed secrets and will run a script on a schedule.

### Later

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
- Why does it show a higher number in imported, than importing?
  ```
  Importing 46 transactions for AAA
  Imported 51 transactions for AAA (0 duplicates)
  Importing 10 transactions for BBB
  Imported 10 transactions for BBB (0 duplicates)
  Importing 2 transactions for CCC
  Imported 3 transactions for CCC (0 duplicates)
  Importing 21 transactions for DDD
  Imported 24 transactions for DDD (0 duplicates)
  ```
- Passing logger everywhere feels weird.

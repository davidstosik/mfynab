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

Credentials can be set in your config file directly:

```yml
credentials:
  ynab_access_token: "plain_text_access_token"
  moneyforward_username: "david@example.com"
  moneyforward_password: "plain_text_password"
```

It is also possible to have the config fetch secrets from environment variables (this is the default in the example config file):

```yml
credentials:
  ynab_access_token:
    type: "env"
    value: "YNAB_ACCESS_TOKEN"
  moneyforward_username:
    type: "env"
    value: "MONEYFORWARD_USERNAME"
  moneyforward_password:
    type: "env"
    value: "MONEYFORWARD_PASSWORD"
```

If using environment variables, you can for example also use
[dotenv](https://github.com/bkeepers/dotenv)
to store your secrets in a `.env` file:

```
MONEYFORWARD_USERNAME=david@example.com
MONEYFORWARD_PASSWORD=Passw0rd!
YNAB_ACCESS_TOKEN=abunchofcharacters
```

<a name="one-password-cli"></a>

Alternatively, you can also use something like [1Password's CLI](https://developer.1password.com/docs/cli/)
to completely avoid storing clear secrets:

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

## Running MFYNAB with cron and Docker

The `docker-example/` directory contains sample files that'll help you schedule MFYNAB inside a Docker container.

See the comments in each file for more details on how it works.

First you'll want to bring your MFYNAB configuration file into this directory:

```sh
cp path_to/config.yml docker_example/
```

Then you can build the Docker image:

```sh
docker build -t mfynab docker_example/
```

Finally, you can run the Docker image. Note that you need to pass secrets as environment variables:

```sh
docker run -d \
  --env YNAB_ACCESS_TOKEN=... \
  --env MONEYFORWARD_USERNAME=... \
  --env MONEYFORWARD_PASSWORD='...' \
  --name mfynab mfynab
```

You can also use the 1Password CLI ([documented here](#one-password-cli)) for this step:

```sh
op run --env-file=.env -- sh -c 'docker run -d \
  --env YNAB_ACCESS_TOKEN=$YNAB_ACCESS_TOKEN \
  --env MONEYFORWARD_USERNAME=$MONEYFORWARD_USERNAME \
  --env MONEYFORWARD_PASSWORD="$MONEYFORWARD_PASSWORD" \
  --name mfynab mfynab'
```

## Roadmap

### Deploy/Automate

I'd like to be able to deploy something to a server, that would run the sync on a schedule (eg. every hour or day).
I could for example use Kamal to produce a Docker image that includes all needed secrets and will run a script on a schedule.

### Better session management

- If Money Forward username/password is not passed in the environment, open a browser and ask the user to log in.
- Save cookie for reuse. Every request to Money Forward refreshes the `_moneybook_session` cookie with a new expiry date. (Appears to be a full year.) If we save that cookie every time it is refreshed, then use it in future requests, we can keep the session active for a long time (for ever?).

Previous notes:
- Open browser, ask user to log into MoneyForward and store cookie? (Does it expire though?)
  - Or prompt user from credentials in terminal and fill in form in headless browser
  - Need to handle case when cookie has expired:
    > セキュリティ設定	最終利用時間から[30日]後に自動ログアウト

### Later

- Improve CHANGELOG. Not sure exactly what to do, but the current process with SHA links feels a bit tedious.
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
- Prompt user for captcha and other account extra authentication required by Money Forward?
- One might want to run a single Docker instance for multiple users, but the current setup does not allow that easily. We'll want to bring the secret environment variables into the config file, making it possible to assign them to a given "user", and name them accordingly.

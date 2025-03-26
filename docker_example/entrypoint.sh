#!/usr/bin/env sh

# Save environment variables to a file, so we can forward them to cron jobs
env >> /etc/environment

# Run cron in the foreground
cron -f

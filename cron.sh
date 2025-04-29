#!/bin/bash
set -eu

# Start cron in foreground, log to stdout
exec cron -f -L /dev/stdout
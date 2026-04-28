#!/bin/bash
set -e

cd /home/devmvpcodeworks/repo
git pull

# Copy all files including dotfiles (.htaccess, etc.)
cp -r -f repo/. /home/devmvpcodeworks/public_html/

touch /home/devmvpcodeworks/public_html/tmp/restart.txt

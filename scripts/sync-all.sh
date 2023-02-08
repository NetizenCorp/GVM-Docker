#!/usr/bin/env bash

echo "Downloading Feed Data..."
su -c "/usr/local/bin/greenbone-feed-sync" gvm

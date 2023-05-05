#!/usr/bin/env bash

echo "Downloading GVM Feed Data..."
su -c "greenbone-feed-sync -v	--compression-level=9" gvm

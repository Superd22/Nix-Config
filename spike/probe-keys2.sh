#!/bin/sh
echo "--- major keys ---"
aerospace config --major-keys 2>&1
echo
echo "--- all keys (first 60) ---"
aerospace config --all-keys 2>&1 | head -60

#!/bin/sh
# Confirms the two new keys are real config keys on the installed build, and
# shows what the live (config-version = 1) config currently infers.
echo "--- does the running build know these keys? ---"
aerospace config --all-keys 2>&1 | grep -E 'config-version|persistent-workspaces|on-window-detected'

echo
echo "--- current value of config-version ---"
aerospace config --get config-version 2>&1

echo
echo "--- persistent-workspaces as inferred under config-version = 1 ---"
aerospace config --get persistent-workspaces --json 2>&1

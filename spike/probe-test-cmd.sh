#!/bin/sh
# Does the running AeroSpace accept the new command-based condition syntax that
# the modern on-window-detected `if` uses? `aerospace test` is that same
# evaluator exposed on the CLI, so it answers without touching the live config.
echo "--- test --help ---"
aerospace test --help 2>&1

echo
echo "--- literal comparison (expect: exit 0) ---"
aerospace test foo = foo
echo "exit=$?"

echo
echo "--- literal comparison, false (expect: exit 1) ---"
aerospace test foo = bar
echo "exit=$?"

echo
echo "--- interpolation var, no focused window context ---"
aerospace test %{app-bundle-id} = com.apple.iphonesimulator
echo "exit=$?"

echo
echo "--- what interpolation vars exist ---"
aerospace echo %{app-bundle-id} 2>&1
echo "exit=$?"

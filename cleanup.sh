#!/bin/bash

set -euo pipefail

# Cleanup and remove all running, stopped or delete instances
multipass stop --all && multipass delete --all && multipass purge

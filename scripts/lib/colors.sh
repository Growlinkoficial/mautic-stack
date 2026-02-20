#!/bin/bash

# Source guard
if [ -n "${_LIB_COLORS_SH_LOADED:-}" ]; then return; fi
_LIB_COLORS_SH_LOADED=1

# Cores ANSI para saída no terminal
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m' # No Color

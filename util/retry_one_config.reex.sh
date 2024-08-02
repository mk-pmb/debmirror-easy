#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
"$(readlink -m -- "$BASH_SOURCE"/..)"/hardreset_experimental.sh \
  --then retry_one_config "$@"; exit $?

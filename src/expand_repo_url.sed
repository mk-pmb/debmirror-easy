#!/bin/sed -nurf
# -*- coding: UTF-8, tab-width: 2 -*-

/^ppa:/{s~^ppa:~http://ppa.launchpad.net/~;s~$~/ubuntu/~;p}

#!/bin/sed -nurf
# -*- coding: UTF-8, tab-width: 2 -*-
#
# Convert debian control files (e.g. Release/Packages lists) to JSON.
# https://www.debian.org/doc/debian-policy/ch-controlfields.html

i [{

: read_more
  s~\r$~~
  /\n$/b convert
  $b convert
  N
b read_more

: convert
  s~\f~~g
  s~\\~&&~g
  s~"~\\"~g
  s~\n ~\\n~g
  s~\t~\\t~g
  s~\s*$~"~
  s~\n~",&~g
  s~(^|\n)(\S+)(:\s)~\1  "\2"\3"~g
  $!s~$~\n},{~
  $s~$~\n}]~
  s~"(-?[0-9]+)"(,\n)~\1\2~g
  p;n
b read_more

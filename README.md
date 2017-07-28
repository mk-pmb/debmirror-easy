
debmirror-easy
==============

Helps me mirror Debian package repositories.

Launch multiple instances of debmirror according to your config files,
with logging and automatic repo URL splitting.


Usage
-----

[example config](docs/example.dm-easy.rc),
[example daily cron job](docs/example.cron.txt)


<!--#toc stop="scan" -->



Known issues
------------

* `gzip: stdin: not in gzip format` / `Failed: gzip -d <.temp/dists/…`:
  use [debmirror-pmb](https://github.com/mk-pmb/debmirror-pmb/issues/1).




License
-------
<!--#echo json="package.json" key=".license" -->
ISC
<!--/#echo -->


<!--#echo json="package.json" key="name" underline="=" -->
debmirror-easy
==============
<!--/#echo -->

<!--#echo json="package.json" key="description" -->
Helps me mirror Debian package repositories.
<!--/#echo -->

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
  Use https://github.com/mk-pmb/debmirror-salsa-22/tree/experimental .




License
-------
<!--#echo json="package.json" key=".license" -->
ISC
<!--/#echo -->

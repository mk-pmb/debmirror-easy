
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


Installation
------------

* Use Ubuntu 22.04 or later.
* Clone this repo.
* Install these apt packages
  (you can use [`util/install_deps.sh`](util/install_deps.sh) to do that):

<!--#include file="util/install_deps.sh" outdent="    " code="text"
  start="  local PKG=(" stop="  )" -->
<!--#verbatim lncnt="5" -->
```text
liblockfile-simple-perl
libstring-shellquote-perl
libwww-perl   # LWP::UserAgent
```
<!--/include-->

* That should be all.



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

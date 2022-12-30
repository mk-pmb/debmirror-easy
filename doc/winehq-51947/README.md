
WineHQ problem 51947
====================

Original problem description:
https://bugs.winehq.org/show_bug.cgi?id=51947

```text
Hi! I'm trying to fix my debmirror. If I want to support Ubuntu focal,
I need to add "all" to the architectures in order to mirror
https://dl.winehq.org/wine-builds/ubuntu/dists/focal/main/binary-all/ .
But if I do so, bionic and xenial fail becuase they don't have a
main/binary-all directory.
Could you please create those and put a dummy placeholder file in?
```



Defending the wine devs' inaction
---------------------------------

While at first glance, adding a directory and a dummy file seems trivial
enough a task to make the world a better place, it's out of project scope
for wine. And rightly so, because once wine devs would start to accept
feature creep for external tools compatibility, they'd have to either
accept every request from every tool maker, or start explaining why they
help one and not the other.



Work-around strategies
----------------------


### Doubt

__Strategy:__
Hope there (no longer) is a problem.
To try it: `./try.sh doubt_with_all.rc`

__Benefits:__
Always a good idea to verify a problem still exists before you try a
work-around. Someone else might have fixed it already after all!

__Drawbacks:__
```text
220430-220344 D: dm: [100%] Getting: dists/trusty/main/binary-all/Packages.gz... failed 404 Not Found
220430-220344 D: dm: Errors:
220430-220344 D: dm:  Ignoring missing Release file for dists/trusty/main/binary-all/Packages.gz
220430-220344 D: dm:  Download of dists/trusty/main/binary-all/Packages.gz failed: 404 Not Found
220430-220344 D: dm: Failed to download some Package, Sources or Release files!
```


### Use separate mirror directories

__Strategy:__
Use one directory to mirror pre-focal winehq
(precise, trusty, xenial, bionic)
and a different one for the new (focal and later) packages.

__Benefits:__
Works cleanly.

__Drawbacks:__
Potentially duplicate shared files might waste space on
non-deduping file systems.


### Re-use same directory naively

__Strategy:__
Run debmirror multiple times, once for each combination of
distros and architectures,
re-using the same target directory.
To facilitate this, I added the [reruns feature](../reruns.md) to DME.

__Benefits:__
Semi-easy and seems to work.

__Drawbacks:__
On closer inspection, it fails horribly:
Each run's cleanup removes most of the downloads from previous runs. 🤦


### Re-use same directory with restricted cleanup

__Strategy:__
Same as above, but with `--ignore=` patterns for all distros not in this run.
To try it: `./try.sh rerun_with_ignore.rc`

__Benefits:__
Could work with original debmirror, in theory.

__Drawbacks:__
Only works if you disable the local cache, because original debmirror
ignores the `--ignore=` option when cleanup uses the cache. 🤦
(Fixed in https://github.com/mk-pmb/debmirror-salsa-22/tree/experimental .)




















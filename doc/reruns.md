
Reruns
======

The reruns idea was a failed attempt at creating a work-around for
[WineHQ problem 51947](winehq-51947/README.md).

On the first run, variable `CFG_RERUN` is always empty.

Only in that first run, we can request additional runs by setting it to
a space-separated list of shell-safe names.
If we do so, each of those names will cause an additional run,
with `CFG_RERUN` set to that name,
in the order they were given.


⚠ Hazards ⚠
-----------

Make sure your subsequent runs won't sabotage the previous ones,
e.g. by removing files in the cleanup step, or by generating index
files that list only the current run's packages.



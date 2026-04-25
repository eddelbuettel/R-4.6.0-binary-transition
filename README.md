
## R 4.6.0 binary transition

### Context

R 4.6.0 was released yesterday. It brought changes to the header files which impact the run-time of
installed and pre-made packages.

Why you ask? Well, the R Core team has for decades shipped R with C language headers containing
functions and variables it considered private. Consider it a 'global marshmallow test': "We told you
all not to eat these."  Other people, myself included, consider _each published API header_ a
'contract' and view shipping it as both an implicit contract to not alter these headers with an
honour code to provide backwards compatibility. R, once again, is different.

There is no point now debating this _at nauseum_. Many of us tried to precent this, but the release
was made the it was. Going forward, we will have a cleaner understanding (and improved seperation of
_public_ installed header and _private_ compile-time only source headers) which is nice. But we also
have breakage now nice. Which is not nice.  

### So What Happens?

Consider this simple illustration of R 4.6.0 in the updated r-base container.  After install
`data.table` or `rlang` as a binary, it fails to load:

```
root@e47199f8b6fd:/# Rscript -e 'library(rlang)'
Error: package or namespace load failed for ‘rlang’ in dyn.load(file, DLLpath = DLLpath, ...):
 unable to load shared object '/usr/lib/R/site-library/rlang/libs/rlang.so':
  /usr/lib/R/site-library/rlang/libs/rlang.so: undefined symbol: SETLENGTH
Execution halted
root@e47199f8b6fd:/# 
```

The same thiing happens on every installation containing locally compiled packages. I upgraded to R
4.6.0 on my Ubuntu machine, and packages like `data.table` or `RSQLite` (because of `rlang`) no
longer loaded (so CRANberries was down).  A quick local compilation helped.

### How Big A Deal ?

CRAN currently has about 5100 compiled packages among 23000 packages. We know the nearly 18000
R-only packages are not affected. For the 5100 others we need a search tool. This repo tried to work
towards this.  Of course, non-CRAN code is also affected but less reachable. It has been one day,
but I already received email asking for help on one such package.

We also now a good handful of packages implementing a 'graphics device' need to honour the API code
for the graphics engine. It moved from 16 to 17 so these need help.

If I had to guess now as this endeavour starts, I'd venture we probably need to update several dozen
packages.  Which would be manageable, and quicker than rebuilding all, or all 5100.

### So What Now?

I am trying to collect best practices here for addressing this at scale and reliably. I have to do
for my machines, but also for the set of 100k packages in
[r2u](https://github.com/eddelbuettel/r2u), and sort out with my fellow Debian developers what we do
inside the distro. I maintain that we can this efficiently and surgically. Other, such as my friend
[Iñaki](https://github.com/enchufa2) who looks after
[cran2copr](https://copr.fedorainfracloud.org/coprs/iucar/cran/) prefer to rebuild
everything. Again, different folks can come to different conclusions but I prefer _narrow_ and
_focussed_.

### Detecting Packages Needing a Rebuild

#### Binary API

One way is to use GitHub and to search the (inofficial) CRAN mirror as
[Jeroen](https://github.com/jeroen) (who looks after
[r-universe](https://r-universe.dev/search) and I discussed:

- [`#if R_VERSION >= R_Version(4, 6, 0)`](https://github.com/search?q=org%3Acran%20%22%23if%20R_VERSION%20%3E%3D%20R_Version(4%2C%206%2C%200)%22&type=code)  
  lidr, treesitter, rlang, vctrs, lobstr, lazyeval, nanoarrow, tidyCpp, qs2, igraph, QuickJSR, Rcpp,
  rlas, leidenAlg, collections, cpp11, archive, spaMM
  
- [`#if R_VERSION >= R_Version(4,6,0)`](https://github.com/search?q=org%3Acran+%22%23if+R_VERSION+%3E%3D+R_Version%284%2C6%2C0%29%22&type=code)  
  rJava, iotools
  
- [`#if R_VERSION < R_Version(4,6,0)`](https://github.com/search?q=org%3Acran+%22%23if+R_VERSION+%3C+R_Version%284%2C6%2C0%29%22&type=code)  
  RApiDatetime, Rcpp, RProtoBuf, 

- [`#if R_VERSION < R_Version(4, 6, 0)`](https://github.com/search?q=org%3Acran+%22%23if+R_VERSION+%3C+R_Version%284%2C+6%2C+0%29%22&type=code)  
  sparsevctrs, data.table, vroom, arrow, lidR, checkmate, box, vetr, renv, tkrplot, treesitter
  
(Note that I removed double-counts here.)  That is a conservative guess. E.g. on my machine I can
load e.g. `arrow` and `archive` just fine but e.g. `lidR` fails.

Another way is to ... actually load each package.  A simple enough shell script loop is

```sh
#!/bin/bash

cd /usr/local/lib/R/site-library

(for d in $(ls -1d *);do
    if test -f ${d}/libs/${d}.so; then
        r -e "cat(\"${d}: \"); suppressMessages(library(${d})); cat(\"Good\n\")"
    fi
done) 2>&1 | grep 'undefined symbol'
```

Of course, this also finds old packages one may have installed that are no longer on CRAN
(e.g. `pryr` for me) or packages that never were on CRAN one may have installed.

I plan to run something like the above over the ~ 1200 packages inside Debian.

#### GraphicsEngine

This aspect we realized earlier and already did partial rebuilds inside Debian. It is also easier to
find package using the one (exported, public) accessor from a public header:

- [`R_GE_checkVersionOrDie`](https://github.com/search?q=org%3Acran+R_GE_checkVersionOrDie&type=code)  
  devoid, unigd, Cairo, RSVGTipsDevice, ragg, rscproxy, svglite, RSvgDevice, tikzDevice, vdiffr,
  ggiraph, devEMF, qtutils, cairoDevice, R2SWF, magick, rvg, JuniperKernel

### Who Do You Care ?

I have been looking after Debian's R package since the late 1990s, maintaining a large number of
CRAN packages inside Debian, am a co-creator of the Rocker project where I look after a number of
R-based container, and of late have been building r2u with its Ubuntu CRAN binaries.

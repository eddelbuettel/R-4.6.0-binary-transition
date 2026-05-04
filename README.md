
## R 4.6.0 binary transition

TL,DR: Jump to [Results !!][results] or [Outcome][outcome]

### What is the Context

R 4.6.0 was released on April 24, 2026. It brought changes to the header files which impact the
run-time of installed and pre-made packages.

Why you ask? Well, the R Core team has for decades shipped R with C language headers containing
(some) functions and variables it considered private (among many other public ones). Consider it a
'global marshmallow test': "We told you all not to eat these."  Some people, myself included,
consider _each published API header_ a 'contract' and view shipping it as both an implicit contract
to not alter these headers with an honour code to provide backwards compatibility. R, once again, is
different. (To be plain, I understand where they are coming from, I disagree about releasing this
way.)

There is no point now debating this _ad nauseam_. Many of us tried to prevent this, but the release
was made the way it was. Going forward, we will have a cleaner understanding (and improved
separation) of _public_ installed header and _private_ compile-time only source headers which is
nice and helpful. But we also have some obvious breakage now. Which is not nice.  

### So What Happens ?

Consider this simple illustration of R 4.6.0 in the updated r-base container.  After install
`data.table` or `rlang` as a binary, it fails to load:

```
root@e47199f8b6fd:/# Rscript -e 'library(rlang)'
Error: package or namespace load failed for ‘rlang’ in dyn.load(file, DLLpath=DLLpath, ...):
 unable to load shared object '/usr/lib/R/site-library/rlang/libs/rlang.so':
  /usr/lib/R/site-library/rlang/libs/rlang.so: undefined symbol: SETLENGTH
Execution halted
root@e47199f8b6fd:/# 
```

The same thing happens on every installation containing locally compiled packages touching removed
symbols or functions. I upgraded to R 4.6.0 on my Ubuntu machine, and packages like `data.table` or
`RSQLite` (because of `rlang`) no longer loaded (so e.g. [CRANberries][cranberries] was briefly out
of sorts).  A quick local compilation helped.

### How Big A Deal ?

CRAN currently has about 5100 compiled packages among 23000 packages. We know the nearly 18000
R-only packages are not affected. For the 5100 others we need a search tool. This repo tries to work
towards this.  Of course, non-CRAN code is also affected but less reachable. It has been one day,
but I already received email asking for help on one such package.

We also now have a good handful of packages implementing a 'graphics device' needing to honour the
API code for the graphics engine. That code moved from 16 to 17 so these need help.

If I had to guess now as this endeavour starts, I'd venture we probably need to update several dozen
packages.  Which would be manageable, and quicker than rebuilding all, or all 5100, or even blindly
all 23000.  The change impacts a small, but widely used, subset. By updating the small subset
_quickly_ we can hopefully minimize overall pain.

### So What Now ?

I am trying to collect best practices here for addressing this at scale and reliably. I have to do
this for my machines, but also for the set of 100k packages in [r2u][r2u], and sort out with my
fellow Debian developers what we do inside the distro. I maintain that we can do this efficiently
and surgically. Others, such as my friend [Iñaki][inaki] who looks after [cran2copr][cran2copr]
prefers to rebuild everything. Again, different folks can come to different conclusions, but I prefer
_narrow_ and _focussed_ approaches.

### Detecting Packages Needing a Rebuild

#### Binary API

One way is to use GitHub and to search the (unofficial) CRAN mirror as [Jeroen][jeroen] (who looks
after [r-universe][r-universe]) and I discussed:

- [`#if R_VERSION >= R_Version(4, 6, 0)`](https://github.com/search?q=org%3Acran%20%22%23if%20R_VERSION%20%3E%3D%20R_Version(4%2C%206%2C%200)%22&type=code)  
  lidR, treesitter, rlang, vctrs, lobstr, lazyeval, nanoarrow, tidyCpp, qs2, igraph, QuickJSR, Rcpp,
  rlas, leidenAlg, collections, cpp11, archive, spaMM
  
- [`#if R_VERSION >= R_Version(4,6,0)`](https://github.com/search?q=org%3Acran+%22%23if+R_VERSION+%3E%3D+R_Version%284%2C6%2C0%29%22&type=code)  
  rJava, iotools
  
- [`#if R_VERSION < R_Version(4,6,0)`](https://github.com/search?q=org%3Acran+%22%23if+R_VERSION+%3C+R_Version%284%2C6%2C0%29%22&type=code)  
  RApiDatetime, RProtoBuf, 

- [`#if R_VERSION < R_Version(4, 6, 0)`](https://github.com/search?q=org%3Acran+%22%23if+R_VERSION+%3C+R_Version%284%2C+6%2C+0%29%22&type=code)  
  sparsevctrs, data.table, vroom, arrow, checkmate, box, vetr, renv, tkrplot
  
(Note that I removed double-counts here.)  That is a conservative guess; e.g. on my machine I can
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

I plan to run something like the above over the ~ 1200 packages inside Debian. [Edit: Now done, see
below in [Results !!][results].]

#### GraphicsEngine

This aspect we realized earlier and already did partial rebuilds inside Debian. It is also easier to
find packages using the one (exported, public) accessor from a public header:

- [`R_GE_checkVersionOrDie`](https://github.com/search?q=org%3Acran+R_GE_checkVersionOrDie&type=code)  
  devoid, unigd, Cairo, ragg, svglite, tikzDevice, vdiffr, ggiraph, devEMF, magick, rvg

plus 'false positives' packages RSVGTipsDevice, rscproxy, RSvgDevice, qtutils, cairoDevice, R2SWF,
JuniperKernel which match the condition but are no longer on CRAN.


### Results !!

I used containers for, respectively, Ubuntu 26.04 and Debian. The containers `rocker/r2u:26.04` as
well as `rocker/r-base` (aka the official `r-base`) work well for this. I used what is in the
snippet files [code.R](code.R) and [code.sh](code.sh) in two interactive sessions. I started from
the list of packages indicated above and then added column by column to the file
[packages.csv](packages.csv). And it was good: for Debian, and relying on `unstable` we are in
better shape than I thought. `rlang` and `data.table` are already rebuilt (given that we had weekly
release 'alpha', 'beta' and 'rc' of 4.6.0 in unstable, recent builds are ok). Per this analysis, in
Debian we may only need to rebuild package `lobstr` aka `r-cran-lobstr`.  For r2u I have more work
to do but will get to it as well.

#### Result for Debian 'unstable'

```r
> pkgs[Debian==TRUE & Loads_Unstable==FALSE,Package]
[1] "lobstr"
> 
```

#### Results for Ubuntu 26.04 with `r2u`

```r
> pkgs[Loads_26.04==FALSE, Package]   # Ubuntu via r2u
 [1] "lidR"        "treesitter"  "rlang"       "vctrs"       "lobstr"      "lazyeval"   
 [7] "igraph"      "leidenAlg"   "archive"     "sparsevctrs" "vroom"       "arrow"      
[13] "box"        
> 
```

Note that this set gets shorter once we update `rlang` as several packages
then load.

#### Results Table

| Package      | Version   | Loads_26.04 | Debian | Unstable_Version | Loads_Unstable |
|--------------|-----------|-------------|--------|------------------|----------------|
| lidR         | 4.3.2     | FALSE       | FALSE  |                  | NA             |
| treesitter   | 0.3.2     | FALSE       | FALSE  |                  | NA             |
| rlang        | 1.2.0     | FALSE       | TRUE   | 1.2.0-2          | TRUE           |
| vctrs        | 0.7.3     | FALSE       | TRUE   | 0.7.3-1          | TRUE           |
| lobstr       | 1.2.1     | FALSE       | TRUE   | 1.2.0-1          | FALSE          |
| lazyeval     | 0.2.3     | FALSE       | TRUE   | 0.2.2-2          | TRUE           |
| nanoarrow    | 0.8.0     | TRUE        | TRUE   | 0.8.0-1          | TRUE           |
| tidyCpp      | 0.0.11    | TRUE        | FALSE  |                  | NA             |
| qs2          | 0.2.0     | TRUE        | FALSE  |                  | NA             |
| igraph       | 2.3.0     | FALSE       | TRUE   | 2.2.3-1          | TRUE           |
| QuickJSR     | 1.9.2     | TRUE        | TRUE   | 1.9.0-1          | TRUE           |
| Rcpp         | 1.1.1-1.1 | TRUE        | TRUE   | 1.1.1-1.1-1      | TRUE           |
| rlas         | 1.8.6     | TRUE        | FALSE  |                  | NA             |
| leidenAlg    | 1.1.7     | FALSE       | FALSE  |                  | NA             |
| collections  | 0.3.12    | TRUE        | FALSE  |                  | NA             |
| cpp11        | 0.5.4     | TRUE        | TRUE   | 0.5.4-2          | TRUE           |
| archive      | 1.1.13    | FALSE       | FALSE  |                  | NA             |
| spaMM        | 4.6.65    | TRUE        | FALSE  |                  | NA             |
| rJava        | 1.0-18    | TRUE        | TRUE   | 1.0-18-1         | TRUE           |
| iotools      | 0.4-0     | TRUE        | FALSE  |                  | NA             |
| RApiDatetime | 0.0.11    | TRUE        | FALSE  |                  | NA             |
| RProtoBuf    | 0.4.26    | TRUE        | TRUE   | 0.4.25-1         | TRUE           |
| sparsevctrs  | 0.3.6     | FALSE       | TRUE   | 0.3.6-1          | TRUE           |
| data.table   | 1.18.2.1  | TRUE        | TRUE   | 1.18.2.1+dfsg-3  | TRUE           |
| vroom        | 1.7.1     | FALSE       | TRUE   | 1.7.1-1          | TRUE           |
| arrow        | 23.0.1.2  | FALSE       | TRUE   | 23.0.1-11        | TRUE           |
| checkmate    | 2.3.4     | TRUE        | TRUE   | 2.3.4-1          | TRUE           |
| box          | 1.2.2     | FALSE       | FALSE  |                  | NA             |
| vetr         | 0.2.21    | TRUE        | FALSE  |                  | NA             |
| renv         | 1.2.2     | TRUE        | TRUE   | 1.2.2-1          | TRUE           |
| tkrplot      | 0.0-32    | TRUE        | TRUE   | 0.0.32-1         | TRUE           | 

NB: This omits two columns for space reasons. See the [full csv](packages.csv) for all data. 
The entry for box is a false positive as it errors on load by its choice.

#### Outcome

Based on the analysis presented above, we successfully accommodated the R 4.6.0 requirement by
explicitly rebuilding packages

    data.table box rlang vctrs lobstr lazyeval treesitter lidR vroom
    
as well as the (active) packages with a graphis engine check

    devoid unigd Cairo ragg svglite tikzDevice vdiffr ggiraph devEMF magick rvg

Following a bug report, we also updated package 

    this.path 
   
which used a local wrapper for the version comparison escaping our initial filter.  When building
package we also noticed packages

    tidygraph tweenr
   
referencing a removed symbol and hence requiring a rebuild.

Given the DDOS attach on Ubuntu and Launchpad, we had to place 'jammy' binaries (for now) in a
(temporary) [release in this repo][jammy_adhoc_release]. This allowed us to complete container
builds and all three supported LTS release in r2u now cover R 4.6.0.
   
This completes the transition. There may still be a package or two or two coming up as needed a
rebuild, which we will do as needed. But by and large, a narrower and focussed upgrade is possible,
and has been undertaken. 

#### Debian Bulk Check

We use an [additional script](debian_bulk_check.R) to 'bulk check' all `r-cran-*` package in Debian
that contain compiled code. The reasoning is that non-binary packages cannot be affected by the
header change, only binary ones can.

We left some comments in the file that should explain the code. In brief we find that Debian
(currently) has 591 non-binary packages (that we ignore per the previous paragraph) and 519 binary
package. So in a loop we install all 519 first, and then in a second loop check each for whether it
'loads' into an R session. A shared library with missing symbols (as in the `lobstr` example) will
fail this immediately.

We find seven out of 519 packages failing. The following table contains them.

| Package    | Version | NeedsCompilation | lcpkg             | loads |
|------------|---------|------------------|-------------------|-------|
| gstat      | 2.1-6   | yes              | r-cran-gstat      | FALSE |
| lobstr     | 1.2.1   | yes              | r-cran-lobstr     | FALSE |
| reticulate | 1.46.0  | yes              | r-cran-reticulate | FALSE |
| Rmpi       | 0.7-3.4 | yes              | r-cran-rmpi       | FALSE |
| RQuantLib  | 0.4.26  | yes              | r-cran-rquantlib  | FALSE |
| Rsymphony  | 0.1-33  | yes              | r-cran-rsymphony  | FALSE |
| Seurat     | 5.5.0   | yes              | r-cran-seurat     | FALSE | 

(Rmpi is my package, the failure may be unrelated. Ditto for RQuantLib.)

Updates: RQuantLib has now been rebuilt against the current libquantlib and works as expected; this
was unrelated to R. Bug reports asking for updates/rebuilds of `lobstr` and `reticulate` have been
filed.

### Who Do You Care ?

I have been looking after Debian's R package since the late 1990s, maintaining a large number of
CRAN packages inside Debian, am a co-creator of the Rocker project where I look after a number of
R-based containers, and of late have been building r2u with its Ubuntu CRAN binaries.

[results]: https://github.com/eddelbuettel/R-4.6.0-binary-transition/tree/master#results-
[outcome]: https://github.com/eddelbuettel/R-4.6.0-binary-transition/tree/master#outcome
[cranberries]: https://dirk.eddelbuettel.com/cranberries/
[r2u]: https://github.com/eddelbuettel/r2u
[inaki]: https://github.com/enchufa2
[cran2copr]: https://copr.fedorainfracloud.org/coprs/iucar/cran/
[jeroen]: https://github.com/jeroen
[r-universe]: https://r-universe.dev/search
[jammy_adhoc_release]: https://github.com/eddelbuettel/R-4.6.0-binary-transition/releases/tag/4.6.0-2.2204.0

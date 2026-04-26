
library(data.table)
if (dir.exists("~/git/r-4.6.0-binary-transition/")) setwd("~/git/r-4.6.0-binary-transition/")

## packages.csv is the list of package names in the README
pkgs <- fread("packages.csv")
AP <- data.table(available.packages())
p <- AP[pkgs, on="Package"]
p[, .(Package, Version)]
fwrite(p[, .(Package, Version)], "packages.csv")


## switch to code.sh and install some packages, then
pkgs <- fread("packages.csv")
pkgs[, Binary := paste0("r-cran-", tolower(Package)), by="Package"]
pkpg[, Loads_26.04 := suppressMessages(require(Package, character.only=TRUE, quietly=TRUE)), by="Package"]

fwrite(pkgs, "packages.csv")

## after installation of rlang, packages igraph and sparsevtrs load
## after installation of vctrs, packages leidenAlg, archive and arrow also load


library(data.table)
if (dir.exists("~/git/r-4.6.0-binary-transition/")) setwd("~/git/r-4.6.0-binary-transition/")

## packages.csv is the list of package names in the README
pkgs <- fread("packages.csv")
AP <- data.table(available.packages())
p <- AP[pkgs, on="Package"]
p[, .(Package, Version)]
fwrite(p[, .(Package, Version)], "packages.csv")



## switch to code.sh and install some packages in Ubuntu 26.04, then
pkgs <- fread("packages.csv")
pkgs[, Binary := paste0("r-cran-", tolower(Package)), by="Package"]
pkpg[, Loads_26.04 := suppressMessages(require(Package, character.only=TRUE, quietly=TRUE)), by="Package"]

fwrite(pkgs, "packages.csv")

## after installation of rlang, packages igraph and sparsevtrs load
## after installation of vctrs, packages leidenAlg, archive and arrow also load



## now same in Debian unstable
## binary r-cran-data.table in unstable already works: 'apt install -t unstable r-cran-data.table'
library("data.table")
pkgs <- fread("packages.csv")

## determine which packages are in Debian, and get their versions
pkgs[, Debian := system(paste("apt-cache show", Binary), intern=FALSE, ignore.stderr=TRUE, ignore.stdout=TRUE) == 0, by=Binary]
pkgs[Debian == TRUE, Unstable_Version := as.character(system(paste("apt-cache show", Binary, "| awk '/Version/ {print $2}' | head -1"), intern=TRUE)), by=Binary]

## install them
ign <- pkgs[Debian == TRUE, system(paste("apt-get -y -t unstable --no-install-recommends install", Binary)), by=Binary]
## and try loading
pkps[Debian == TRUE, Loads_Unstable := suppressMessages(require(Package, character.only=TRUE, quietly=TRUE)), by="Package"]

fwrite(pkgs, "packages.csv")

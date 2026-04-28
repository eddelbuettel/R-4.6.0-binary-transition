#!/usr/bin/Rscript

options(width=200)                       # wider display
suppressMessages(library(data.table))    # our preferred data wranger: r-cran-data.table

ap <- data.table(available.packages())   # leaves out BioConductor which will get updated soon anyway

# create the Debian package name for each CRAN package name
ap[, lcpkg := paste0("r-cran-", tolower(Package))]

# find all Debian packages matching r-cran-*
deb <- data.table(lcpkg=system("apt-cache search '^r-' | sort | uniq | awk '/^r-cran-/ {print $1}'", intern=TRUE))

# merge on lcpkg (i.e. Debian package name), keep columns package, version, binary or not, debian name
p <- ap[deb, on="lcpkg"][,.(Package,Version,NeedsCompilation,lcpkg)]
# tabulate:  591 non-binary packages, 519 binary packages
table(p[,NeedsCompilation])

# this needs to run just once per (virtual machine or container) session and take a moment
if (FALSE)
    for (p in p[NeedsCompilation=="yes", lcpkg])
        system(paste("apt-get install -t unstable --yes --no-install-recommends", p, "2>&1 >/dev/null"))

# now loop over all packages and check if they can be attached to an R session
p[NeedsCompilation=="yes", loads := suppressMessages(requireNamespace(Package, quietly=TRUE)), by = Package]

# show the ones that do not
p[NeedsCompilation=="yes" & loads==FALSE]

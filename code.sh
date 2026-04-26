## in r2u container for 26.04, git repo mounted as /work

apt update -qq
apt upgrade -y
apt install wget

cd /tmp
wget 'https://launchpad.net/~edd/+archive/ubuntu/misc/+files/r-base-core_4.6.0-0.2604.2_amd64.deb'
apt install ./r-base-core_4.6.0-0.2604.2_amd64.deb

## now e.g. the already install r-cran-data.table no longer loads so quicj rebuild
Rscript -e 'bspm::disable(); install.packages("data.table")'

## read csv file and install all the packages (as binaries via bspm using r2u)
cd /work
## this runs into the SSL handshake error
#Rscript -e 'p <- data.table::fread("packages.csv"); install.packages(p[, Package])'
## so for once doing it in bits
Rscript -e 'p <- data.table::fread("packages.csv"); for (p in p[,Package]) install.packages(p)'


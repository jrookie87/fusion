# COVID-19 Canada Open Data Working Group Official Dataset Download and Compatibility Script #
# Author: Jean-Paul R. Soucy #

# Download official COVID-19 datasets and convert them to a compatible format.
# This will allow these datasets to be used as drop-in replacements
# for portions of COVID-19 Canada Open Data Working Group dataset.

# Note: This script assumes the working directory is set to the root directory of the project
# This is most easily achieved by using the provided Covid19Canada.Rproj in RStudio

# Authentication: You must authenticate your Google account before running the rest of the script.
# This is performed in the conductor.R script. See details there.

# load libraries
library(dplyr) # data manipulation
library(tidyr) # data manipulation
library(lubridate) # better dates
# devtools::install_github("jeanpaulrsoucy/Covid19CanadaData")
library(Covid19CanadaData) # load official datasets

# load functions
source("scripts/update_data_funs.R")
source("scripts/update_official_data_funs.R")

# list files in Google Drive data folder
files <- drive_ls("ccodwg/data")

# official PHAC testing (n_tests_completed) province-level dataset
tryCatch(
  convert_phac_testing_prov(),
  error = function(e) {print(e); cat("Error: convert_phac_testing_prov()", fill = TRUE)}
)

# official Quebec dataset (incomplete, testing only)
tryCatch(
  convert_official_qc(),
  error = function(e) {print(e); cat("Error: convert_official_qc()", fill = TRUE)}
)

# NT sub health-region cases and active cases
tryCatch(
  update_nt_subhr(date_today),
  error = function(e) {print(e); cat("Error: update_nt_subhr()", fill = TRUE)}
)

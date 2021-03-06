# Orchestrate the nightly COVID-19 Canada Open Data Working Group data update #
# Author: Jean-Paul R. Soucy #

# Note: This script assumes the working directory is set to the root directory of the project
# This is most easily achieved by using the provided Covid19Canada.Rproj in RStudio

# Authentication: You must authenticate your Google account before running the rest of the script.
# You may be asked to give "Tidyverse API Packages" read/write access to your Google account.
# All the scripts called by this script assume authentication has been already performed.

# get CCODWG_STATUS environmental variable, if set
# if status == "NO_UPDATE", the data update will be validated but not pushed to GitHub
status <- Sys.getenv("CCODWG_STATUS")
if (status == "NO_UPDATE") {
  cat("CCODWG_STATUS is set to NO_UPDATE. Beginning script...", fill = TRUE)
}

# authenticate your Google account before running the rest of the script
library(googledrive) # interface with Google Drive
library(googlesheets4) # read from Google Sheets
if (!gs4_has_token()) {
  if (file.exists("/secrets.json")) {
    # use service account key, if it exists
    drive_auth(path = "/secrets.json")
    gs4_auth(path = "/secrets.json")
  } else {
    # otherwise, prompt for authentication
    drive_auth()
    gs4_auth()
  }
}

# load libraries
library(lubridate) # better dates
library(dplyr) # data manipulation
library(stringr) # manipulate strings
library(lubridate) # better dates
library(compareDF) # compare data frames
library(pander) # output markdown tables
library(crayon) # colourful output in console

# load functions
source("scripts/conductor_update_nightly_funs.R")

# get today's date
date_today <- as.character(date(get_time_et()))

# update data
source("scripts/update_data.R")

# update official data
# don't run if status == "NO_UPDATE"
if (status == "NO_UPDATE") {
  cat("CCODWG_STATUS is set to NO_UPDATE. Skipping update of official datasets...", fill = TRUE)
} else {
  source("scripts/update_official_data.R")
}

# validate data update
update_data_validation()

# email validation results (if GITHUB_PAT environmental variable is set)
results <- paste(capture.output(update_data_validation()), collapse = "\n")
Covid19CanadaETL::send_email(subject = "CCODWG Update: Validation Results", body = results)
Covid19CanadaETL::pushover(message = "Summary of data update is ready for review.", title = "CCODWG Update: Validation Results", priority = "1")

# push update to GitHub and mirror to Google Drive (at 22:00 ET)
# don't run if status == "NO_UPDATE"
if (status == "NO_UPDATE") {
  cat("CCODWG_STATUS is set to NO_UPDATE. Exiting script without pushing data update...", fill = TRUE)
} else {
  run_at(paste(date_today, "22:00:00"), {
    
    # retrieve value for "run_automatically"
    while(!exists("f")) f <- drive_ls("ccodwg/data")
    f <- f[f$name == "covid19", ]
    while(!exists("run_automatically")) {
      run_automatically <- range_read(
        f,
        sheet = "run_automatically",
        range = "A6",
        col_names = "run_automatically"
      )
    }
    run_automatically <- run_automatically[1, 1, drop = TRUE]
    
    # rerun update code before pushing update if run_automatically == REFRESH
    if (run_automatically == "REFRESH") {
      # report refresh
      cat("Refreshing data prior to data push...", fill = TRUE)
      # update data
      source("scripts/update_data.R")
      # update official data
      source("scripts/update_official_data.R")
      # validate data update
      update_data_validation()
    } else if (!isTRUE(run_automatically)) {
      # stop script if run_automatically is not TRUE
      stop("run_automatically is not TRUE. Stopping update. Please complete manually.")
    }
    
    # push update
    source("scripts/github_update.R")
    
    # send notification (if GITHUB_PAT environmental variable is set)
    Covid19CanadaETL::pushover(message = "Operation successful.", priority = 1, title = "CCODWG Update: Pushed to GitHub")
    
    # wait 15 seconds
    Sys.sleep(15)
    
    # sync updated files to Google Drive
    source("scripts/mirror_to_gdrive.R")
    
    # send notification (if GITHUB_PAT environmental variable is set)
    Covid19CanadaETL::pushover(message = "Operation successful.", priority = 1, title = "CCODWG Update: Synced with Google Drive")
    
  })
}

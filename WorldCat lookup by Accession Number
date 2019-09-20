# This returns a count of WorldCat holdings (total and in-state). It searches by Accession Number.
# While searching by ISBN would return more holdings, it may return holdings for an ebook record, which is not what we want.
# The Accession Numbers come from our catalog, so we assume they are the records with the largest number of holdings.

library(httr)
library(jsonlite)
library(tidyverse)
options(stringsAsFactors = FALSE, timeout=40000, scipen = 999)

# Read the list of damaged books
damaged <- read.csv("./Monographs/Damaged/Damaged books 3-13.csv")
oclc.raw <- damaged$Local.Param.01

#clean up list
oclc.num <- parse_number(oclc.raw)
oclc.num <- unique(oclc.num)

#Set up the path and URL
WorldCat_key <- "[key redacted]"
URL_WorldCat <- "http://worldcat.org/"
path_ocn <- "webservices/catalog/content/libraries/"

#set up the objects that will store the data
holdings <- data.frame("","","")
names(holdings) <- c("OCLC Number","PA Holdings","Total WorldCat Holdings")

#loop through all OCLC Numbers
for(j in 1:length(oclc.num)) {
  ocn <- oclc.num[j]
  url_ocn <- paste(URL_WorldCat,path_ocn,ocn,sep='')
  
#PA Holdings
  results.pa <- GET(url_ocn, query=list(wskey=WorldCat_key,format="json",location="PA", frbrGrouping="off", maximumLibraries=100,servicelevel="full"))
  content.pa <- content(results.pa)
  pa.json <- fromJSON(content.pa)

if (length(pa.json$totalLibCount)>0) {  
  
holdings[nrow(holdings)+1, ]  <- list(ocn,length(pa.json$library$oclcSymbol),pa.json$totalLibCount)
    
}

  message(".", appendLF = FALSE)
  Sys.sleep(time = 1)
}

write.csv(holdings,"./Monographs/Damaged/Damaged books holdings 3-13.csv")

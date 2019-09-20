# This query is in R script. It is designed to take a list of ISBNs from a csv file and query a library's catalog to see what holdings exist.
# The query contains some filters specific to Temple University Libraries.

library(httr)
library(jsonlite)
library(dplyr)
options(scipen=999,stringsAsFactors = FALSE)

#Key and Base URL
Alma_key <- "[key redacted]"
base_URL_Alma <- "https://api-na.hosted.exlibrisgroup.com/"

#Read the file.
#This code includes no clean-up of the ISBNs. All ISBNs should be in single column with no dashes.
title_list <- read.csv(".\\APIs\\ISBNs for Alma test.csv")
ISBN.list <- title_list$EAN.13

#Path for Primo and Alma APIs
path_Primo <- "primo/v1/pnxs"
path_Alma <- "almaws/v1/bibs/"

#Create empty data frame that will store MMS IDs with corresponding ISBNs.
MMS.ISBN <- data.frame(stringsAsFactors = FALSE,"","","")
names(MMS.ISBN) <- c("MMS","ISBN","Library")

for (j in 1:length(ISBN.list)) {
  ISBN <- ISBN.list[j]
  full_URL_Primo <- paste(base_URL_Alma,path_Primo,"?","q=any,contains,",ISBN,sep='')
  Primo_query <- GET(full_URL_Primo,query=list(apikey=Alma_key,format="json",view="full"))
  if (Primo_query$status_code==200) {
    p.query.content <- content(Primo_query)
    if (length(p.query.content$docs) > 0) {
        MMS.id <- p.query.content$docs[[1]]$addsrcrecordid
        
      if(length(p.query.content$docs[[1]]$delivery$holding) > 0)  {
      for (k in 1:length(p.query.content$docs[[1]]$delivery$holding))  {
        
        lib.name <- p.query.content$docs[[1]]$delivery$holding[[k]]$mainLocation
        MMS.ISBN[nrow(MMS.ISBN)+1,] <- list(as.character(MMS.id),as.character(ISBN),lib.name)
      }
      } #end if holdings
        else if (length(p.query.content$docs[[1]]$delivery$bestlocation)>0)   {
          lib.name <- p.query.content$docs[[1]]$delivery$bestlocation$mainLocation
          MMS.ISBN[nrow(MMS.ISBN)+1,] <- list(as.character(MMS.id),as.character(ISBN),lib.name)
        }
    
      message(".", appendLF = FALSE)
      Sys.sleep(time = 1)
    } #end if docs
  } # end if status=200
}  #end loop through ISBN list

#Filter to Main Libraries, then select just one instance of each MMS ID.
mainlibs <- c("MAIN","AMBLER","KARDON","ASRS","RES_SHARE")
MMS.main <- MMS.ISBN[which(MMS.ISBN$Library %in% mainlibs),]
MMS.main <- MMS.main %>% distinct(MMS.main$MMS,MMS.main$ISBN,.keep_all = TRUE) %>% select(1:3)

# I don't know how to get this to display the permanent location instead of the current (possibly temporary) one
# So I just included the Resource Sharing location in this list.
# The next query, of Alma, will display the permanent location.

#create the object for storing physical holdings
phys.holdings <- data.frame(stringsAsFactors = FALSE,"","","","","","","","")
names(phys.holdings) <- c("ISBN","MMSID","Item ID","Location","Library","Process Type","Call Number","Description")

# loop through all MMS ids for Physical Items

for (r in 1:length(MMS.main$MMS)) {
  MMSid <- MMS.main$MMS[[r]]
  
  URL_Alma_holdings <- paste(base_URL_Alma,path_Alma,MMSid,"/holdings/ALL/items",sep='')
  Alma_query <- GET(URL_Alma_holdings,query=list(apikey=Alma_key,format="json",limit=100))
  query_content <- content(Alma_query)
  item.isbn <- MMS.main$ISBN[[r]]
  #loop to check all items for this MMSid
  for (m in 1:length(query_content$item)) {
    
    itemid <- query_content$item[[m]]$item_data$pid
    descr <- query_content$item[[m]]$item_data$description
    
    if (length(query_content$item[[m]]$item_data$library) > 0) {
      location <- query_content$item[[m]]$item_data$location$desc
      hold_library <- query_content$item[[m]]$item_data$library$desc
      if (length(process_type <- query_content$item[[m]]$item_data$process_type$desc) >0) {
        process_type <- query_content$item[[m]]$item_data$process_type$desc
      }
      else { 
        process_type <- "none"
      } 
      if (length(query_content$item[[m]]$holding_data$call_number >0)) {
        call_no <- query_content$item[[m]]$holding_data$call_number 
      }
      else {
        call_no <- "not given"
      } 
      
      phys.holdings[nrow(phys.holdings)+1, ] = list(item.isbn,as.character(MMSid),as.character(itemid),location,hold_library,process_type,call_no,descr)
      
    }
  }
  
  message(".", appendLF = FALSE)
  Sys.sleep(time = 1)
}

#filters
phys.holdings.filtered <- phys.holdings[which(phys.holdings$`Process Type`!="Missing"),]
phys.holdings.filtered <- phys.holdings.filtered[which(phys.holdings.filtered$`Process Type`!="Lost"),]
maincoll <- c("Charles Library","Ambler Campus Library","Remote Storage","ASRS")
phys.holdings.filtered <- phys.holdings.filtered[which(phys.holdings.filtered$Library %in% maincoll),]

#Remember to look at the Description column to check if the volume we have is the one you are trying to match

write.csv(phys.holdings.filtered,file=".//APIs/output of test.csv")

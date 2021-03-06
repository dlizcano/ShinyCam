###############################
# animal_count.R
# Calculate the animal counts per project per deployment per month.
# It is suggested to run this for the entire dataset.
# EHF ADD MORE DESCRIPTION
# Output:
# 1. File containing the groupings
# 2. File containing the final counts
###############################
# Clear the environment and load libraries
rm(list = ls())
library(lubridate)
library(dplyr)
library(plyr)
###############################
# Set the path and workspace  to to main ShinyCam directory (i.e. the one that has README.md file, ShinyApps directory,etc)
shinycam_path <- "/Users/efegraus/Documents/GitHub/ShinyCam/"
prj_name<- "Papandayan" # No spaces in names
setwd(shinycam_path)
source("rscripts/RShiny_functions.R")
old <- Sys.time()
# Set the file name and path to your raw data files. This should be a file name that is in the correct format. See README process for explanation
#Load Data
#df_name <- "YOUR FILENAME HERE"
#Exmample
df_name <- "Papandayan_joined_data.csv" # 
# Set the path to your local camera trap data file in the raw_dataprep ditectory
# ct_data <- read.csv(paste("YOUR LOCALPATH TO THE REAW DATA FILE",df_name,sep=""))
# Example
ct_data <-read.csv(paste("ShinyApps/LeafletApp/data/raw_dataprep/",df_name, sep=""))
###############################

# Remove all images that we know don't have an animal
data_animals <- ct_data[which(ct_data$Photo.Type == "Animal"),]# | marin_data$Photo.Type == "Unknown" 
data_animals_2 <- filter(data_animals,Project.ID == "GaryGiacomini")

# Shrink data frame
# delete data_animals_2
data_new <- select(data_animals_2,Project.ID,Camera.Deployment.Begin.Date,Camera.Deployment.End.Date,Latitude.Resolution,Longitude.Resolution,Photo.Type,Image.ID,Genus.Species,Count,Deployment.Location.ID,Event,Date_Time.Captured)

data_new <- select(data_animals,Project.ID,Camera.Deployment.Begin.Date,Camera.Deployment.End.Date,Latitude.Resolution,Longitude.Resolution,Photo.Type,Image.ID,Genus.Species,Count,Deployment.Location.ID,Event,Date_Time.Captured)
# Create the groups 
data_order <-f.order.data(data_new)
data_order$Date_Time.Captured <-ymd_hms(data_order$Date_Time.Captured)
# Run through the events
event_runs<- c(120,3600,86400) # 3 million record dataset run times are: 120 ~4hrs, 3600 (30mins) ~47 mins, 1 day 86400 ~42 mins
for (m in 1:length(event_runs)) {
  events <- f.separate.events(data_order,event_runs[m]) 
  # EHF: Think next 4 lines below can be deleted. Test with Marin
  # Drop image.id column
  # events_no_image <- select(events,-Image.ID)
  # Remove Dups (Image ID oftern makes unique but removed above)
  # events_distinct <- distinct(marin_events_no_image)
  # Unique groups
  events_distinct <- events
  unique_grps <- unique(events_distinct$grp)
  # unique_grps <- unique(marin_events_distinct$grp)
  
  # output dataframe with same str as input
  output_df <- events_distinct[0,]
  # This loop may take awhile...6 hours or so for some Marin projects.
  for (i in 1:length(unique(unique_grps))) {
    temp <- events_distinct[which(events_distinct$grp == unique_grps[i]),]
    # Case 1: Only 1 record
    if (nrow(temp) == 1) {
      output_df <- rbind(output_df,temp)
      # More than 1 record but with same species and count
    } else if (length(unique(paste(temp$Genus.Species,temp$Count))) == 1) {
      output_df <- rbind(output_df,temp[1,]) # just get the first one as they are the same
      # More than 1 record but with same species and different count
    } else if (length(unique(paste(temp$Genus.Species,temp$Count))) > 1) { ## take largest count from 
      # Could have more than one species
      num_recs_want <- length(unique(paste(temp$Genus.Species,temp$Count)))
      temp2 <- distinct(temp,Genus.Species,Count,.keep_all = TRUE)
      if (nrow(temp2) != num_recs_want) {
        print(paste("ERROR"))
        break
      }
      output_df <-rbind(output_df,temp2)
    }
  }
  # Tag the datframe with the interval
  output_df$event_interval <- event_runs[m]
  output_df$prj_name <- prj_name
  new <- Sys.time() - old 
  print(paste("Time event group",event_runs[m],"secs took",new,"to run and is complete"))
  # Print out the events file and then the final_counts
  output_path <-paste(shinycam_path,"ShinyApps/LeafletApp/data/processed/",sep="")
  write.csv(output_df,file=paste(output_path,"data_event_",event_runs[m],"secs_",prj_name,".csv", sep=""))
  #Final Count
  output_df$Year <-year(output_df$Date_Time.Captured)
  output_df$Month <- month(output_df$Date_Time.Captured)
  # Calculate  summary information
  final_count <- ddply(output_df,.(prj_name,Project.ID,Latitude.Resolution,Longitude.Resolution,
                                   Event,Deployment.Location.ID,Month,Year,Genus.Species),summarize,total=max(Count))
  write.csv(final_count,file=paste(output_path,"final_count_",event_runs[m],"secs_",prj_name,".csv", sep=""))
}  

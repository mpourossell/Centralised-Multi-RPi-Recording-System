##> Process raw_data to create new csv files after:
##> - Correct timestamps
##> - Filter based on date (from X to Y)
##> - Filter based on sunrise and sunset times
##> - Filter the times from our visits in the tower
##> - Correct wrong detections:
##>   + Duration of detection. Interpolate missing detections, eliminate fake
##> - Add columns with information from location of the detection:
##>   + Incubating (binary, 0-1)
##>   + At the door (binary, 0-1)
##>   + Angle of bird when there is only 1 detection.

library(readr)
library(fs)
library(tidyr)
library(dplyr)
library(suncalc)
library(solartime)
library(tools)
source("G:/Mi unidad/Marçal's PhD/001_automated_jackdaw_monitoring/Test_dir/Z_scripts/functions_test.R")

# calculate_angle_vec <- Vectorize(calculate_angle)
# calculate_relative_angle_vec <- Vectorize(calculate_relative_angle)


setwd("G:/Mi unidad/Marçal's PhD/001_automated_jackdaw_monitoring/Z_scripts")

# Read raw_data csv files
datafiles <- list.files("../B_raw_data", pattern = "\\.csv$", full.names = TRUE)
datafiles <- lapply(datafiles, sort)
##> Read helper data: 
##> timestamps_OCR.csv to relate timestamps with the CSV where timestamp is NA
timestamps_complet <- read.csv("../B2_helper_data/timestamps_OCR.csv", colClasses="character")

##> idbox-rpi csv file to relate box with Rpi
box_rpi_csv <- read.csv("../B2_helper_data/box_rpi_2023.csv", colClasses="character")

##> fitness_data.csv to check relative dates to LD, HD.
fitness_data <- read.csv("../B2_helper_data/fitness_data.csv", sep = ";", colClasses="character")
fitness_data <- fitness_data %>% 
  mutate(obsLD = as.Date(obsLD, format = "%d/%m/%Y"),
         obsHD = as.Date(obsHD, format = "%d/%m/%Y"))

##> nest_positions.csv to identify location of the eggs and the entry in each box
nest_positions <- read.csv("../B2_helper_data/nest_positions.csv", colClasses="character")


##> Add a new column with the xy coordinates for the centre of the door. Then,
##> re-direct the angle of the cartasian system to the door centre. This way
##> we would know if bird is looking at the entry or not!

nest_positions <- nest_positions %>% 
  mutate(date_from = ifelse(nchar(date_from) > 6, 
                            as.POSIXct(date_from, format = "%y%m%d%H%M%S"), 
                            as.POSIXct(paste0(date_from, "000001"), format = "%y%m%d%H%M%S")
  )) %>% 
  mutate(date_to = ifelse(nchar(date_to) > 6, 
                          as.POSIXct(date_to, format = "%y%m%d%H%M%S"), 
                          as.POSIXct(paste0(date_to, "000001"), format = "%y%m%d%H%M%S")
  )) %>% 
  mutate(
    date_from = as.POSIXct(date_from, format = "%y%m%d%H%M%S"),
    date_to = as.POSIXct(date_to, format = "%y%m%d%H%M%S")
  ) %>% 
  mutate(nest_x_from = as.numeric(nest_x_from),
         nest_y_from = as.numeric(nest_y_from),
         nest_x_to = as.numeric(nest_x_to),
         nest_y_to = as.numeric(nest_y_to),
         door_x_from = as.numeric(door_x_from),
         door_y_from = as.numeric(door_y_from),
         door_x_to = as.numeric(door_x_to),
         door_y_to = as.numeric(door_y_to),
         img_w = as.numeric(img_w),
         img_h = as.numeric(img_h),
         door_x = as.numeric(door_x),
         door_y = as.numeric(door_y)
         )

#Normalize coordinates from the nest
nest_positions <- nest_positions %>% 
  mutate(nest_x_from = if_else(!is.na(nest_x_from) & !is.na(img_w), nest_x_from / img_w, NA_real_),
         nest_y_from = if_else(!is.na(nest_y_from) & !is.na(img_h), nest_y_from / img_h, NA_real_),
         nest_x_to = if_else(!is.na(nest_x_to) & !is.na(img_w), nest_x_to / img_w, NA_real_),
         nest_y_to = if_else(!is.na(nest_y_to) & !is.na(img_h), nest_y_to / img_h, NA_real_),
         door_x_from = if_else(!is.na(door_x_from) & !is.na(img_w), door_x_from / img_w, NA_real_),
         door_y_from = if_else(!is.na(door_y_from) & !is.na(img_h), door_y_from / img_h, NA_real_),
         door_x_to = if_else(!is.na(door_x_to) & !is.na(img_w), door_x_to / img_w, NA_real_),
         door_y_to = if_else(!is.na(door_y_to) & !is.na(img_h), door_y_to / img_h, NA_real_),
         door_x = if_else(!is.na(door_x) & !is.na(img_w), door_x / img_w, NA_real_),
         door_y = if_else(!is.na(door_y) & !is.na(img_h), door_y / img_h, NA_real_)
         )

# Define variables to cut data
from_date <- as.Date("230315", format = "%y%m%d") # Before 230318, videos that recorder 2 days maintained the first date after 00:00!
to_date <- as.Date("230715", format = "%y%m%d")

# Set location of the tower
latitude <- 41.525019
longitude <- 0.705792

# Main Loop to iterate through all files and process raw_data
for (datafile in datafiles) {
  # datafile <- "../B_raw_data/RG_230315_jackdaw6_5.csv"
  out_csv_path <- paste0("../C_processed_data/", file_path_sans_ext(basename(datafile)), "_processed.csv")
  
  if (file.exists(out_csv_path)) {
    cat("Skipping", basename(datafile), "as processed file already exists. \n")
    next
  }
  
  if (file.size(datafile) < 10000) {
    print(paste(datafile, "size is ", round(file.size(datafile)/1024, 2), "KB"))
    next
  }
  
  print(paste("Working with file ->", datafile))
  
  # Extract rpi and date from the filename
  video_id <- sub(".*/(.*)\\.csv$", "\\1", datafile)
  rpi_name <- strsplit(video_id, "_")[[1]][3]
  rpi_name <- format_rpi_id(rpi_name)
  date_str <- strsplit(video_id, "_")[[1]][2]
  date <- as.Date(date_str, format = "%y%m%d")
  
  # Filter by date
  if (from_date <= date & date <= to_date) {
    
    data <- read.csv(datafile, colClasses = c(timestamp = "character"))
    
    # Read timestamps correctly using timestamps_OCR.csv
    if (is.na(data$timestamp[1])) {
      print(paste("NA in timestamp:", data$timestamp[1]))
      
      timestamp_value <- timestamps_complet$timestamp[timestamps_complet$video == video_id][1]
      
      if (!is.na(timestamp_value)) {
        print(paste("New timestamp is:", timestamp_value))
        
        data$timestamp[1] <- timestamp_value
        # Check FPS of the current video
        # fps <- ifelse(10000 < as.integer(timestamp_value) & as.integer(timestamp_value < 53001), 1, 2)
        
        # Update the timestamp in the first row of mydata
        timestamp_value <- as.POSIXct(paste(date_str, timestamp_value), format = "%y%m%d %H%M%S")
        data[1,"complete_timestamp"] <- timestamp_value
        
        data <- data %>%
          group_by(frame) %>% 
          mutate(complete_timestamp = ifelse(frame == 1, 
                                             timestamp_value,
                                             timestamp_value + frame
                                             )) %>% 
          mutate(complete_timestamp = as.POSIXct(complete_timestamp)) %>% 
          ungroup() %>% 
          # mutate(complete_timestamp = timestamp_value + lubridate::seconds(frame - 1)) %>% 
          subset(select= -c(timestamp, fps_, real_time, class, video))
      } 
    } else {
      timestamp_value <- as.POSIXct(paste(date_str, data$timestamp[1]), format = "%y%m%d %H%M%S")
      data <- data %>%
        # mutate(complete_timestamp = as.POSIXct(paste(date_str, timestamp), format = "%y%m%d %H%M%S")) %>% 
        group_by(frame) %>% 
        mutate(complete_timestamp = ifelse(frame == 1, 
                                           timestamp_value,
                                           timestamp_value + frame
        )) %>% 
        mutate(complete_timestamp = as.POSIXct(complete_timestamp)) %>% 
        subset(select= -c(timestamp, fps_, real_time, class, video))
    }
    
    # Fix dates! Sometimes RPi was recording over midnight and date was maintained!
    if (min(as.Date(data$complete_timestamp)) == max(as.Date(data$complete_timestamp))) {
      data <- fix_date_jumps(data)
    }
    
    # Filter based on sunrise and sunset times
    # Get sunrise and sunset times for each date
    sunrise <- getSunlightTimes(date = date,
                               lat = latitude,
                               lon = longitude,
                               tz = "Europe/Madrid")[1,6]
    sunset <- getSunlightTimes(date = date,
                               lat = latitude,
                               lon = longitude,
                               tz = "Europe/Madrid")[1,7]
    
    data <- data %>% 
      filter(format(complete_timestamp, "%H:%M:%S") 
             >= format(sunrise, "%H:%M:%S") &
               format(complete_timestamp, "%H:%M:%S") <= 
               format(sunset, "%H:%M:%S"))
    
    if (nrow(data) != 0) {

      
      # Add dates relative to Recording, LD and HD
      idbox <- box_rpi_csv$idbox[box_rpi_csv$rpi == rpi_name][1]
      
      obsLD <- fitness_data$obsLD[fitness_data$idbox == idbox]
      obsHD <- fitness_data$obsHD[fitness_data$idbox == idbox]
      obsLD <- if (length(obsLD) > 1) obsLD[2] else obsLD
      obsHD <- if (length(obsHD) > 1) obsHD[2] else obsHD
      
      data <- data %>% 
        mutate(
          ld_date = as.numeric(difftime(as.Date(complete_timestamp), obsLD, units = "days")),
          hd_date = as.numeric(difftime(as.Date(complete_timestamp), obsHD, units = "days")),
          rec_date = as.numeric(difftime(as.Date(complete_timestamp), from_date, units = "days")) + 1
        )
      
      
      # Correct detections: 
      
      # Correct number of detections, filtering >2 num_detections based on 
      # confidence (keep higher ones) and track_id (keep lower ones)
      data_over2 <- data %>% 
        group_by(frame) %>% 
        filter(num_detections > 2) %>% 
        arrange(desc(confidence), track_id) %>% 
        slice_head(n = 2) %>% 
        mutate(num_detections = 2) %>% 
        ungroup()
      
      data_below2 <- data %>% 
        group_by(frame) %>%
        filter(num_detections <= 2 | !frame %in% data_over2$frame) %>%
        ungroup()
      
      data <- bind_rows(data_over2, data_below2) %>% 
        arrange(frame, track_id)
      
      rm(data_over2)
      rm(data_below2)

      {      
      # Interpolate missing detections (based on bbox coordinates)
      ##> for rows with unique "frame", if bbox coordinates are NA, check the last
      ##> time they were not NA and compare the coordinates with the ones from the next time
      ##> they are not NA. If they are similar, interpolate the ones in between if time difference 
      ##> is less than 5 seconds. 
# 
#       data_interpolated <- interpolate_missing_detections(data, 6)
#       
#       data_interpolated <- data_interpolated %>% 
#         arrange(frame, track_id) %>% 
#         group_by(frame) %>%
#         mutate(num_detections = ifelse(is.na(confidence), 0, n()))
#       
      # Re-calculate num_detections cleaning error detections in between two periods where num_detections was stable for at least 15 seconds. 
      ##> For a "inestable" period between two periods of stability, calculate the mean num_detections of all
      ##> inestable frames and recalculate the num_detections rounding that mean. 
      # Calculate periods of stable "num_detections" (>15 continuous frames), and unstable periods

      
    
      ##> Clean num_detections based on confidence and then replacing the "unstable"
      ##> periods for the mean(num_detections) in them. 
      
      # 
      # data_sum <- data %>% 
      #   mutate(conf = ifelse(!is.na(confidence),
      #                        ifelse(confidence >= 0.70, 
      #                               1, 
      #                               ifelse(y < 0.50, 1, 0)
      #                               ),
      #                        0)
      #          ) %>% 
      #   group_by(frame) %>% 
      #   mutate(confident_detections = sum(conf)) #%>% 
      #   
      #   summarize(confident_detections = first(confident_detections)) %>% 
      #   mutate(change = ifelse(confident_detections != lag(confident_detections, default = first(confident_detections)), 1, 0)) %>% 
      #   mutate(change_group = cumsum(change == 1)) %>% 
      #   group_by(change_group) %>% 
      #   mutate(frame_count = n()) %>% 
      #   ungroup() %>% 
      #   mutate(stable = ifelse(frame_count >= 20, TRUE, FALSE)) %>% 
      #   mutate(stable_period_id = cumsum(lag(stable, default = TRUE) != stable)) %>% 
      #   merge(data, by = "frame", all.x = TRUE) %>% 
      #   
      #   group_by(stable_period_id, track_id) %>% 
      #   mutate(valid_track_id = ifelse(confidence >= 0.8, 1, 0)) %>% 
      #   ungroup() %>% 
      #   group_by(stable_period_id) %>% 
      #   mutate(new_num_detections = ifelse(!is.na(track_id), length(unique(track_id[valid_track_id==1])), NA))
      #   mutate(new_confident_detections = ifelse(stable == FALSE, ceiling(mean(confident_detections)), confident_detections)) %>%
      # 
      #   merge(data, by = "frame", all.x = TRUE)
      #   # mutate(new_confident_detections = ifelse(stable == FALSE, mean(confident_detections), confident_detections))
      # 
      # merged_data <- left_join(data, data_sum)
      
      
  
      ##> Clean num_detections based on the track_id:
      ##> In the period of instability, check the track_id that's being lost.
      # data_sum <- data %>% 
      #   mutate(change = ifelse(frame != lag(frame) & num_detections != lag(num_detections, 
      #                          default = first(num_detections)), 
      #                          1,
      #                          ifelse(frame == lag(frame, default = first(frame)), NA, 0)
      #                          )
      #          ) %>% 
      #   mutate(change_group = cumsum(change == 1)) %>% 
      #   group_by(change_group) %>% 
      #   mutate(frame_count = n()) %>% 
      #   ungroup() %>% 
      #   mutate(stable = ifelse(frame_count >= 20, TRUE, FALSE)) %>% 
      #   mutate(stable_period_id = cumsum(lag(stable, default = TRUE) != stable)) %>% 
      #   group_by(stable_period_id) %>% 
      #   mutate(track_id_count = n()) %>%
      #   ungroup() #%>% 
      #   group_by(stable_period_id) %>% 
      #   mutate(new_num_detections = ifelse())
          
          
      
      
      # Function to clean the detections (WORKING):
      # data_sum <- data %>% 
      #   group_by(frame) %>%
      #   summarize(num_detections = first(num_detections)) %>% 
      #   mutate(change = ifelse(num_detections != lag(num_detections, default = first(num_detections)), 1, 0)) %>% 
      #   mutate(change_group = cumsum(change == 1)) %>% 
      #   group_by(change_group) %>% 
      #   mutate(frame_count = n()) %>% 
      #   ungroup() %>% 
      #   mutate(stable = ifelse(frame_count >= 15, 1, 0)) %>% 
      #   mutate(
      #     stable_period_id = cumsum(
      #       lag(stable, default = stable[1]) != stable | 
      #         (stable == 1 & lag(change_group, default = change_group[1]) != change_group)
      #       )
      #     ) %>% 
      #   group_by(stable_period_id) %>% 
      #   mutate(
      #     mean_num_detections = ifelse(
      #       sum(frame_count) < 60, 
      #       mean(num_detections), 
      #       # floor(mean(num_detections))
      #       mean(num_detections)
      #     )
      #   ) %>% 
      #   mutate(
      #     new_num_detections = ifelse(
      #       sum(frame_count) < 60, 
      #       round(mean(num_detections)), 
      #       # floor(mean(num_detections))
      #       round(mean(num_detections))
      #       )
      #     ) %>%
      #   ungroup() %>% 
      #   group_by(stable_period_id) %>% 
      #   mutate(period_count = n()) %>% 
      #   ungroup() %>% 
      #   mutate(
      #     new_num_detections2 = ifelse(
      #       stable == 0 & frame_count <= 6 & period_count <= 6, 
      #       NA,
      #       new_num_detections
      #       )
      #     ) %>% 
      #   fill(new_num_detections2, .direction = "down") %>%
      # 
      #   mutate(new_num_detections = ifelse(stable == 0 & frame_count < 4,
      #                                      lag(new_num_detections, default = first(new_num_detections)),
      #                                      new_num_detections)) %>%
      #   ungroup() %>%
      #   # merge with the original dataframe based on frame
      #   subset(select = -c(change, change_group, period_count, stable_period_id, stable)) %>%
      #   merge(data, all.x = TRUE)
      
}
      
      # Function to re-calculate number of detections
      data_clean <- data %>% 
        ##> Identify the periods with the same number of detections
        group_by(frame) %>%
        summarize(sum_num_detections = first(num_detections)) %>% 
        mutate(change = ifelse(sum_num_detections != lag(sum_num_detections, default = first(sum_num_detections)), 1, 0)) %>% 
        mutate(change_group = cumsum(change == 1)) %>%
        # mutate(change_group = ifelse(all(change == 0), 0, cumsum(change == 1))) %>%
        # mutate(change_group = ifelse(n_distinct(change) == 1, 0, cumsum(change == 1))) %>%
        ungroup() %>%
        group_by(change_group) %>% 
        mutate(frame_count = n()) %>% 
        ungroup() %>% 
        ##> Check the stability of the number of detections (> 6 frames with no change)
        mutate(stable = ifelse(frame_count >= 6, 1, 0)) %>% 
        mutate(
          stable_period_id = cumsum(
            lag(stable, default = stable[1]) != stable | 
              (stable == 1 & (lag(change_group, default = change_group[1]) != change_group))
          )
        ) %>% 
        merge(data, by = "frame", all.x = TRUE) %>% 
        group_by(stable_period_id) %>% 
        mutate(mean_num_detections = mean(num_detections, na.rm = TRUE)) %>% 
        
        ##> Check the mean_pixel value for frames with 2 detections during a 
        ##> period of unstability. If the frames with 2 detections have lower 
        ##> pixel value than the ones with 1 detectoins during the period, 
        ##> select num_detections = 2 for that period. Else, just clean that 
        ##> second detection. (I finally did not use that!!!!)

        ##> Also, take into account the confidence of the
        ##> detections. If during the period with 2 detection, there is any detection
        ##> over 0.75 of confidence, understand that's a fake detection and round
        ##> on floor the mean number of detections for that period. 
        mutate(
          #mean_col_2 = mean(mean_color[num_detections == 2], na.rm = TRUE),
          #mean_col_1 = mean(mean_color[num_detections == 1], na.rm = TRUE),
          min_id_conf = confidence[track_id == min(track_id)][1],
          max_id_conf = confidence[track_id == max(track_id)][1]
        ) %>% 
        mutate(
          new_num_detections = 
            ifelse(stable_period_id == first(stable_period_id), 
                   num_detections,
                   ifelse(
                     max(num_detections) == 2,
                     ifelse(
                       (max_id_conf < 0.75 & min_id_conf > 0.75) | (max_id_conf > 0.75 & min_id_conf < 0.75),
                       1,
                       ifelse(
                         max_id_conf < 0.75 & min_id_conf < 0.75,
                         floor(mean(num_detections, na.rm = TRUE)),
                         ceiling(mean(num_detections, na.rm = TRUE))
                       )
                     ),
                     # round(mean(num_detections, na.rm = TRUE))
                     num_detections
                     
                   ))
            
        ) %>%
        ungroup() %>% 
        group_by(stable_period_id) %>% 
        mutate(period_length = n_distinct(frame)) %>% 
        ##> Correct the short unstable periods creating NA and then filling down
        mutate(
          corrected_num_detections = ifelse(
            stable == 0 & period_length <= 6 & stable_period_id != min(stable_period_id),
            NA,
            new_num_detections
          )
        ) %>% 
        ##> HERE i SHOULD ADD A FUNCTION THAT ADDS NEW LINES ESTIMATING THE 2ND
        ##> DETECTION COORDINATES FOR THE FRAMES WHERE ORIGINALLY THERE WERE
        ##> LESS DETECTIONS THAN THE ONES I ESTIMATED WITHT HE CODE. I SHOULD
        ##> DO THIS BASED ON THE TRACK ID AND INTERPOLATE THE X, Y AND KPTS!
        ##> 
        ##> ALSO, add a binary column to tell if the line is "real" or "estimated"
        ungroup() %>%
        fill(corrected_num_detections, .direction = "down") %>%
        group_by(stable_period_id, track_id) %>% 
        fill(11:28, .direction = "down") %>% 
        ungroup() %>% 
        subset(select = -c(change,
                           change_group,
                           period_length,
                           stable_period_id,
                           stable,
                           # mean_col_2,
                           # mean_col_1,
                           min_id_conf,
                           max_id_conf))
      
      # Fill NA where there was a missing detection with the last known coordinates
      # data_clean <- data_clean %>% 
        # group_by(stable_period_id) %>% 
        # fill(11:28, .direction = "down") %>% 
        # ungroup()
      
      # data_filled <- fill_na(data_clean, 11:28)
        
      
      
      #Add binary columns (incubating or not, entrance or not) 
      # Manually create a csv file with the locations of the nest centroid and entry (with dates)
      
      data_clean <- data_clean %>%
        mutate(complete_timestamp = as.POSIXct(complete_timestamp, format = "%y-%m-%d %H:%M:%S"),
               rpi = rpi_name) 
      
      data_clean_merged <- data_clean %>% 
        left_join(nest_positions, by = "rpi") %>% 
        filter(complete_timestamp >= date_from & complete_timestamp <= date_to)
      
      # Check if the detection is over the "eggs" area or at the entrance of the nest
      # Based on bbox location, add new columns for:
      # on_eggs (binary, 1 or 0)
      # at_door (binary, 1 or 0)
      # data_clean_merged <- data_clean_merged %>% 
      #   mutate(on_eggs = ifelse((x >= nest_x_from &
      #                                 x <= nest_x_to &
      #                                 y >= nest_y_from &
      #                                 y <= nest_y_to) & 
      #                                 !(x >= door_x_from &
      #                                   x <= door_x_to &
      #                                   y >= door_y_from &
      #                                   y <= door_y_to) &
      #                                 # <60% of bbox is in nest_area, 
      #                              1, 
      #                              0
      #                              )
      #          ) %>% 
      #   mutate(at_door = ifelse((x >= door_x_from &
      #                              x <= door_x_to &
      #                              y >= door_y_from &
      #                              y <= door_y_to) &
      #                             !(x >= nest_x_from &
      #                                 x <= nest_x_to &
      #                                 y >= nest_y_from &
      #                                 y <= nest_y_to),
      #                           1,
      #                           0)
      #           ) %>% 
      #   subset(select = -c(2:8, 10, 30:34, 37:48))
      
      
      data_clean_merged <- data_clean_merged %>%
        # Calculate the angle of the head using beak-neck or head-neck if NA in neck
        # mutate(angle_head = ifelse(!is.na(kpt0_x) & kpt0_x != 0 & !is.na(kpt2_x) & kpt2_x != 0,
        #                            calculate_angle(kpt2_x, kpt2_y, kpt0_x, kpt0_y),
        #                            ifelse(!is.na(kpt1_x) & kpt1_x != 0 & !is.na(kpt2_x) & kpt2_x != 0,
        #                                   calculate_angle(kpt2_x, kpt2_y,
        #                                                       kpt1_x, kpt1_y),
        #                                   NA))
        # ) %>%
        # Calculate the angle of the body using neck-tail or head-tail if NA in neck
        # mutate(angle_body = ifelse(!is.na(kpt2_x) & kpt2_x != 0 & !is.na(kpt3_x) & kpt3_x != 0, 
        #                            calculate_angle(kpt3_x, kpt3_y, kpt2_x, kpt2_y),
        #                            ifelse(!is.na(kpt1_x) & kpt1_x != 0 & !is.na(kpt3_x) & kpt3_x != 0,
        #                                   calculate_angle(kpt3_x, kpt3_y, 
        #                                                       kpt1_x, kpt1_y),
        #                                   NA))
        # ) %>%
        # mutate(angle_head_door = ifelse(!is.na(kpt0_x) & kpt0_x != 0 & !is.na(kpt2_x) & kpt2_x != 0, 
        #                                 calculate_relative_angle(angle_head, 
        #                                                        kpt2_x, kpt2_y,
        #                                                        door_x, door_y 
        #                                                        ),
        #                                 ifelse(!is.na(kpt1_x) & kpt1_x != 0 & !is.na(kpt2_x) & kpt2_x != 0,
        #                                        calculate_relative_angle(angle_head, 
        #                                                                 kpt2_x, kpt2_y,
        #                                                                 door_x, door_y
        #                                                               ),
        #                                        NA))
        # ) %>% 
        # mutate(angle_body_door = ifelse(!is.na(kpt2_x) & kpt2_x != 0 & !is.na(kpt3_x) & kpt3_x != 0, 
        #                                 calculate_relative_angle(angle_body, 
        #                                                        kpt2_x, kpt2_y,
        #                                                        door_x, door_y
        #                                                        ),
        #                                 ifelse(!is.na(kpt1_x) & kpt1_x != 0 & !is.na(kpt3_x) & kpt3_x != 0,
        #                                        calculate_relative_angle(angle_body, 
        #                                                               kpt1_x, kpt1_y, 
        #                                                               door_x, door_y
        #                                                               ),
        #                                        NA))
        # ) %>%
        # Caltulate the angle of the head using the beak-head only.
        mutate(angle_head = ifelse(!is.na(kpt0_x) & kpt0_x != 0 & !is.na(kpt1_x) & kpt1_x != 0,
                                          calculate_angle(kpt1_x, kpt1_y,
                                                          kpt0_x, kpt0_y),
                                          NA)
        ) %>%
        # Calculate the angle of the body using the tail-neck only
        mutate(angle_body = ifelse(!is.na(kpt2_x) & kpt2_x != 0 & !is.na(kpt3_x) & kpt3_x != 0, 
                                   calculate_angle(kpt3_x, kpt3_y, kpt2_x, kpt2_y),
                                   NA)
        ) %>%
        mutate(angle_head_door = ifelse(!is.na(kpt0_x) & kpt0_x != 0 & !is.na(kpt1_x) & kpt1_x != 0, 
                                        calculate_relative_angle(angle_head, 
                                                                 kpt1_x, kpt1_y,
                                                                 door_x, door_y),
                                        NA)
        ) %>% 
        mutate(angle_body_door = ifelse(!is.na(kpt2_x) & kpt2_x != 0 & !is.na(kpt3_x) & kpt3_x != 0, 
                                        calculate_relative_angle(angle_body, 
                                                                 kpt2_x, kpt2_y,
                                                                 door_x, door_y),
                                         NA)
        ) %>%
        group_by(track_id) %>% 
        mutate(body_movement = 
                   # abs(
                   #   lag(angle_body, 
                   #       default = first(angle_body)
                   #       ) -  angle_body
                   #   ), 
                   ifelse(is.na(lag(angle_body)), NA, angle_diff(angle_body, lag(angle_body)))
          ) %>% 
        mutate(head_movement = 
                  # abs(
                  #   lag(angle_head, 
                  #       default = first(angle_head)
                  #   ) -  angle_head
                  # ), 
                  ifelse(is.na(lag(angle_head)), NA, angle_diff(angle_head, lag(angle_head)))
          ) %>% 
        mutate(body_movement_rel = 
                  # abs(
                  #   lag(angle_body_door, 
                  #       default = first(angle_body_door)
                  #   ) -  angle_body_door
                  # ), 
                  ifelse(is.na(lag(angle_body_door)), NA, angle_diff(angle_body_door, lag(angle_body_door)))
          
          ) %>% 
        mutate(head_movement_rel = 
                  # abs(
                  #   lag(angle_head_door, 
                  #       default = first(angle_head_door)
                  #   ) -  angle_head_door
                  # ), 
                  ifelse(is.na(lag(angle_head_door)), NA, angle_diff(angle_head_door, lag(angle_head_door)))
          
          ) %>% 
        ungroup() %>% 
        subset(select = -c(door_x, door_y))
      
      data_clean_merged <- data_clean_merged %>%
        mutate(
          # Calculate bounding box coordinates
          x_min = x - w / 2,
          x_max = x + w / 2,
          y_min = y - h / 2,
          y_max = y + h / 2,
          
          # Check if the center point (x, y) is within the nest area / door area
          center_on_nest = x >= nest_x_from & x <= nest_x_to & y >= nest_y_from & y <= nest_y_to + 0.1,
          center_at_door = x >= door_x_from - 0.1 & x <= door_x_to + 0.1, # & y >= door_y_from & y <= door_y_to,
          ends_at_door = y_min >= (door_y_from - 0.05) & y_min <= (door_y_from + 0.05),
          
          # Calculate the overlapping area between the bounding box and the nest area / door area
          overlap_x_min_nest = pmax(nest_x_from, x_min),
          overlap_x_max_nest = pmin(nest_x_to, x_max),
          overlap_y_min_nest = pmax(nest_y_from, y_min),
          overlap_y_max_nest = pmin(nest_y_to, y_max),
          
          overlap_width_nest = pmax(0, overlap_x_max_nest - overlap_x_min_nest),
          overlap_height_nest = pmax(0, overlap_y_max_nest - overlap_y_min_nest),
          overlap_area_nest = overlap_width_nest * overlap_height_nest,
          
          overlap_x_min_door = pmax(door_x_from, x_min),
          overlap_x_max_door = pmin(door_x_to, x_max),
          overlap_y_min_door = pmax(door_y_from, y_min),
          overlap_y_max_door = pmin(door_y_to, y_max),
          
          overlap_width_door = pmax(0, overlap_x_max_door - overlap_x_min_door),
          overlap_height_door = pmax(0, overlap_y_max_door - overlap_y_min_door),
          overlap_area_door = overlap_width_door * overlap_height_door,
          
          # Calculate the bounding box area
          bounding_box_area = w * h,
          
          # Check if more than 60% of the bounding box area is within the nest area /door
          more_than_33_percent_on_nest = (overlap_area_nest / bounding_box_area) > 0.25,
          more_than_33_percent_at_door = (overlap_area_door / bounding_box_area) > 0.25,
          
          # Check if angle of the body is heading to the door
          heading_door = angle_body_door > (-15) & angle_body_door < 15,
          
          # Determine the value of on_eggs based on the conditions
          on_eggs = ifelse(center_on_nest & 
                             (overlap_area_nest / bounding_box_area) > 0.25 &
                             (overlap_area_door / bounding_box_area) < 0.50 &
                             !ends_at_door, 
                           1, 
                           0),
          
          at_door = ifelse(center_at_door & 
                             (overlap_area_door / bounding_box_area) > 0.20 &
                             # !(overlap_area_nest / bounding_box_area) > 0.50 &
                             (ends_at_door | heading_door),
                           1, 
                           0)
          
        ) %>%
        # Optionally, you can select to keep only relevant columns
        select(-x_min, -x_max, -y_min, -y_max, -center_on_nest, -center_at_door,
               -overlap_x_min_nest, -overlap_x_max_nest, -overlap_y_min_nest, -overlap_y_max_nest,
               -overlap_width_nest, -overlap_height_nest, -overlap_area_nest, -overlap_x_min_door,
               -overlap_x_max_door, -overlap_y_min_door, -overlap_y_max_door, -overlap_width_door,
               -overlap_height_door, -overlap_area_door, -bounding_box_area, ends_at_door,
               -more_than_33_percent_on_nest, -more_than_33_percent_at_door, -heading_door)

      # If state == 1 and duration > 30 sec, calculate the angle of keypoints 
      data_sum <- data_clean_merged %>% 
      group_by(frame) %>%
        # summarize(sum_num_detections = first(corrected_num_detections)) %>% 
        mutate(change = ifelse(sum_num_detections != lag(sum_num_detections, default = first(sum_num_detections)), 1, 0)) %>% 
        # mutate(change_group = cumsum(change == 1)) %>%
        # mutate(change_group = ifelse(all(change == 0), 0, cumsum(change == 1))) %>%
        mutate(change_group = ifelse(n_distinct(change) == 1, 0, cumsum(change == 1))) %>%
        ungroup() %>%
        # left_join(data_clean_merged, by = "frame") %>% 
        group_by(change_group) %>% 
        mutate(frame_count = n()) %>% 
        ungroup() %>% 
        mutate(body_change = ifelse(frame_count >= 30 & corrected_num_detections == 1, body_movement, NA)) %>% 
        mutate(head_change = ifelse(frame_count >= 30 & corrected_num_detections == 1, head_movement, NA)) %>% 
        # MAKE SURE WE KEEP "HEAD_CHANGE" AND "BODY_CHANGE" HERE!
        subset(select = -c(2:4, 6, 29, 30, 32:44, 53, 56:57))
      
      # Add video name to the dataframe
      # data_sum <- data_sum %>% 
      #   mutate(rec_date = rec_date,
      #          ld_date = ld_date,
      #          hd_date = hd_date
      #          )
        

      # Head_down (there is no beak coordinates and angle from tail-head and neck-head is less than 90º)
      # NA if I don't have the points to calculate them. 
      # CALCULATE THE difference of the angle (C) from the last frame (rate of change)
      
      
      
      
      # Based on keypoints location, add new column with angle of them to the entry
      ##> For frames where there is only 1 detection:
      ##> Calculate the angle of tail-neck line with tail-entry. 
      ##> If beak keypoint exist, calculate the angle of neck-beak angle with the entry.
      ##> Otherwise, use neck-head. 
      ##> NA if that's not possible. 
      
      # Save processed CSV file in the processed_data folder
      write.csv(data_sum, file = out_csv_path)
    }
  } else {
    video_id <- sub(".*/(.*)\\.csv$", "\\1", file_path_sans_ext(datafile))
    print(paste0("Date out of range in ", video_id, ": ", date))
    next
    }
}

##> This script extract needed variables from processed detections and creates
##> dataframes with some "results", ready to start analysis from them. 

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(purrr)
library(lubridate)
library(tools)
source("G:/Mi unidad/Marçal's PhD/001_automated_jackdaw_monitoring/Test_dir/Z_scripts/functions_test.R")

setwd("G:/Mi unidad/Marçal's PhD/001_automated_jackdaw_monitoring/Z_scripts")

##> Read needed dataframes
box_rpi_csv <- read.csv("../B2_helper_data/box_rpi_2023.csv", colClasses="character")

# Read temperature log files
file_path <- "../B2_helper_data/temperature"
log_files <- list.files(path = file_path, pattern = "*.log", full.names = TRUE)

# Create a function to read and process each log file
process_log_file <- function(file) {
  # Extract the rpi from the filename (e.g., "jackdaw0" from "temperature_jackdaw0.log")
  rpi <- str_extract(basename(file), "jackdaw\\d+")
  
  # Read the raw data
  raw_data <- readLines(file)
  
  # Extract datetime and temperature
  data <- tibble(raw = raw_data) %>%
    mutate(
      datetime = str_extract(raw, "^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}"),
      datetime = ymd_hms(datetime),  # Convert to proper datetime
      temperature = str_extract(raw, "\\d+\\.\\d{1,3}"),  # Extract temperature
      temperature = as.numeric(temperature),  # Convert to numeric
      rpi = rpi  # Add rpi as a column
    ) %>%
    select(datetime, temperature, rpi)  # Keep only relevant columns
  
  return(data)
}

all_temperature_data <- map_dfr(log_files, process_log_file)
write.csv(all_temperature_data, "../B2_helper_data/all_temperature_data.csv", row.names = FALSE)


##> fitness_data.csv to check relative dates to LD, HD.
fitness_data <- read_delim("G:/Mi unidad/Marçal's PhD/001_automated_jackdaw_monitoring/B2_helper_data/fitness_data.csv",
                           delim = ";", escape_double = FALSE, trim_ws = TRUE)
fitness_data <- fitness_data %>% 
  mutate(obsLD = as.Date(obsLD, format = "%d/%m/%Y"),
         obsHD = as.Date(obsHD, format = "%d/%m/%Y")) %>%
  left_join(box_rpi_csv, by = "idbox") %>% 
  mutate(across(rpi, ~ifelse(.=="", NA, as.character(.))))

# Remove data from non recorded boxes
fitness_data <- fitness_data %>% 
  filter(!is.na(rpi),
         !is.na(obsHD))

##> STATE_CHANGES <- Every row is period where "num_detections" did not change.####
##>     |_ rpi
##>     |_ relative date to LD
##>     |_ relative date to HD
##>     |_ absolute date from the start of recording
##>     |_ us visiting the tower (TRUE-FALSE), to filter the times where we were bothering them
##>     |_ start_time
##>     |_ state (num_detection)
##>     |_ duration
##>     |_ previous and next states
##>     |_ % incubation
##>     |_ % at the entry
##>     |_ average position to nest opening (head)
##>     |_ average position to nest opening (body)
##>     |_ average amount of movement (head) per minute

datafiles <- list.files("../C_processed_data", pattern = "\\.csv$", full.names = TRUE)

# Create an empty data frame to store the results
state_changes <- data.frame()
# for (datafile in datafiles[-1:-2700]) {
for (datafile in datafiles) {
  # datafile <- "../C_processed_data/RG_230710_jackdaw3_3_processed.csv"
  print(paste("Working with file:", datafile))
  
  data <- read.csv(datafile)
  data$complete_timestamp <- as.POSIXct(data$complete_timestamp)

  # Extract video basic information
  video_id <- sub(".*/(.*)_processed\\.csv$", "\\1", datafile)
  rpi_name <- strsplit(video_id, "_")[[1]][3]
  rpi_name <- format_rpi_id(rpi_name)
  # date <- strsplit(video_id, "_")[[1]][2]
  # date <- as.Date(date, format = "%y%m%d")
  idbox <- box_rpi_csv$idbox[box_rpi_csv$rpi == rpi_name][1]
  
  
  # # First row of data
  # first_row <- data[1, ]
  # 
  # # Initialize variables to track periods
  # start_time <- min(data$complete_timestamp)
  # end_time <- max(data$complete_timestamp)
  # current_state <- data$corrected_num_detections[1]
  # last_state <- NA
  # 

  # Find shifts in 'corrected_num_detections' using lag() and lead() functions
  data <- data %>%
    mutate(shift = ifelse(rec_date == lag(rec_date) & corrected_num_detections != lag(corrected_num_detections, default = corrected_num_detections[1]),
                          1,
                          0)
           )
  
  data_shift <- data %>% 
    ##> Identify the periods with the same number of detections
    group_by(frame) %>%
    summarise(sum_num_detections = first(corrected_num_detections),
              rec_date) %>% 
    ungroup() %>% 
    mutate(change = ifelse(sum_num_detections != lag(sum_num_detections, default = first(sum_num_detections)), 1, 0)) %>% 
    mutate(change_group = cumsum(change == 1 | rec_date != lag(rec_date, default = first(rec_date)))) %>%
    # mutate(change_group = ifelse(all(change == 0), 0, cumsum(change == 1))) %>%
    # mutate(change_group = ifelse(n_distinct(change) == 1, 0, cumsum(change == 1))) %>%
    # ungroup() %>%
    subset(select = -c(change, sum_num_detections, rec_date)) %>% 
    left_join(data, by = "frame") %>% 
    distinct(frame, track_id, .keep_all =TRUE) %>% 
    group_by(change_group) %>% 
    summarise(rpi = rpi_name,
              idbox = idbox,
              video = video_id,
              current_state = corrected_num_detections,
              start_time = min(complete_timestamp),
              # duration = as.numeric(difftime(max(complete_timestamp), 
              #                                min(complete_timestamp), 
              #                                units = "secs")),
              duration = n_distinct(frame),
              on_eggs = n_distinct(frame[on_eggs == 1 & !is.na(on_eggs)]),
              at_door = n_distinct(frame[at_door == 1 & !is.na(at_door) & on_eggs != 1]), 
              avg_angle_head = mean(angle_head_door, na.rm = TRUE),
              avg_angle_body = mean(angle_body_door, na.rm = TRUE),
              avg_change_head = mean(head_movement, na.rm = TRUE),
              avg_change_body = mean(body_movement, na.rm = TRUE),
              ld_date = ld_date,
              hd_date = hd_date,
              rec_date = rec_date
              ) %>% 
    distinct(change_group, .keep_all = TRUE) %>% 
    ungroup() %>% 
    mutate(last_state = ifelse(row_number() != 1 & 
                                 rec_date == lag(rec_date, default = first(rec_date)), 
                               lag(current_state),
                               NA),
            next_state = ifelse(row_number() != n() & 
                                  rec_date == lead(rec_date, default = first(rec_date)),
                                lead(current_state),
                                NA)
           ) %>% 
    mutate(change_group = ifelse(is.na(change_group), cumsum(is.na(change_group) + max(change_group, na.rm = TRUE)), change_group))
  
  
    # Add the period to the results dataframe
    state_changes <- bind_rows(state_changes, data_shift)
    # state_changes <- state_changes %>% 
    #   subset(select = c(-1, -2))
}

##> Store results extracted to a csv after loop
state_changes_path <- "../D_summarizing_data/state_changes.csv"
write.csv(state_changes, file = state_changes_path)








##> HOURLY_DATA & DAILY_DATA <- summary of visitation and attendance at an hourly/daily scale ####
##>     |_ rpi
##>     |_ relative date to LD
##>     |_ relative date to HD
##>     |_ absolute date from the start of recording
##>     |_ Available data
##>     |_ us visiting the tower (TRUE-FALSE), to filter the times where we were bothering them
##>     |_ num_visits of every kind (0-1, 1-2, 0-2)
##>     |_ num_visits of 0-1 of more than 1 minutes (used to calculate amount of head movement)
##>     |_ more informative columns like "how many visits shorter than 10 secs, etc
##>     |_ time spent by 1 ind
##>     |_ time spent by 2 inds
##>     |_ coeficient of variation of durations of visits of every kind (0, >0, 1, 2)
##>     |_ average amount of movement (head) per minute

# Using state_change.csv file created before:

state_changes <- read_csv("G:/Mi unidad/Marçal's PhD/001_automated_jackdaw_monitoring/D_summarizing_data/state_changes.csv")

visitation <- state_changes %>% 
  mutate(start_time = as.POSIXct(start_time),
         hour = format(start_time, "%H"),
  ) %>% 
  subset(select = -c(1)) %>% 
  group_by(hour, rpi, rec_date, ld_date, hd_date) %>% 
  summarise(
    visits_0_1 = n_distinct(start_time[current_state == 1 & last_state == 0 & !is.na(last_state)]),
    visits_1_0 = n_distinct(start_time[current_state == 0 & last_state == 1 & !is.na(last_state)]),
    visits_1_2 = n_distinct(start_time[current_state == 2 & last_state == 1 & !is.na(last_state)]),
    visits_2_1 = n_distinct(start_time[current_state == 1 & last_state == 2 & !is.na(last_state)]),
    visits_0_2 = n_distinct(start_time[current_state == 2 & last_state == 0 & !is.na(last_state)]),
    visits_2_0 = n_distinct(start_time[current_state == 0 & last_state == 2 & !is.na(last_state)]),
    visits_0_gt0 = n_distinct(start_time[current_state > 0 & last_state == 0 & !is.na(last_state)]), # group periods with more than 0 individual and sum durations
    visits_gt0_0 = n_distinct(start_time[current_state == 0 & last_state > 0 & !is.na(last_state)]), # group periods with more than 0 individual and sum durations
    short10_visits_0_1 = n_distinct(start_time[current_state == 1 & last_state == 0 & !is.na(last_state) & duration < 10]),
    short10_visits_1_2 = n_distinct(start_time[current_state == 2 & last_state == 1 & !is.na(last_state) & duration < 10]),
    short10_visits_0_2 = n_distinct(start_time[current_state == 2 & last_state == 0 & !is.na(last_state) & duration < 10]),
    short30_visits_0_1 = n_distinct(start_time[current_state == 1 & last_state == 0 & !is.na(last_state) & duration >= 10 & duration <= 60]),
    short30_visits_1_2 = n_distinct(start_time[current_state == 2 & last_state == 1 & !is.na(last_state) & duration >= 10 & duration <= 60]),
    short30_visits_0_2 = n_distinct(start_time[current_state == 2 & last_state == 0 & !is.na(last_state) & duration >= 10 & duration <= 60]),
    long_visits_0_1 = n_distinct(start_time[current_state == 1 & last_state == 0 & !is.na(last_state) & duration > 60]),
    long_visits_1_2 = n_distinct(start_time[current_state == 2 & last_state == 1 & !is.na(last_state) & duration > 60]),
    long_visits_0_2 = n_distinct(start_time[current_state == 2 & last_state == 0 & !is.na(last_state) & duration > 60]),
    mean_duration_0_1 = mean(duration[current_state == 1 & last_state == 0 & !is.na(last_state)]),
    mean_duration_1_2 = mean(duration[current_state == 2 & last_state == 1 & !is.na(last_state)]),
    mean_duration_0_2 = mean(duration[current_state == 2 & last_state == 0 & !is.na(last_state)])
  )

visitation_gt0 <- state_changes %>% 
  mutate(start_time = as.POSIXct(start_time),
         hour = format(start_time, "%H"),
  ) %>% 
  mutate(more0 = ifelse(current_state > 0, 1, 0)) %>% 
  mutate(group = cumsum(more0 == 0) + 1) #%>% 

visitation_gt0 <- visitation_gt0 %>%   
  filter(more0 > 0) %>% 
  group_by(rpi, hour, rec_date, group) %>% 
  summarise(
    # gt0_start_time = first(start_time),
    duration_gt0 = sum(duration)) %>% 
  filter(duration_gt0 > 3) %>% 
  summarise(mean_duration_gt0 = as.integer(mean(duration_gt0)))

visitation_0 <- state_changes %>% 
  mutate(start_time = as.POSIXct(start_time),
         hour = format(start_time, "%H"),
  ) %>% 
  mutate(zero = ifelse(current_state == 0, 1, 0)) %>% 
  mutate(group = cumsum(zero == 0) + 1) #%>% 

visitation_0 <- visitation_0 %>%   
  filter(zero > 0) %>% 
  group_by(rpi, hour, rec_date, group) %>% 
  summarise(
    duration_0 = sum(duration)) %>% 
  filter(duration_0 > 3) %>% 
  summarise(mean_duration_0 = as.integer(mean(duration_0)))

datafiles <- list.files("../C_processed_data", pattern = "\\.csv$", full.names = TRUE)
datafiles <- lapply(datafiles, sort)

attendance <- data.frame()

for (datafile in datafiles){
  print(paste("Working with file:", datafile))
  data <- read.csv(datafile)
  # Extract video basic information
  video_id <- sub(".*/(.*)_processed\\.csv$", "\\1", datafile)
  rpi_name <- strsplit(video_id, "_")[[1]][3]
  rpi_name <- format_rpi_id(rpi_name)
  # date <- strsplit(video_id, "_")[[1]][2]
  # date <- as.Date(date, format = "%y%m%d")
  idbox <- box_rpi_csv$idbox[box_rpi_csv$rpi == rpi_name][1]
  
  # data$complete_timestamp <- as.POSIXct(data$complete_timestamp)
  
  data <- data %>% 
    mutate(complete_timestamp = as.POSIXct(complete_timestamp),
           hour = format(complete_timestamp, "%H"),
           rpi = rpi_name,
           video = video_id
    )
  
  # Count the frames with 0, 1 or 2 detections. Also the total recorded frames per h
  hourly_attendance <- data %>% 
    group_by(hour, rpi, video, rec_date) %>% 
    summarise(
      date = as.Date(min(complete_timestamp)),
      first_state = corrected_num_detections[row_number() == 1],
      last_state = corrected_num_detections[row_number() == n()],
      attendance_0 = n_distinct(frame[corrected_num_detections == 0]),
      attendance_1 = n_distinct(frame[corrected_num_detections == 1]),
      attendance_2 = n_distinct(frame[corrected_num_detections == 2]),
      available_frames = n_distinct(frame),
      mean_head_change = mean(head_change, na.rm = TRUE),
      var_head_change = var(head_change, na.rm = TRUE),
      mean_body_change = mean(body_change, na.rm = TRUE),
      var_body_change = var(body_change, na.rm = TRUE),
      mean_angle_head = mean(head_change, na.rm = TRUE),
      mean_angle_body = mean(body_change, na.rm = TRUE),
      head_frames = n_distinct(frame[!is.na(angle_head_door)]),
      body_frames = n_distinct(frame[!is.na(angle_body_door)]),
      on_eggs = n_distinct(frame[on_eggs == 1 & !is.na(on_eggs)]),
      at_door = n_distinct(frame[at_door == 1 & !is.na(at_door) & on_eggs != 1])
    )

  attendance <- bind_rows(hourly_attendance, attendance)
}

visitation_attendance <- visitation %>% 
  merge(attendance, by = c("hour", "rpi", "rec_date"), all.x = TRUE, all.y = TRUE) %>%
  merge(visitation_gt0) %>%
  merge(visitation_0) %>%
  group_by(hour, rpi, date, rec_date) %>% 
  summarize(
    available_frames = sum(available_frames, na.rm = TRUE),
    visits_0_1 = sum(visits_0_1),
    visits_1_0 = sum(visits_1_0),
    visits_1_2 = sum(visits_1_2),
    visits_2_1 = sum(visits_2_1),
    visits_0_2 = sum(visits_0_2),
    visits_2_0 = sum(visits_0_2),
    visits_0_gt0 = sum(visits_0_gt0),
    visits_gt0_0 = sum(visits_gt0_0),
    short10_visits_0_1 = sum(short10_visits_0_1),
    short10_visits_1_2 = sum(short10_visits_1_2),
    short10_visits_0_2 = sum(short10_visits_0_2),
    short30_visits_0_1 = sum(short30_visits_0_1),
    short30_visits_1_2 = sum(short30_visits_1_2),
    short30_visits_0_2 = sum(short30_visits_0_2),
    long_visits_0_1 = sum(long_visits_0_1),
    long_visits_1_2 = sum(long_visits_1_2),
    long_visits_0_2 = sum(long_visits_0_2),
    mean_duration_0_1 = mean(sum(mean_duration_0_1)),
    mean_duration_1_2 = mean(sum(mean_duration_1_2)),
    mean_duration_0_2 = mean(sum(mean_duration_0_2)),
    mean_duration_gt0 = mean(mean_duration_gt0),
    mean_duration_0 = mean(mean_duration_0),
    first_state = first(first_state),
    last_state = last(last_state),
    from_video = paste(video, collapse = "_AND_"),
    attendance_0 = sum(attendance_0),
    attendance_1 = sum(attendance_1),
    attendance_2 = sum(attendance_2),
    attendance_gt0 = sum(c(attendance_2, attendance_1)),
    mean_head_change = mean_head_change,
    mean_body_change = mean_body_change,
    var_head_change = var_head_change,
    var_body_change = var_body_change,
    mean_angle_head = mean_angle_head,
    mean_angle_body = mean_angle_body,
    on_eggs = on_eggs,
    at_door = at_door
    ) %>% 
  left_join(box_rpi_csv, by = "rpi") %>% 
  left_join(fitness_data, by = "idbox") %>% 
  filter(!is.na(obsHD)) %>% 
  mutate(ld_date = as.numeric(difftime(date, obsLD, units = "days")),
         hd_date = as.numeric(difftime(date, obsHD), units = "days")) %>% 
  mutate(breeding_stage = ifelse(ld_date < 0, 
                                 "nest_construction",
                                 ifelse(ld_date >= 0 & hd_date < 0, 
                                        "incubation",
                                        ifelse(hd_date >= 0 & hd_date <= 6, 
                                               "1week_h",
                                               ifelse(hd_date >= 7 & hd_date <= 13, 
                                                      "2week_h",
                                                      ifelse(hd_date >= 14 & hd_date <= 20, 
                                                             "3week_h",
                                                             "gt3week_h"))))))

visitation_attendance <- visitation_attendance %>% 
  group_by(hour, rpi, date, breeding_stage) %>% 
  summarise(across(where(is.numeric) & !c(on_eggs, at_door), mean, na.rm = TRUE, .names = "{col}"),
            on_eggs = sum(on_eggs, na.rm = TRUE),  # Sum for "on_eggs"
            at_door = sum(at_door, na.rm = TRUE),  # Sum for "at_door"
            from_video = first(from_video)  # Keep "from_video" as is (first occurrence)
  ) %>%
  mutate(available_frames = if_else(available_frames > 3600, available_frames / length(strsplit(from_video, "_AND_")[[1]]), available_frames)) %>%
  ungroup() %>% 
  left_join(box_rpi_csv, by = "rpi") %>% 
  left_join(fitness_data, by = "idbox") %>% 
  filter(!is.na(obsHD)) %>% 
  subset(select = -c(47, 48, 49, 50, 51, 53, 56, 57, 60, 61))

colnames(visitation_attendance)

# visitation_attendance <- visitation_attendance %>% 
#   subset(select = -c(44:48, 50, 53:58))
# visitation_attendance <- visitation_attendance %>% 
#   filter(available_frames <= 3600)

# Calc total daily sunlight time
# Set location of the tower
latitude <- 41.525019
longitude <- 0.705792
library(suncalc)

visitation_attendance <- visitation_attendance %>% 
  group_by(date) %>% 
  mutate(# Day length from sunrise to sunset in seconds
         day_length = as.numeric((getSunlightTimes(date = date,
                                                   lat = latitude,
                                                   lon = longitude,
                                                   tz = "Europe/Madrid")[1,7]) -
                                   (getSunlightTimes(date = date,
                                                     lat = latitude,
                                                     lon = longitude,
                                                     tz = "Europe/Madrid")[1,6]))*3600) %>% 
  ungroup()

daily_data <- visitation_attendance %>% 
  mutate(date = as.Date(date)) %>% 
  group_by(hd_date, ld_date, rec_date, date, day_length, breeding_stage, rpi, 
           idbox, ousTotals, ousEclosionats, volanders) %>% 
  summarise(
    across(c("available_frames":"long_visits_0_2", 
             "attendance_0":"attendance_gt0", 
             "on_eggs":"at_door"), 
           sum, .names = "{col}"),
    across(c("mean_duration_0_1":"mean_duration_0", 
             "mean_head_change", "mean_body_change"), 
           mean, na.rm = TRUE, .names = "{col}"),
    )

##> Store results extracted to a csv after loop
visitation_path <- "../D_summarizing_data/visitation.csv"
write.csv(visitation, file = visitation_path)

attendance_path <- "../D_summarizing_data/attendance.csv"
write.csv(attendance, file = attendance_path)

visitation_attendance_path <- "../D_summarizing_data/visitaiton_attendance.csv"
write.csv(visitation_attendance_d, file = visitation_attendance_path)

daily_data_path <- "../D_summarizing_data/daily_data.csv"
write.csv(daily_data, file = daily_data_path)

# visitation_attendance_sum <- visitation_attendance %>% 
#   group_by(hour, rpi, date) %>% 
#   summarize(across(where(is.numeric), sum, na.rm = TRUE), .groups = "drop")



# Extract some specific variables I need to compute models ####
##> For column in dataframe:
##>   column_nc (ld_date == -15:-10) (nest construction)
##>   column_b_ld (ld_date == -5:-1) (before laying date)
##>   column_ld_cc (ld_date == 0:ousTotals) (laying date to clutch completed)
##>   column_ld_inc (ld_date == 10:15) (incubation)
##>   column_ld_1w (breeding_stage == 1week_h) (1week_h)
##>   column_ld_2w (breeding_stage == 2week_h) (2week_h)
##>   
##>   

summary_stages <- daily_data %>% 
  group_by(rpi) %>% 
  mutate(interesting_period = case_when(
    ld_date >= -10 & ld_date <= -5 ~ "nc",
    ld_date >= -5 & ld_date <= -1 ~ "b_ld",
    ld_date >= 0 & ld_date <= max(as.numeric(ousTotals)) ~ "cc",
    ld_date > max(as.numeric(ousTotals)) & hd_date < 0 ~ "complete_inc",
    ld_date >= 10 & ld_date <= 15 ~ "inc",
    hd_date >= 0 & hd_date <= 6 ~ "1week_h",
    hd_date >= 7 & hd_date <= 13 ~ "2week_h",
    TRUE ~ "other")
         ) %>% 
  ungroup() %>% 
  filter(interesting_period!="other") %>% 
  group_by(interesting_period, rpi, idbox) %>% 
  # mutate(
  #   across(c("visits_0_1":"at_door"), ~ ./ available_frames, .names = "{col}")) %>% 
  summarise(
    across(c("available_frames":"at_door"), sum, .names = "{col}"),
    across(c("mean_duration_0_1":"mean_body_change"), mean, na.rm = TRUE, .names = "{col}")
  )

summary_stages_path <- "../D_summarizing_data/summary_stages.csv"
write.csv(summary_stages, file = summary_stages_path)

##> Mean attendance_gt0 at nc
mean_attendance <- summary_stages %>% 
  filter(interesting_period == "nc")

hist(mean_attendance$attendance_gt0/mean_attendance$available_frames*100)
mean(mean_attendance$attendance_gt0/mean_attendance$available_frames*100)
sd(mean_attendance$attendance_gt0/mean_attendance$available_frames*100)

##> Mean attendance_gt0 from 7-14 days after LD
mean_attendance <- summary_stages %>% 
  filter(interesting_period == "b_ld")

hist(mean_attendance$attendance_gt0/mean_attendance$available_frames*100)
mean(mean_attendance$attendance_gt0/mean_attendance$available_frames*100)
sd(mean_attendance$attendance_gt0/mean_attendance$available_frames*100)

##> Mean attendance_gt0 during 1-week-h
mean_attendance <- summary_stages %>% 
  filter(interesting_period == "1week_h")

hist(mean_attendance$attendance_gt0/mean_attendance$available_frames*100)
mean(mean_attendance$attendance_gt0/mean_attendance$available_frames*100)
sd(mean_attendance$attendance_gt0/mean_attendance$available_frames*100)

##> Mean attendance_gt0 during incubation
mean_attendance <- summary_stages %>% 
  filter(interesting_period == "complete_inc")

hist(mean_attendance$attendance_gt0/mean_attendance$available_frames*100)
mean(mean_attendance$attendance_gt0/mean_attendance$available_frames*100)
sd(mean_attendance$attendance_gt0/mean_attendance$available_frames*100)

hist(mean_attendance$on_eggs/mean_attendance$available_frames*100)
mean(mean_attendance$on_eggs/mean_attendance$available_frames*100)
sd(mean_attendance$on_eggs/mean_attendance$available_frames*100)

##> Duration of incubation period

##> Rec_date at laying date



# Mean daily visits by a second individual ld_date == -25:-15 (nest construction)

# Mean daily visits by a second individual ld_date == -5:-15 (nest construction)


##> DESCRIPTIVES <- Available data, how many complete days, accuracy of detections...####

##> Include calculations for data availability, for descriptives. 
##> Calculate the number of frames available for each RPi, mean, max and min.
##> Weight of the data stored in the SD card.
##> Cost of the system (money)

rpi_descriptives <- daily_data %>% 
  group_by(rpi) %>% 
  summarise(
    unique_days = n_distinct(date),
    total_available_frames = sum(available_frames),
    total_day_length = sum(day_length),
    total_percent_available_frames = (sum(available_frames)/sum(day_length))*100,
    n_complete_days = sum((available_frames/day_length)*100 > 95),
    n_80_percent_days = sum((available_frames/day_length)*100 > 80),
    n_less_20_days = sum((available_frames/day_length)*100 < 20),
    n_empty_days = sum((available_frames/day_length)*100 < 5),
    mean_percent_available_frames = mean((available_frames/day_length)*100),
    max_percent_available_frames = max((available_frames/day_length)*100),
    min_percent_available_frames = min((available_frames/day_length)*100),
    sd_percent_available_frames = sd((available_frames/day_length)*100)
  )

total_detections <- sum(visitation_attendance$attendance_1 + visitation_attendance$attendance_2 * 2)


# Overall statistics across all RPi
overall_descriptives <- rpi_descriptives %>%
  summarise(
    total_recorded_frames = sum(total_available_frames),
    mean_unique_days = mean(unique_days),
    max_unique_days = max(unique_days),
    min_unique_days = min(unique_days),
    var_unique_days = var(unique_days),
    sd_unique_days = sd(unique_days),
    
    
    mean_available_frames = mean(total_available_frames),
    max_available_frames = max(total_available_frames),
    min_available_frames = min(total_available_frames),
    var_available_frames = var(total_available_frames),
    sd_available_frames = sd(total_available_frames),
    
    
    mean_day_length = mean(total_day_length),
    max_day_length = max(total_day_length),
    min_day_length = min(total_day_length),
    var_day_length = var(total_day_length),
    
    mean_percent_frames = mean(total_percent_available_frames),
    max_percent_frames = max(total_percent_available_frames),
    min_percent_frames = min(total_percent_available_frames),
    var_percent_frames = var((total_available_frames/total_day_length)*100),
    sd_percent_frames = sd((total_available_frames/total_day_length)*100),
    
    mean_n_complete_days = mean(n_complete_days),
    var_n_complete_days = var(n_complete_days),
    sd_n_complete_days = sd(n_complete_days),
    
    mean_n_80_percent_days = mean(n_80_percent_days),
    var_n_80_percent_days = var(n_80_percent_days),
    sd_n_80_percent_days = sd(n_80_percent_days),
    
    mean_n_less_20_days = mean(n_less_20_days),
    var_n_less_20_days = var(n_less_20_days),
    sd_n_less_20_days = sd(n_less_20_days),
    
    mean_n_empty_days = mean(n_empty_days),
    var_n_empty_days = var(n_empty_days),
    sd_n_empty_days = sd(n_empty_days)
  )

rpi_descriptives_path <- "../D_summarizing_data/rpi_descriptives.csv"
write.csv(rpi_descriptives, file = rpi_descriptives_path)

overall_descriptives_path <- "../D_summarizing_data/overall_descriptives.csv"
write.csv(overall_descriptives, file = overall_descriptives_path)










# I DON'T USE THIS ANYMORE! VVVVVVV ####
# Create an empty data frame to store the results
hourly_data <- data.frame()

for (datafile in datafiles) {
  # datafile <- "../C_processed_data/RG_230315_jackdaw2_processed.csv"
  data <- read.csv(datafile)
  print(paste("Working with file:", datafile))
  
  # Extract video basic information
  video_id <- sub(".*/(.*)_processed\\.csv$", "\\1", datafile)
  rpi_name <- strsplit(video_id, "_")[[1]][3]
  rpi_name <- format_rpi_id(rpi_name)
  # date <- strsplit(video_id, "_")[[1]][2]
  # date <- as.Date(date, format = "%y%m%d")
  idbox <- box_rpi_csv$idbox[box_rpi_csv$rpi == rpi_name][1]
  
  # data$complete_timestamp <- as.POSIXct(data$complete_timestamp)
  
  data <- data %>% 
    mutate(complete_timestamp = as.POSIXct(complete_timestamp),
           hour = format(complete_timestamp, "%H"),
           # date = date,
           rpi = rpi_name,
           video = video_id
           )
  
  # Extract hourly visit counts and time spent in the nest
  
  # Identify shifts in corrected_num_detections
  data <- data %>%
    distinct(complete_timestamp, corrected_num_detections, rpi) %>% 
    mutate(shift = ifelse(
      lag(corrected_num_detections, default = first(corrected_num_detections)) != corrected_num_detections,
      paste0("From_", lag(corrected_num_detections, default = first(corrected_num_detections)), "_to_", corrected_num_detections),
      NA
    )) %>% 
    mutate(shift_group = cumsum(!is.na(shift))) %>%
    group_by(shift_group) %>% 
    mutate(duration = as.numeric(difftime(max(complete_timestamp), 
                                          min(complete_timestamp),
                                          units = "secs"))) %>% 
    ungroup() %>% 
    
    # fill(shift, .direction = "down") %>% 
    subset(select = -c(corrected_num_detections)) %>% 
    merge(data, by = c("complete_timestamp", "rpi")) %>% 
    subset(select = -c(X))
    
  
  # # Count the number of each state change per hour
  # hourly_shifts <- data %>% 
  #   group_by(hour, shift, rpi) %>% 
  #   tally(name = "shift_count") %>% 
  #   spread(key = shift, value = shift_count, fill = 0) %>% 
  #   ungroup() %>% 
  #   subset(select = -c(9))
  # 
  # Count the frames with 0, 1 or 2 detections. Also the total recorded frames per h
  hourly_attendance <- data %>% 
    group_by(hour, rpi) %>% 
    summarise(
      first_state = corrected_num_detections[row_number() == 1],
      last_state = corrected_num_detections[row_number() == n()],
      attendance_0 = n_distinct(frame[corrected_num_detections == 0]),
      attendance_1 = n_distinct(frame[corrected_num_detections == 1]),
      attendance_2 = n_distinct(frame[corrected_num_detections == 2]),
      avg_head_change = mean(head_change, na.rm = TRUE),
      avg_body_change = mean(body_change, na.rm = TRUE),
      available_frames = n_distinct(frame)
    ) %>% 
    ungroup() #%>% 
    left_join(hourly_shifts, by = c("hour", "rpi"))
  
  # append data to the hourly_data and continue the loop
  hourly_data <- bind_rows(hourly_data, hourly_attendance)
  
  
}
# UNTIL HERE TTTTTTTTTTTTT####

##> BREEDING_STAGE <- summary of visitation and attendance for each breeding stage
##>     |_ rpi
##>     |_ Available data
##>     |_ Breeding_stage (nest_construction, incubation, 0-7d, 7-14d)
##>     |_ 
##>     
##>     
##>     Fer un model mixte per mirar intraclass coeficient.
##>     Per veure si hi ha diferencies entre caixes niu
##>     
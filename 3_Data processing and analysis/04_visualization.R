library(readr)
library(readxl)
library(ggplot2)
library(reshape2)
library(dplyr)
library(tidyr)
library(scales)
library(viridis)
library(patchwork)
source("G:/Mi unidad/Marçal's PhD/001_automated_jackdaw_monitoring/Z_scripts/functions.R")
setwd("G:/Mi unidad/Marçal's PhD/001_automated_jackdaw_monitoring/Z_scripts")

##> LOAD DATAFRAMES FOR PLOTTING ####
rpi_descriptives <- read_delim("G:/Mi unidad/Marçal's PhD/001_automated_jackdaw_monitoring/D_summarizing_data/rpi_descriptives.csv", 
                               delim = ";", 
                               escape_double = FALSE,
                               col_types = cols(rpi = col_double(),
                                                ...8 = col_skip()),
                               locale = locale(decimal_mark = ",",
                                               grouping_mark = "."),
                               trim_ws = TRUE)
# Ensure that rpi is treated as a factor and sorted numerically
rpi_descriptives$rpi <- factor(rpi_descriptives$rpi, levels = unique(rpi_descriptives$rpi))

overall_descriptives <- read_csv("G:/Mi unidad/Marçal's PhD/001_automated_jackdaw_monitoring/D_summarizing_data/overall_descriptives.csv", 
                                 col_types = cols(...1 = col_skip()))

visitation_data <- read.csv("../D_summarizing_data/visitation.csv")

visitation_attendance <- read_csv("../D_summarizing_data/visitaiton_attendance.csv")
visitation_attendance$date <- as.POSIXct(visitation_attendance$date)
visitation_attendance$rpi <- factor(visitation_attendance$rpi)

daily_data <- read.csv("../D_summarizing_data/daily_data.csv")

box_rpi_2023 <- read.csv("../B2_helper_data/box_rpi_2023.csv")

fitness_data <- read.csv("../B2_helper_data/fitness_data.csv", sep = ";", colClasses="character")
fitness_data <- fitness_data %>% 
  mutate(obsLD = as.Date(obsLD, format = "%d/%m/%Y"),
         obsHD = as.Date(obsHD, format = "%d/%m/%Y")) %>% 
  merge(box_rpi_2023, by = "idbox", all.x=TRUE) %>% 
  filter(!is.na(obsHD))

measures_R <- read_excel("../B2_helper_data/fitness_data.xlsx", sheet = "captures_R") %>% 
  merge(box_rpi_2023, by = "idbox", all.x=TRUE)


# Identify the positions where hd_date is 0
hd_zero_positions <- visitation_attendance %>%
  filter(hd_date == 0) %>%
  select(rpi, date, hd_date, ld_date)

ld_zero_positions <- visitation_attendance %>%
  filter(ld_date == 0) %>%
  select(rpi, date, hd_date, ld_date)

#visitation_attendance <- mutate_all(visitation_attendance, ~replace(., is.na(.), 0))


##> PLOT FITNESS DATA ####

# fitness_data <- fitness_data %>% 
#   mutate(across(all_of(c(7, 9, 10, 16)), as.numeric))
##> Do some data exploration on the fitness_data, to see variation between boxes
{
  # Boxplot for clutch size (ousTotals)
  clutch_size_plot <- ggplot(fitness_data, aes(x = "", y = ousTotals)) +
    geom_boxplot() +
    geom_jitter(aes(color = factor(idbox)), width = 0.2) +
    labs(title = "Clutch Size", y = "Clutch Size", x = NULL) +
    theme_minimal() +
    theme(legend.position = "none")
  
  # Boxplot for hatched eggs percentage (ousEclosionats*100/ousTotals)
  hatchlings_plot <- ggplot(fitness_data, aes(x = "", y = ousEclosionats)) +
    geom_boxplot() +
    geom_jitter(aes(color = factor(idbox)), width = 0.2) +
    labs(title = "n Hatchlings", y = "Hatched Eggs", x = NULL) +
    theme_minimal() +
    theme(legend.position = "none")
  
  hatching_success_plot <- ggplot(fitness_data, aes(x = "", y = ousEclosionats * 100 / ousTotals)) +
    geom_boxplot() +
    geom_jitter(aes(color = factor(idbox)), width = 0.2) +
    labs(title = "% Hatched Eggs", y = "Hatched Eggs (%)", x = NULL) +
    theme_minimal() +
    theme(legend.position = "none")
  
  # Boxplot for fledglings (volanders)
  fledglings_plot <- ggplot(fitness_data, aes(x = "", y = volanders)) +
    geom_boxplot() +
    geom_jitter(aes(color = factor(idbox)), width = 0.2) +
    labs(title = "n Fledglings", y = "Fledgling number", x = NULL) +
    theme_minimal() +
    theme(legend.position = "none")
  
  reproductive_success_plot <- ggplot(fitness_data, aes(x = "", y = volanders/ousEclosionats * 100)) +
    geom_boxplot() +
    geom_jitter(aes(color = factor(idbox)), width = 0.2) +
    labs(title = "% Reproductive success", y = "Fledgings/hatchlings (%)", x = NULL) +
    theme_minimal() +
    theme(legend.position = "none")
  
  # Boxplot for obsLD
  LD_plot <- ggplot(fitness_data, aes(x = "", y = obsLD)) +
    geom_boxplot() +
    geom_jitter(aes(color = factor(idbox)), width = 0.2) +
    labs(title = "Laying Date", y = "Laying date", x = NULL) +
    theme_minimal() +
    theme(legend.position = "none")
  
  
  # Boxplot for obsHD
  HD_plot <- ggplot(fitness_data, aes(x = "", y = obsHD)) +
    geom_boxplot() +
    geom_jitter(aes(color = factor(idbox)), width = 0.2) +
    labs(title = "Hatching Date", y = "Hatching date", x = NULL) +
    theme_minimal() +
    theme(legend.position = "none")
  
  
  # Boxplot for duration of incubation
  incubation_plot <- ggplot(fitness_data, aes(x = "", y = incubation)) +
    geom_boxplot() +
    geom_jitter(aes(color = factor(idbox)), width = 0.2) +
    labs(title = "Duration of incubation", y = "Incubation time (days)", x = NULL) +
    theme_minimal() +
    theme(legend.position = "none")
  
  }

# Combine plots into a single image
combined_plot <- clutch_size_plot + 
  hatchlings_plot + 
  hatching_success_plot +
  fledglings_plot +
  reproductive_success_plot +
  LD_plot + 
  HD_plot + 
  incubation_plot +
  plot_layout(ncol = 4)

# Plot histograms
##> Do some data exploration on the fitness_data, to see variation between boxes
{
  # Boxplot for clutch size (ousTotals)
  clutch_size_plot <- ggplot(fitness_data, aes(x = ousTotals)) +
    geom_histogram(binwidth=1) +
    geom_density() +
    labs(title = "Clutch Size", x = "Clutch Size") +
    theme_minimal() +
    theme(legend.position = "none")
  
  # Boxplot for hatched eggs percentage (ousEclosionats*100/ousTotals)
  hatchlings_plot <- ggplot(fitness_data, aes(x = ousEclosionats)) +
    geom_histogram(binwidth=1) +
    labs(title = "n Hatchlings", x = "Hatched Eggs") +
    theme_minimal() +
    theme(legend.position = "none")
  
  hatching_success_plot <- ggplot(fitness_data, aes(x = ousEclosionats * 100 / ousTotals)) +
    geom_histogram(binwidth=3) +
    # geom_jitter(aes(color = factor(idbox)), width = 0.2) +
    labs(title = "% Hatched Eggs", x = "Hatched Eggs (%)") +
    theme_minimal() +
    theme(legend.position = "none")
  
  # Boxplot for fledglings (volanders)
  fledglings_plot <- ggplot(fitness_data, aes(x = volanders)) +
    geom_histogram(binwidth=1) +
    labs(title = "n Fledglings", x = "Fledgling number") +
    theme_minimal() +
    theme(legend.position = "none")
  
  reproductive_success_plot <- ggplot(fitness_data, aes(x = volanders/ousEclosionats * 100)) +
    geom_histogram(binwidth=1) +
    labs(title = "% Reproductive success", x = "Fledgings/hatchlings (%)") +
    theme_minimal() +
    theme(legend.position = "none")
  
  # Boxplot for obsLD
  LD_plot <- ggplot(fitness_data, aes(x = obsLD)) +
    geom_histogram(binwidth=1) +
    labs(title = "Laying Date", x = "Laying date") +
    theme_minimal() +
    theme(legend.position = "none")
  
  
  # Boxplot for obsHD
  HD_plot <- ggplot(fitness_data, aes(x = obsHD)) +
    geom_histogram(binwidth=1) +
    labs(title = "Hatching Date", x = "Hatching date") +
    theme_minimal() +
    theme(legend.position = "none")
  
  
  # Boxplot for duration of incubation
  incubation_plot <- ggplot(fitness_data, aes(x = incubation)) +
    geom_histogram(binwidth=1) +
    labs(title = "Duration of incubation", x = "Incubation time (days)") +
    theme_minimal() +
    theme(legend.position = "none")
  }
# hist(fitness_data$ousEclosionats/fitness_data$ousTotals)
# hist(fitness_data$volanders/fitness_data$ousEclosionats)

# Combine plots into a single image
combined_plot <- clutch_size_plot + 
  hatchlings_plot + 
  hatching_success_plot +
  fledglings_plot +
  reproductive_success_plot +
  LD_plot + 
  HD_plot + 
  incubation_plot +
  plot_layout(ncol = 4)


# Display the combined plot
print(combined_plot)


##> Plot chick grouth from all boxes in RG
{
  # Reshape the data to long format
  data_long <- fitness_data %>%
    pivot_longer(cols = c(ousTotals, ousEclosionats, volanders),
                 names_to = "stage",
                 values_to = "count")
  
  # Relabel stages for better readability
  data_long$stage <- factor(data_long$stage, levels = c("ousTotals", "ousEclosionats", "volanders"),
                            labels = c("Clutch Size", "Hatched Eggs", "Fledglings"))
  
  # Create a unique ID for each combination of idbox and posta
  data_long$idbox_posta <- interaction(data_long$idbox, data_long$posta, sep = "_")
  
  # Create the plot
  ggplot(data_long, aes(x = stage, y = count, group = idbox_posta, color = factor(idbox))) +
    geom_line(size = 1) +
    geom_point() +
    geom_boxplot(aes(group = stage), alpha = 0.3, width = 0.5) +  # Add boxplots
    labs(title = "Variation in Clutch Size, Hatched Eggs, and Fledglings",
         x = "Stage",
         y = "Count",
         color = "ID Box") +
    theme_minimal()
  
  
  # Convert obsLD and obsHD to Date, handling NA values
  measures_R$data <- as.Date(measures_R$data)
  
  # Handle missing values in box_rpi_2023
  box_rpi_2023 <- box_rpi_2023 %>%
    mutate_all(na_if,"")
  
  measures_R <- measures_R %>% 
    filter(!is.na(rpi))
  #   left_join(box_rpi_2023, by = "idbox")
  
  
  
  # Plot for chick grouth
  levels=c("ou", "1 dia", "7 dies", "14 dies", "21 dies")
  chick_grouth <- ggplot(measures_R, 
                         aes(x = factor(edat, level = levels), 
                             y = pes, 
                             group = id_individu, 
                             color = factor(id_individu)
                         )
  ) +
    geom_line() +
    geom_point() +
    facet_wrap(~ idbox) +
    labs(title = "Weight of Individuals at Different Ages",
         x = "Age",
         y = "Weight",
         color = "Individual ID") +
    theme_minimal() +
    theme(legend.position = "botom")
  
  chick_grouth
}

##> Boxplot for chick grouth
{
  # Define a function to generate the boxplot for each age
  plot_weight_by_age <- function(measures_R, age, rpi_colors) {
    # Filter the data for the specified age
    measures_r <- measures_R %>% 
      filter(edat == paste(age, "dies")) %>% 
      group_by(rpi) %>% 
      mutate(chicks = n_distinct(id_individu)) %>% 
      ungroup()
    
    # Order `rpi` based on median `pes`
    ordered_levels <- measures_r %>%
      group_by(rpi) %>%
      summarize(median_pes = median(pes, na.rm = TRUE)) %>%
      arrange(desc(median_pes)) %>%
      pull(rpi)
    
    # Convert `rpi` to a factor with ordered levels
    measures_r <- measures_r %>%
      mutate(rpi = factor(rpi, levels = ordered_levels))
    
    # Create the plot with consistent colors
    plot <- ggplot(measures_r, aes(x = rpi, y = pes, color = rpi)) +
      geom_boxplot(aes(group = rpi)) +
      geom_jitter(aes(group = rpi), width = 0.2) +
      labs(title = paste("Weight at", age, "days"), y = "pes/chicks", x = NULL) +
      scale_color_manual(values = rpi_colors) +  # Apply consistent colors
      theme_minimal() +
      theme(legend.position = "none")
    
    return(plot)
  }
  
  # Get the unique `rpi` values and create a consistent color palette
  unique_rpis <- unique(measures_R$rpi)
  rpi_colors <- viridis(length(unique_rpis))  # Use viridis color palette
  
  # Assign colors to each unique rpi
  names(rpi_colors) <- unique_rpis
  
  # Generate plots for each age with consistent colors
  ages <- c(7, 14, 21)
  plots <- lapply(ages, function(age) plot_weight_by_age(measures_R, age, rpi_colors))
  
  # Display the plots
  print(plots[[1]])  # 7 days
  print(plots[[2]])  # 14 days
  print(plots[[3]])  # 21 days
}
# Create an animation for this boxplot
library(gganimate)
{
  measures_r <- measures_R %>%
    filter(edat %in% c("1 dia", "7 dies", "14 dies", "21 dies", "ou")) %>%
    mutate(age_days = case_when(
      edat == "1 dia" ~ 1,
      edat == "7 dies" ~ 7,
      edat == "14 dies" ~ 14,
      edat == "21 dies" ~ 21,
      edat == "ou" ~ 0  # Assign 0 for "ou" (other)
    ))
  
  # Ensure we still have the unique rpi values and consistent color palette
  unique_rpis <- unique(measures_r$rpi)
  rpi_colors <- viridis(length(unique_rpis))  # Use viridis color palette
  names(rpi_colors) <- unique_rpis
  
  # Order rpi based on median weight at each age
  measures_r <- measures_r %>%
    group_by(age_days, rpi) %>%
    mutate(median_pes = median(pes, na.rm = TRUE)) %>%
    arrange(age_days, desc(median_pes)) %>%
    ungroup() %>%
    mutate(rpi = factor(rpi, levels = unique(rpi)))  # Ensure `rpi` is a factor
  
  # Create the animated plot, now including "ou" and "1 dia"
  animated_plot <- ggplot(measures_r, aes(x = rpi, y = pes, color = rpi)) +
    geom_boxplot(aes(group = rpi)) +
    geom_jitter(aes(group = rpi), width = 0.2) +
    scale_color_manual(values = rpi_colors) +  # Apply consistent colors
    labs(title = "Weight of chicks over time", y = "Weight (pes)", x = NULL) +
    theme_minimal() +
    theme(legend.position = "none") +
    transition_states(age_days, transition_length = 3, state_length = 0.5) +  # Animate over age_days
    labs(title = 'Weight at {ifelse(closest_state == 0, "ou", paste(closest_state, "day"))}') +
    ease_aes('sine-in-out')  # Smooth transition
  
  # Render the animation
  anim <- animate(animated_plot, renderer = gifski_renderer(), width = 800, height = 600)
  anim
  # Save the animation to GIF file
  anim_save("../E_visualization/fitness/chick_weight_evolution.gif", animation = anim)

}


##> PLOT DATA AVAILABILITY ####

# Ensure 'date' is in Date format and 'hour' is in numeric format
visitation_attendance <- visitation_attendance %>%
  mutate(date = as.Date(date),
         hour = as.numeric(hour))

# Create the plot
ggplot(visitation_attendance, aes(x = date, y = hour, fill = available_frames)) +
  geom_tile() +
  scale_fill_gradient(low = "white", high = "grey30", limits = c(0, 3600)) +
  geom_vline(data = visitation_attendance[visitation_attendance$ld_date == 0,], 
             aes(xintercept = date),
             color = "skyblue", size = 1) +
  geom_vline(data = visitation_attendance[visitation_attendance$hd_date == 0,], 
             aes(xintercept = date),
             color = "pink", size = 1) +
  # scale_fill_viridis(discrete = FALSE, direction = -1, limits = c(0, 3600)) +
  scale_y_continuous(breaks = seq(0, 23, by = 5)) +
  labs(title = "Data Availability Heatmap", x = "Date", y = "Hour", fill = "Data Available") +
  scale_x_date(labels = date_format("%b %d"), expand = c(0, 0)) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  facet_wrap(~rpi)

# Create the plot
ggplot(visitation_attendance, aes(x = date, y = available_frames)) +
  geom_step() +
  geom_vline(data = visitation_attendance[visitation_attendance$ld_date == 0,], 
             aes(xintercept = date),
             color = "skyblue", size = 1) +
  geom_vline(data = visitation_attendance[visitation_attendance$hd_date == 0,], 
             aes(xintercept = date),
             color = "pink", size = 1) +
  # scale_fill_viridis(discrete = FALSE, direction = -1, limits = c(0, 3600)) +
  # scale_y_continuous(breaks = seq(0, 23, by = 5)) +
  labs(title = "Data Availabile", x = "Date", y = "% recorded") +
  scale_x_date(labels = date_format("%b %d"), expand = c(0, 0)) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  facet_wrap(~rpi)

ggsave("../E_visualization/data_availability.jpg", width = 2940, height = 1675, units = "px")


##> PLOT DATA DESCRIPTIVES
# Loop over the columns (excluding the 'rpi' column) to create a bar plot for each variable
for (col in names(rpi_descriptives)[-1]) {
  p <- ggplot(rpi_descriptives, aes(x = rpi, y = rpi_descriptives[[col]])) +
    geom_bar(stat = "identity", fill = "steelblue") +
    theme_minimal() +
    labs(title = paste("Barplot of", col, "by RPi"),
         x = "RPi",
         y = col) +
    # theme(axis.text.x = element_text(angle = 90, hjust = 1)) + # Rotate x labels vertically for better readability
    scale_x_discrete(labels = rpi_descriptives$rpi)
  print(p)
}

##> PLOT ATTENDANCE #####
# Define parameters for plotting:
span = 0.1

# Attendance by more than 0 individuals at -100:16 hd_date

# Define a list with the plot configurations
plot_configs <- list(
  list(attendance = "both", title = "Daily presence of jackdaws in the nest (%)", filename = "../E_visualization/Attendance_gt0"),
  list(attendance = "attendance_2", title = "Daily presence of 2 jackdaws in the nest (%)", filename = "../E_visualization/Attendance_2"),
  list(attendance = "attendance_1", title = "Daily presence of only 1 jackdaw in the nest (%)", filename = "../E_visualization/Attendance_1")
)

# Loop through each configuration to create and save plots
for (config in plot_configs) {
  # Subset data
  data <- subset(visitation_attendance, hd_date %in% -100:16)
  
  # Calculate y_ based on attendance type
  if (config$attendance == "both") {
    y_ <- ((data$attendance_1 + data$attendance_2) / data$available_frames) * 100
  } else {
    y_ <- (data[[config$attendance]] / data$available_frames) * 100
  }
  
  # Create the plots and save
  plot_calendar_date(data, y_, span = span, config$title, "Daily attendance (%)")
  ggsave(paste(config$filename, ".jpg"), width = 2940, height = 1675, units = "px")
  
  plot_rel_ld(data, y_, span = span, paste(config$title, " (rel_ld)"), "Daily attendance (%)")
  ggsave(paste(config$filename, "_ld.jpg"), width = 2940, height = 1675, units = "px")
  
  plot_rel_hd(data, y_, span = span, paste(config$title, " (rel_hd)"), "Daily attendance (%)")
  ggsave(paste(config$filename, "_hd.jpg"), width = 2940, height = 1675, units = "px")
  
}

##> PLOT VISITATION #####
# Define a list with the plot configurations
plot_configs <- list(
  list(y_ = data$visits_0_gt0, title = "Daily visitation rate of jackdaws", filename = "../E_visualization/Visits_0_gt0"),
  list(y_ = data$visits_1_2, title = "Daily visitation rate of a 2nd jackdaw when there was 1 already", filename = "../E_visualization/Visits_1_2"),
  list(y_ = data$visits_0_1, title = "Daily visitation rate of only 1 jackdaw", filename = "../E_visualization/Visits_0_1")
)

# Loop through each configuration to create and save plots
for (config in plot_configs) {
  # Subset data
  data <- subset(visitation_attendance, hd_date %in% -100:16)
  
  # Create the plots and save
  plot_calendar_date(data, config$y_, span = span, config$title, "Visitation rate: mean(visits/hour)")
  ggsave(paste(config$filename, ".jpg"), width = 2940, height = 1675, units = "px")
  
  plot_rel_ld(data, config$y_, span = span, paste(config$title, " (rel_ld)"), "Visitation rate: mean(visits/hour)")
  ggsave(paste(config$filename, "_ld.jpg"), width = 2940, height = 1675, units = "px")
  
  plot_rel_hd(data, config$y_, span = span, paste(config$title, " (rel_hd)"), "Visitation rate: mean(visits/hour)")
  ggsave(paste(config$filename, "_hd.jpg"), width = 2940, height = 1675, units = "px")
}


##> PLOT VISIT DURATION #####
# Define a list with the plot configurations
plot_configs <- list(
  list(y_ = data$mean_duration_gt0, y_n = "gt0", title = "Mean duration of visits of jackdaws", filename = "../E_visualization/mean_duration_gt0"),
  list(y_ = data$mean_duration_1_2, y_n = "1_2", title = "Mean duration of visits of a 2nd jackdaw when there was 1 already", filename = "../E_visualization/mean_duration_1_2"),
  list(y_ = data$mean_duration_0_1, y_n = "0_1", title = "Mean duration of visits of only 1 jackdaw", filename = "../E_visualization/mean_duration_0_1")
)

# Loop through each configuration to create and save plots
for (config in plot_configs) {
  # Subset data
  data <- subset(visitation_attendance, hd_date %in% -100:16)
  
  # Calculate y_ based on attendance type
  if (config$y_n == "gt0") {
    y_lim <- 1500
  } else {
    if (config$y_n == "1_2") {
      y_lim <- 200
    } else {
      y_lim <- 600}
  }
  
  # Create the plots and save
  plot_calendar_date(data, config$y_, span = span, config$title, "Duration (seconds)", y_percent = FALSE, ylim = y_lim)
  ggsave(paste(config$filename, ".jpg"), width = 2940, height = 1675, units = "px")
  
  plot_rel_ld(data, config$y_, span = span, paste(config$title, " (rel_ld)"), "Duration (seconds)", y_percent = FALSE, ylim = y_lim)
  ggsave(paste(config$filename, "_ld.jpg"), width = 2940, height = 1675, units = "px")
  
  plot_rel_hd(data, config$y_, span = span, paste(config$title, " (rel_hd)"), "Duration (seconds)", y_percent = FALSE, ylim = y_lim)
  ggsave(paste(config$filename, "_hd.jpg"), width = 2940, height = 1675, units = "px")
}




# distribution of attendance by gt0 individuals in the day at each breeding_stage
breeding_stages <- unique(visitation_attendance$breeding_stage)
for (b_stage in breeding_stages) {
  data <- subset(visitation_attendance, breeding_stage == b_stage)
  
  ggplot(data = data,
         aes(x = hour, 
             y = ((attendance_1 + attendance_2) / available_frames) * 100,
             group = rpi)) +
    labs(title = paste("Attendance by >0 jackdaws during", b_stage),
         x = "Hour",
         y = "Attendance/available_frames*100") + 
    geom_jitter(size = 0.2, color = "grey90") +
    geom_smooth(aes(color=rpi),
                method = "loess",
                span = span, se = FALSE) +
    theme_minimal() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          axis.line = element_line(colour = "black")) +
    scale_color_viridis_d() +
    scale_x_continuous(expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, 100), expand = c(0, 0))
  
  # Generate the filename for saving
  filename <- paste0("../E_visualization/Attendance_gt0_", gsub(" ", "_", b_stage), ".jpg")
  ggsave(filename, width = 2940, height = 1675, units = "px")
}

# Distribution of attendance by 2 individuals in the day at each breeding_stage
for (b_stage in breeding_stages) {
  data <- subset(visitation_attendance, breeding_stage == b_stage)
  
  ggplot(data = data,
         aes(x = hour, 
             y = ((attendance_2) / available_frames) * 100,
             group = rpi)) +
    labs(title = paste("Attendance by 2 jackdaws during", b_stage),
         x = "Hour",
         y = "Attendance_2/available_frames*100") +
    geom_jitter(size = 0.2, color = "grey90") +
    geom_smooth(aes(color=rpi),
                method = "loess",
                span = span, se = FALSE) +
    theme_minimal() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          axis.line = element_line(colour = "black")) +
    scale_color_viridis_d() +
    scale_x_continuous(expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, 100), expand = c(0, 0))
  
  filename <- paste0("../E_visualization/Attendance_2_", gsub(" ", "_", b_stage), ".jpg")
  ggsave(filename, width = 2940, height = 1675, units = "px")
}

# Distribution of attendance by 1 individual in the day at each breeding_stage
for (b_stage in breeding_stages) {
  data <- subset(visitation_attendance, breeding_stage == b_stage)
  
  ggplot(data = data,
         aes(x = hour, 
             y = ((attendance_1) / available_frames) * 100,
             group = rpi)) +
    labs(title = paste("Attendance by 1 jackdaw during", b_stage),
         x = "Hour",
         y = "Attendance_1/available_frames*100") + 
    geom_jitter(size = 0.2, color = "grey90") +
    geom_smooth(aes(color=rpi),
                method = "loess",
                span = span, se = FALSE) +
    theme_minimal() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          axis.line = element_line(colour = "black")) +
    scale_color_viridis_d() +
    scale_x_continuous(expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, 100), expand = c(0, 0))
  
  filename <- paste0("../E_visualization/Attendance_1_", gsub(" ", "_", b_stage), ".jpg")
  ggsave(filename, width = 2940, height = 1675, units = "px")
}

for (b_stage in breeding_stages) {
  data <- subset(visitation_attendance, breeding_stage == b_stage)
  
  ggplot(data = data,
         aes(x = ld_date, 
             y = ((visits_0_gt0) / available_frames) * day_length,
             group = rpi)) +
    labs(title = paste("Visits by >0 jackdaw during", b_stage),
         x = "Date relative to laying date",
         y = "visits_0_gto0/available_frames*day_length") + 
    geom_jitter(size = 0.2, color = "grey90") +
    geom_smooth(aes(color=rpi),
                method = "loess",
                span = span, se = FALSE) +
    theme_minimal() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          axis.line = element_line(colour = "black")) +
    scale_color_viridis_d() +
    scale_x_continuous(expand = c(0, 0)) +
    scale_y_continuous(expand = c(0, 0))
  
  filename <- paste0("../E_visualization/visits_0_gt0_", gsub(" ", "_", b_stage), ".jpg")
  ggsave(filename, width = 2940, height = 1675, units = "px")
}

# Time over eggs by rpi during incubation period at -10:30 ld_date relative to ld
ggplot(data = subset(visitation_attendance, ld_date %in% -10:30),
       aes(x = ld_date, 
           y = (on_eggs/available_frames)*100,
           group = rpi)) +
  labs(title = "Daily time with a jackdaw on the eggs area (incubation)",
       x = "Date relative to the laying date",
       y = "Daily time on the eggs (%)") + 
  geom_jitter(size = 0.2, color = "grey90") +
  geom_vline(xintercept = ld_zero_positions[["ld_date"]], 
             color = "skyblue", size = 0.7) +
  geom_vline(xintercept = hd_zero_positions[["ld_date"]], 
             color = "pink", size = 0.7) +
  # geom_smooth(method = "gam", formula = y ~ s(x, bs = "cs"), aes(color=rpi), span = 0.4, se = FALSE) +
  geom_smooth(aes(color=rpi),
              method = "loess",
              span = span, se = FALSE) +
  theme_minimal() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(colour = "black")) +
  scale_color_viridis_d() +
  scale_x_continuous(expand = c(0, 0)) +
  scale_y_continuous(limits = c(0,100), expand = c(0, 0)) # Start y-axis at zero
# scale_x_datetime(date_breaks = "15 days")

ggsave("../E_visualization/on_eggs_ld.jpg", width = 2940, height = 1675, units = "px")

# Time over eggs by rpi relative to attendance_gt0 during incubation period at -10:30 ld_date relative to ld
ggplot(data = subset(visitation_attendance, ld_date %in% -10:30),
       aes(x = ld_date, 
           y = (on_eggs/attendance_gt0)*100,
           group = rpi)) +
  labs(title = "Attended time with a jackdaw on the eggs area (incubation)",
       x = "Date relative to the laying date",
       y = "Attended time on the eggs (%)") + 
  geom_jitter(size = 0.2, color = "grey90") +
  geom_vline(xintercept = ld_zero_positions[["ld_date"]], 
             color = "skyblue", size = 0.7) +
  geom_vline(xintercept = hd_zero_positions[["ld_date"]], 
             color = "pink", size = 0.7) +
  # geom_smooth(method = "gam", formula = y ~ s(x, bs = "cs"), aes(color=rpi), span = 0.4, se = FALSE) +
  geom_smooth(aes(color=rpi),
              method = "loess",
              span = 0.4, se = FALSE) +
  theme_minimal() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(colour = "black")) +
  scale_color_viridis_d() +
  scale_x_continuous(expand = c(0, 0)) +
  scale_y_continuous(limits = c(0,100), expand = c(0, 0)) # Start y-axis at zero
# scale_x_datetime(date_breaks = "15 days")

ggsave("../E_visualization/attended_on_eggs_ld.jpg", width = 2940, height = 1675, units = "px")

ggplot(data = fitness_data, aes(x = idbox, y = volanders/ousEclosionats)) +
  geom_point()
plot(fitness_data$volanders/fitness_data$ousEclosionats, colour = fitness_data$idbox)

# Time at door by rpi during incubation period at -10:30 ld_date relative to ld
ggplot(data = subset(visitation_attendance, ld_date %in% -10:30),
       aes(x = ld_date, 
           y = (at_door/available_frames)*100,
           group = rpi)) +
  labs(title = "Daily time with a jackdaw at the nest door",
       x = "Date relative to the laying date",
       y = "Daily time at the nest door (%)") + 
  geom_jitter(size = 0.2, color = "grey90") +
  geom_vline(xintercept = ld_zero_positions[["ld_date"]], 
             color = "skyblue", size = 0.7) +
  geom_vline(xintercept = hd_zero_positions[["ld_date"]], 
             color = "pink", size = 0.7) +
  geom_smooth(aes(color=rpi),
              method = "loess",
              span = 0.3, se = FALSE) +
  theme_minimal() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(colour = "black")) +
  scale_color_viridis_d() +
  scale_x_continuous(expand = c(0, 0)) +
  scale_y_continuous(limits = c(0,100), expand = c(0, 0)) # Start y-axis at zero
# scale_x_datetime(date_breaks = "15 days")

ggsave("../E_visualization/at_door_ld.jpg", width = 2940, height = 1675, units = "px")

# head_change at -10:30 ld_date relative to ld
ggplot(data = subset(visitation_attendance, ld_date %in% 0:18),
       aes(x = hour, 
           y = mean_head_change,
           group = rpi)) +
  labs(title = "Mean head movement during incubation",
       x = "Hour",
       y = "mean_head_change") + 
  geom_jitter(size = 0.2, color = "grey90") +
  # geom_vline(xintercept = ld_zero_positions[["ld_date"]], 
  #            color = "skyblue", size = 0.7) +
  # geom_vline(xintercept = hd_zero_positions[["ld_date"]], 
  #            color = "pink", size = 0.7) +
  geom_smooth(aes(color=rpi),
              method = "loess",
              span = 1, se = FALSE) +
  theme_minimal() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(colour = "black")) +
  scale_color_viridis_d() +
  scale_x_continuous(expand = c(0, 0)) +
  scale_y_continuous(limits = c(0,50), expand = c(0, 0)) # Start y-axis at zero
# scale_x_datetime(date_breaks = "15 days")

ggsave("../E_visualization/body_change_ld.jpg", width = 2940, height = 1675, units = "px")






# USE COMPUTED VARIABLES TO SHOW RELATION ACROSS BEHAVIOURAL METRICS ####
computed_data <- computed_data %>%
  mutate(interersting_period = as.character(interesting_period)) %>% 
  arrange(factor(interesting_period, levels = c("nc", "inc", "b_ld", "cc", "inc", "1week_h", "2week_h")))

data <- computed_data %>% 
  merge(fitness_data, by=c("rpi", "idbox"), all.x =  TRUE) %>% 
  mutate(ousEclosionats = as.numeric(ousEclosionats),
         volanders = as.numeric(volanders))

# Attendance at all periods
ggplot(data = data %>% 
         filter(interesting_period %in% c("nc","b_ld", "cc", "inc","1week_h", "2week_h")),
       aes(x = factor(interesting_period, levels = c("nc","b_ld", "cc", "inc","1week_h", "2week_h")),
           y = attendance_gt0/available_frames*100,
           group = rpi,
           color = rpi)) +
  labs(title = "Mean attendance in the nest box during different periods",
       x = "Period",
       y = "attendance_gt0/available_frames") + 
  geom_point() +
  geom_line(size = 1) +
  scale_x_discrete(c("nc","b_ld", "cc", "inc","1week_h", "2week_h")) +
  theme_minimal() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(colour = "black")) +
  scale_color_viridis_d() +
  scale_x_discrete(expand = c(0.02, 0.02)) # Start y-axis at zero

ggsave("../E_visualization/periods_all_attendance.jpg", width = 2940, height = 1675, units = "px")

# Attendance on 3 periods
ggplot(data = data %>% 
         filter(interesting_period %in% c("b_ld", "1week_h", "2week_h")),
       aes(x = factor(interesting_period, levels = c("b_ld", "1week_h", "2week_h")),
           y = attendance_gt0/available_frames*100,
           group = rpi,
           color = rpi)) +
  labs(title = "Mean attendance in the nest box during different periods",
       x = "Period",
       y = "attendance_gt0/available_frames") + 
  geom_point() +
  geom_line(size = 1) +
  scale_x_discrete(c("b_ld", "1week_h", "2week_h")) +
  theme_minimal() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(colour = "black")) +
  scale_color_viridis_d() +
  scale_x_discrete(expand = c(0.02, 0.02)) # Start y-axis at zero

ggsave("../E_visualization/periods_attendance.jpg", width = 2940, height = 1675, units = "px")




# Plot on_eggs with duration of the incubation period
ggplot(data = data %>% 
         filter(interesting_period == "inc") %>%
         mutate(incubation = as.numeric(incubation)),
       aes(x = as.Date(obsLD),
           y = on_eggs/available_frames*100)) +
  geom_point(size = 3) +
  # geom_line(size = 1) +
    geom_smooth(method = "lm", se = TRUE) +
  labs(title = "Time on eggs compared to duration of incubation period",
       x = "Incubation period duration",
       y = "Time spent on eggs") + 
  theme_minimal() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(colour = "black")) +
  scale_color_viridis_d() 
  scale_x_discrete(expand = c(0.02, 0.02)) # Start y-axis at zero

# Plot laying date with duration of the incubation period
ggplot(data = data %>% 
         filter(interesting_period %in% c("1week_h")) %>%
         mutate(incubation = as.numeric(incubation),
                ousTotals = as.numeric(ousTotals),
                ousEclosionats = as.numeric(ousEclosionats),
                volanders = as.numeric(volanders)),
       aes(y = attendance_gt0/available_frames*100,
           x = volanders)) +
  geom_point(size = 3) +
  # geom_line(size = 1) +
  geom_smooth(method = "lm", se = TRUE) +
  labs(title = "Mean attendance of 1st week after HD depending on number of fledglings",
       x = "Number of fledglings",
       y = "Mean nest attendance during 1st week after the hatching date (%)") +
  theme_minimal() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(colour = "black")) +
  scale_color_viridis_d() +
  # coord_fixed(ratio = 1, xlim = c(0,100), ylim = c(0,100))
  # scale_x_date(date_labels = "%d-%m", date_breaks = "3 day", expand = c(0.02, 0.02))
  scale_x_continuous(expand = c(0.02, 0.02))

ggsave("../E_visualization/attendance_gt0_fledglings_1week_h.jpg", width = 2940, height = 1675, units = "px")


# Plot attendance_gt0 depending of fledgling number
ggplot(data = data %>% 
         filter(interesting_period == "inc") %>%
         mutate(incubation = as.numeric(incubation)),
       aes(x = volanders/as.numeric(ousEclosionats)*100,
           y = mean_duration_0))+ #/available_frames*100)) +
  geom_point(size = 3) +
  # geom_line(size = 1) +
  geom_smooth(method = "lm", se = TRUE) +
  # labs(title = "Attendance during 1week_h depending on number of fledglings",
  #      x = "Fledglings",
  #      y = "Attendance in the nest (%)") + 
  # scale_x_discrete("b_ld") +
  theme_minimal() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(colour = "black")) +
  scale_color_viridis_d() +
  scale_x_continuous(expand = c(0.02, 0.02))

with(data = data %>% 
         filter(interesting_period == "1week_h") %>% 
         mutate(incubation = as.numeric(incubation)),
     cor.test(x = mean_duration_0,
     y = attendance_gt0/available_frames*100))
  


# Plot attendance_gt0 depending of fledgling number
ggplot(data = data %>% 
         filter(interesting_period == "nc") %>% 
         mutate(incubation = as.numeric(incubation)),
       aes(x = volanders/as.numeric(ousEclosionats)*100,
           y = mean_duration_0))+ #/available_frames*100)) +
  geom_point(size = 3) +
  # geom_line(size = 1) +
  geom_smooth(method = "lm", se = TRUE) +
  # labs(title = "Attendance during 1week_h depending on number of fledglings",
  #      x = "Fledglings",
  #      y = "Attendance in the nest (%)") + 
  scale_x_discrete("b_ld") +
  theme_minimal() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(colour = "black")) +
  scale_color_viridis_d() +
  scale_x_continuous(expand = c(0.02, 0.02))

# Plot attendance_gt0 at 1week_h depending of reproductive success
ggplot(data = data %>% 
         filter(interesting_period == "1week_h") %>% 
         mutate(incubation = as.numeric(incubation)),
       aes(x = volanders/ousEclosionats*100,
           y = attendance_gt0/available_frames*100)) +
  geom_point(size = 3) +
  # geom_line(size = 1) +
  geom_smooth(method = "lm", se = TRUE) +
  labs(title = "Attendance during 1week_h and reproductive success",
       x = "Fledglings/hatchlings*100",
       y = "Attendance in the nest (%)") + 
  scale_x_discrete("b_ld") +
  theme_minimal() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(colour = "black")) +
  scale_color_viridis_d() +
  scale_x_continuous(expand = c(0.02, 0.02))

# Available frames at every period
ggplot(data = computed_data %>% 
         filter(interesting_period %in% c("b_ld", "1week_h", "2week_h")),
       aes(x = factor(interesting_period, levels = c("b_ld", "1week_h", "2week_h")),
           y = available_frames,
           group = rpi,
           color = rpi)) +
  labs(title = "Available frames on different periods",
       x = "Period",
       y = "Available frames") + 
  geom_point() +
  geom_line(size = 1) +
  scale_x_discrete(c("nc", "b_ld", "cc", "inc", "1week_h", "2week_h")) +
  theme_minimal() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(colour = "black")) +
  scale_color_viridis_d() +
  scale_x_discrete(expand = c(0.02, 0.02)) # Start y-axis at zero


selected_columns <- c(7, 9, 10, 13, 14, 16)
col_names <- colnames(fitness_data)[selected_columns]

# Convert selected columns to character to avoid type conflicts
fitness_data_long <- fitness_data %>%
  mutate(across(all_of(col_names), as.character)) %>%
  pivot_longer(cols = all_of(col_names), names_to = "variable", values_to = "value")

# Plot using ggplot2 with facet_wrap, converting values to numeric in the plot
ggplot(fitness_data_long, aes(x = variable, y = as.numeric(value))) +
  geom_boxplot() +
  facet_wrap(~ variable, scales = "free") +
  theme_minimal() +
  labs(title = "Boxplots of Selected Fitness Data Columns",
       x = "Variable",
       y = "Value")









#---------------------------------------------------------------------



plgeom_point()
plot_list <- lapply(unique(visitation_attendance$breeding_stage), function(b_stage) {
  ggplot(data = subset(visitation_attendance, breeding_stage == b_stage),
         aes(x = hour, 
             y = ((attendance_1 + attendance_2) / available_frames) * 100,
             group = rpi)) +
    labs(title = paste("Attendance by >0 jackdaws during", b_stage),
         x = "Hour",
         y = "Attendance/available_frames*100") + 
    geom_smooth(aes(color = rpi), span = 0.4, se = FALSE) +
    theme_minimal() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          axis.line = element_line(colour = "black")) +
    scale_color_viridis_d() +
    scale_x_continuous(expand = c(0, 0)) +
    scale_y_continuous(limits = c(0, 100), expand = c(0, 0))
  
  ggsave(paste0("../E_visualization/Attendance_gt0_", b_stage, ".jpg"))
  
})
print(plot_list[[1]])
ggplot(data = subset(visitation_attendance, breeding_stage %in% "nest_construciton"),
       aes(x = hour, 
           y = (attendance_1+attendance_2/available_frames)*100,
           group = rpi)) +
  labs(title = "Attendance by >0 jackdaws during nest construction",
       x = "Laying date",
       y = "attendance_0/available_frames*100") + 
  geom_smooth(aes(color=rpi), span = 0.4, se = FALSE) +
  geom_vline(xintercept = ld_zero_positions[["ld_date"]], 
             color = "grey90") +
  geom_vline(xintercept = hd_zero_positions[["ld_date"]], 
             color = "pink") + 
  theme_minimal() +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.line = element_line(colour = "black")) +
  scale_color_viridis_d() +
  scale_x_continuous(expand = c(0, 0)) +
  scale_y_continuous(limits = c(0,100), expand = c(0, 0)) # Start y-axis at zero
# scale_x_datetime(date_breaks = "15 days")

ggsave("../E_visualization/Attendance_2_ld.jpg")

















# NOT USED STUFF TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT


ggplot(data = subset(visitation_attendance, ld_date %in% c(-10:0)), 
            aes(x = hour, 
                y = ((attendance_1 + attendance_2)/available_frames)*100,
                group = rpi)) +
  labs(title = "Attendance by >0 jackdaws at 1week_h",
       x = "Hour",
       y = "Attendance/available_frames*100") + 
  geom_smooth(aes(color=rpi), span = 0.3, se = FALSE) +
  custom_theme() +
  scale_color_viridis_d()
  scale_y_continuous(expand = c(0, 0)) +  # Start y-axis at zero
  scale_x_discrete(expand = c(0, 0)) + # Start x-axis at zero

# Attendance by more than 0 individuals at 2week_h stage
ggplot(data = subset(visitation_attendance, breeding_stage %in% c("2week_h")), 
       aes(x = hour, 
           y = ((attendance_1 + attendance_2)/available_frames)*100,
           group = rpi)) + 
  labs(title = "Attendance by >0 jackdaws at 2week_h",
       x = "Hour",
       y = "Attendance/available_frames*100") +
  geom_smooth(method=loess, aes(color=rpi), se = FALSE)

# Attendance by more than 0 individuals at 3week_h stage
ggplot(data = subset(visitation_attendance, breeding_stage %in% c("3week_h")), 
       aes(x = hour, 
           y = ((attendance_1 + attendance_2)/available_frames)*100,
           group = rpi)) + 
  labs(title = "Attendance by >0 jackdaws at 3week_h",
       x = "Hour",
       y = "Attendance/available_frames*100") +
  geom_smooth(method=loess, aes(color=rpi), se = FALSE)


# Attendance by 2 individuals at a specific day in the calendar
ggplot(data = subset(visitation_attendance, rec_date %in% 31), 
       aes(x = hour, 
           y = ((attendance_2)/available_frames)*100,
           group = rpi)) + 
  labs(title = "Attendance by 2 jackdaws at rec_date=31",
       x = "Hour",
       y = "Attendance_2/available_frames*100") +
  geom_smooth(method=loess, aes(color=rpi), se = FALSE)

# Attendance by 2 individuals at a specific day in the calendar
ggplot(data = visitation_attendance, 
       aes(x = hd_date, 
           y = visits_1_2/available_frames*100,
           group = rpi)) + 
  labs(title = "visits_1_2 at hd_date",
       x = "hd_date",
       y = "visits_1_2/available_frames*3600") +
  geom_smooth(aes(color=rpi), span = 0.3) +
  xlim(c(-40, 21))

# Attendance by 2 individuals at a specific day in the calendar
ggplot(data = visitation_attendance, 
       aes(x = hd_date, 
           y = attendance_0/available_frames*100,
           group = rpi)) + 
  labs(title = "attendance_0 at hd_date",
       x = "hd_date",
       y = "attendance_0/available_frames*3600") +
  geom_smooth(aes(color=rpi), span = 0.3) +
  xlim(c(-40, 21))


ggplot(data = visitation_attendance, 
       aes(x = ld_date, 
           y = mean_duration_0_1,
           group = rpi)) +
  geom_smooth(aes(color=rpi), span = 0.3)




# Visits of a second individual at a specific day in the calendar
ggplot(data = subset(visitation_attendance, rec_date %in% "31"), 
       aes(x = hour, 
           y = attendance_2/available_frames*100,
           group = rpi)) + 
  labs(title = "Attendance of 2 individuals at rec_date=31",
       x = "Hour",
       y = "attendance_2/available_frames*100") +
  geom_smooth(method=loess, aes(color=rpi), se = FALSE)


# PLOT PRESENCE OF ADULTS in time ####
ggplot(data = visitation_attendance, 
       aes(x = ld_date, 
           y = (attendance_1+attendance_2)/available_frames*100,
           color = rpi)) + 
  labs(title = "Attendance of individuals at ld_date",
       x = "ld_date",
       y = "(attendance_1+attendance_2)/available_frames*100") +
  geom_point()
  # geom_smooth(method=loess, aes(color=rpi), se = FALSE)

# Order breeding_stage in logic order
visitation_attendance$breeding_stage <- factor(visitation_attendance$breeding_stage, 
                                               levels=c(
                                                 "nest_construction",
                                                 "incubation",
                                                 "1week_h",
                                                 "2week_h",
                                                 "3week_h",
                                                 "gt3week_h"
                                               ))

# Plot the presence of adults on each breeding stage
ggplot(data = visitation_attendance, 
       aes(x = breeding_stage, 
           y = (attendance_1+attendance_2)/available_frames*100,
           group = rpi)) + 
  labs(title = "Attendance of individuals at breeding_stage",
       x = "breeding_stage",
       y = "(attendance_1+attendance_2)/available_frames*100") +
  geom_smooth(method=loess, aes(color=rpi)) +
  # geom_ribbon(aes(color=rpi))

# Plot the number of visits by the second individual on each breeding stage
ggplot(data = visitation_attendance, 
       aes(x = rec_date, 
           y = visits_1_2,
           group = rpi)) + 
  labs(title = "Visits by the second individual at rec_date",
       x = "rec_date",
       y = "visits_1_2") +
  geom_smooth(method=loess, aes(color=rpi), se = FALSE)

# Plot the duration of visits by second individual on rec_date
ggplot(data = visitation_attendance, 
       aes(x = rec_date, 
           y = mean_duration_1_2,
           group = rpi)) + 
  labs(title = "Duration of visits by the second individual at rec_date",
       x = "rec_date",
       y = "mean_duration_1_2") +
  geom_smooth(method=loess, aes(color=rpi), se = FALSE)

# Plot the duration of visits by second individual on rec_date
ggplot(data = visitation_attendance, 
       aes(x = breeding_stage, 
           y = mean_duration_1_2,
           group = rpi)) + 
  labs(title = "Duration of visits by the second individual at breeding_stage",
       x = "breeding_stage",
       y = "mean_duration_1_2") +
  geom_smooth(method=loess, aes(color=rpi), se = FALSE)

# Plot the number of visits_0_1 on breeding_stage
ggplot(data = visitation_attendance, 
       aes(x = breeding_stage, 
           y = mean_duration_1_2,
           group = rpi)) + 
  labs(title = "Duration of visits by the second individual at breeding_stage",
       x = "breeding_stage",
       y = "mean_duration_0_1") +
  geom_smooth(method=loess, aes(color=rpi), se = FALSE)



p + facet_grid(~rpi)

geom_smooth() 

# Create lines for each nest box with colours instead of different plots
{
# PLOT PRESENCE OF ADULTS PER HOUR at every breeding_stage ####
nest_construciton_data <- visitation_attendance %>% 
  filter(breeding_stage == "nest_construction")

incubation_data <- visitation_attendance %>% 
  filter(breeding_stage == "incubation")

one_week_h_data <- visitation_attendance %>% 
  filter(breeding_stage == "one_week_h")

two_week_h_data <- visitation_attendance %>% 
  filter(breeding_stage == "two_week_h")

three_week_h_data <- visitation_attendance %>% 
  filter(breeding_stage == "three_week_h")

fledging_data <- visitation_attendance %>% 
  filter(breeding_stage == "fledging")
}

# Plot the total hours recorded for each rpi on each day
data <- visitation_attendance %>% 
  group_by(rpi, rec_date) %>% 
  summarise(available_frames = sum(available_frames)) %>% 
  filter(available_frames > 30000)

ggplot(data = data, aes(x = rec_date, y = available_frames)) +
  geom_line() +
  # geom_vline(xintercept = 0, color = "skyblue") +
  # geom_vline(aes(xintercept = hd_date[0,], colour = "red")) +
  facet_wrap(~rpi) +
  labs(title = "Available frames per day for each RPI",
       x = "rec_date",
       y = "Total available frames")


# Plot the total attendance_gt0 relative to available frames per day
data <- visitation_attendance %>% 
  group_by(rpi, rec_date) %>% 
  summarise(available_frames = sum(available_frames),
            attendance_gt0 = sum(attendance_gt0),
            ld_date = unique(ld_date),
            hd_date = unique(hd_date)) %>% 
  filter(available_frames > 30000)

##> I should add here in the "data" dataframe, the dates relative to HD and LD using the fitness data.
##> Create a function that adds the rec_date, ld_date and hd_date to each RPi in the desired dataframe,
##> so I can call that function whenever I need to include the relative dates. 

data_with_hd_date_zero <- data %>%
  filter(hd_date == 0)
ggplot(data = data, aes(x = ld_date, y = attendance_gt0/available_frames*100)) +
  geom_line() +
  geom_vline(xintercept = 0, color = "skyblue") +
  geom_vline(data = data_with_hd_date_zero, aes(xintercept = ld_date, color = "red")) +
  facet_wrap(~rpi) +
  labs(title = "attendance_gt0 corrected by available frames",
       x = "rec_date",
       y = "Attendance_gt0")






data <- visitation_attendance %>% 
  filter(breeding_stage == "nest_construction")

data <- visitation_attendance %>% 
  filter(breeding_stage == "incubation")
data <- visitation_attendance %>% 
  filter(breeding_stage == "nest_construction")
data <- visitation_attendance %>% 
  filter(breeding_stage == "nest_construction")


ggplot(data, aes(x = hour, y = (attendance_1+attendance_2))) +
  geom_boxplot() +
  labs(title = "Presence of adults in the nest per RPi",
       x = "hour",
       y = "Attendance (s)") + 
  theme_minimal()
# facet_wrap(~breeding_stage)

  


##> 1. Re-run the processing file to store the visits of ALL TYPES (1-0, 2-1, ...)
##> 2. Re-run the summarize.R to calculate mean_duration_gt0
##> Plot the data to detect patterns and identify the points I need to store
##>   -mean daily attendance_gt0 of the -8:-4 days before ld_date (before incubation)
##>   -mean daily attendance_gt0 of the 0:n(total_eggs) days after ld_date (egg_laying days)
##>   -mean daily attendance_gt0 of the 7:14 (incubation_days)
##>   -number of frames on the eggs on every of these periods
##>   -number of frames at the entry on every of these periods
##>   
##> Store these summary variables in a data-frame to be able to plot the variables over other variables. 
##> 
##> Create functions that define plot themes, styling and define input variables, 
##> so I can easily replicate plots just changing the input variable and it automatically 
##> set it in the labels, title and so on...

##> Think of ways to show multiple data on a plot (include a geom_topbar showing the data availability i.e.)
##> Color different lines based on the start point (yellow-green-blue palette top-down, 
##> based on the start). This way I can easily see if the lines starting higher are maintained 
##> higher in the plot or are mixed later.
##> 
##> For the ECBB conference, show maybe more specific "temporal changes in behaviour"
##> rather than their link to fitness, as I might not be able to defend it myself...
##> 
##> However, plot fitness data to show variation in reproductive success in birds 
##> breeding in the same place at the same time
##> 
##> 









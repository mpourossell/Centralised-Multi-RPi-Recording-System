##> Function to clean the raw detections CSV based on the confidence of the
##> bounding box detections. It creates a new column in the dataframe recounting
##> the number of detections at every frame using the confidences over a threshold.
# Function to calculate angles in degrees
# calculate_angle <- function(x1, y1, x2, y2) {
#   angle_radians <- atan2(x2 - x1, (1-y2) - (1-y1))
#   angle_degrees <- angle_radians * (180 / pi)
#   return(angle_degrees)
# }

calculate_angle_centre <- function(x1, y1, x2, y2, centre_x, centre_y, ref_x, ref_y) {
  # Angle heading
  angle_head_radians <- atan2(x2 - x1, (1 - y2) - (1 - y1))
  angle_head <- angle_head_radians * (180 / pi)
  
  # Angle to door (based on the reference keypoint to draw the line to the door)
  # For the Head direction it's the neck, for the body it's also the neck.
  angle_centre_radians <- atan2(centre_x - ref_x, (1 - centre_y) - (1 - ref_y))
  angle_centre <- angle_centre_radians * (180 / pi)
  
  # angle_centre[angle_centre < -180] <- 360-abs(angle_centre[angle_centre < -180])
  # angle_centre[angle_centre > 180] <- (360-angle_centre[angle_centre > 180])-1
  #
  # Calculate relative angle to the door
  relative_angle <- ifelse(angle_head > 0,
                           ifelse(angle_centre >= 0,
                                  angle_head-angle_centre,
                                  abs(angle_centre)+angle_head),
                           ifelse(angle_centre > 0,
                                  abs(angle_head)+angle_centre,
                                  -(abs(angle_head)-abs(angle_centre))
                           )
  )
  # relative_angle <- angle_centre - angle_head
  
  # # Normalize the angle to the range [-180, 180]
  # relative_angle <- ifelse(angle_centre > 180, angle_centre - 360, relative_angle)
  # relative_angle <- ifelse(relative_angle < -180, relative_angle + 360, relative_angle)
  
  return(relative_angle)
}


calculate_angle <- function(Ax, Ay, Bx, By) {
  dx <- Bx - Ax
  dy <- (1-By) - (1-Ay)
  
  angle <- atan2(dy, dx) * (180/pi)
  angle <- (90 - angle) %% 360
  # print(angle)
  # if (!is.na(angle) & angle > 180) {
  #   angle <- angle - 360
  # }
  angle[!is.na(angle) & angle > 180] <- angle[!is.na(angle) & angle > 180] - 360
  return(angle)
}

calculate_relative_angle <- function(angle_AB, Ax, Ay, Cx, Cy) {
  dx <- Cx - Ax
  dy <- (1-Cy) - (1-Ay)
  
  reference_angle <- atan2(dy, dx) *(180/pi)
  reference_angle <- (90 - reference_angle) %% 360
  
  relative_angle <- (angle_AB - reference_angle) %% 360
  
  # if (!is.na(relative_angle) & relative_angle > 180) {
  #   relative_angle <- relative_angle - 360
  # }
  relative_angle[!is.na(relative_angle) & relative_angle > 180] <- relative_angle[!is.na(relative_angle) & relative_angle > 180] - 360
  
  return(relative_angle)
}

angle_diff <- function(angle1, angle2) {
  diff <- abs(angle2-angle1)
  diff[!is.na(diff) & diff > 180] <- 360 - diff
  return(diff)
}


angle_difference <- function(angle1, angle2) {
  # Calculate the raw difference
  diff <- abs(angle2 - angle1)
  
  # Normalize the difference to the range [0, 360]
  diff <- diff %% 360
  
  # Adjust if the difference is greater than 180
  diff <- ifelse(diff > 180, 360 - diff, diff)
  
  return(diff)
}

fill_na <- function(data, col_list) {
  data %>%
    arrange(track_id, frame) %>%
    group_by(track_id) %>%
    mutate(across(all_of(col_list), ~ if_else(stable == 0 & frame_count < 6 & is.na(.),
                                              lag(., order_by = frame),
                                              .))) %>%
    ungroup()
}

# Make rpi names have 2 digit numbers instead of 1 (00, 01, 02, 03...)
format_rpi_id <- function(rpi_id) {
  prefix <- "jackdaw"
  # Extract the numeric part
  num_part <- as.numeric(sub(prefix, "", rpi_id))
  # Format the numeric part with two digits
  formatted_num <- sprintf("%02d", num_part)
  # Combine the prefix and the formatted number
  paste0(prefix, formatted_num)
}

clean_data_conf <- function(df_in, bbox_conf_thresh, target_column, new_column) {
  # Create the "new_column" column counting the detections over the confidence threshold
  df_filter <- df_in %>%
    filter({{ target_column }} >= bbox_conf_thresh) %>%
    # group_by(complete_timestamp, video) %>%
    group_by(complete_timestamp) %>%
    mutate(!!new_column := sum(count = n())) %>%
    ungroup()
  
  df_out <- merge(df_in, df_filter[, new_column], all.x = TRUE)
  
  # Group by "complete_timestamp" and fill NAs within each group
  df_out <- df_out %>%
    mutate(!!new_column := ifelse(num_detections == 0, 0, !!sym(new_column))) %>%
    arrange(complete_timestamp) %>%
    group_by(complete_timestamp) %>%
    fill(!!new_column, .direction = "downup") %>%
    ungroup() %>%
    fill(!!new_column, .direction = "up")
  
  return(df_out)
}



# Function to interpolate missing detections
interpolate_missing_detections <- function(df, gap_lenght) {
  df <- df %>%
    arrange(frame) %>%
    group_by(track_id) %>%
    mutate(next_frame = lead(frame),
           prev_frame = lag(frame)) %>%
    ungroup()
  
  interpolated_df <- data.frame()
  
  for (track in unique(df$track_id)) {
    track_data <- df %>% filter(track_id == track)
    gaps <- which(diff(track_data$frame) > 1 & diff(track_data$frame) <= gap_lenght)
    
    for (gap in gaps) {
      start_frame <- track_data$frame[gap]
      end_frame <- track_data$next_frame[gap]
      
      for (i in (start_frame + 1):(end_frame - 1)) {
        interpolated_row <- data.frame(frame = i, track_id = track)
        
        for (col in names(df)[!(names(df) %in% c("frame", "track_id", "num_detections"))]) {
          start_val <- track_data[[col]][gap]
          end_val <- track_data[[col]][gap + 1]
          if (!is.na(start_val) & !is.na(end_val)) {
            interpolated_row[[col]] <- approx(c(start_frame, end_frame), c(start_val, end_val), xout = i)$y
          } else {
            interpolated_row[[col]] <- NA
          }
        }
        
        interpolated_df <- rbind(interpolated_df, interpolated_row)
      }
    }
  }
  
  # Ensure complete_timestamp is POSIXct for the interpolated data
  if ("complete_timestamp" %in% colnames(interpolated_df)) {
    interpolated_df$complete_timestamp <- as.POSIXct(interpolated_df$complete_timestamp, origin = "1970-01-01")
  }
  
  combined_df <- bind_rows(df, interpolated_df) %>%
    arrange(frame, track_id) %>% 
    group_by(frame) %>%
    mutate(num_detections = ifelse(is.na(confidence), 0, n())) %>%
    ungroup() %>% 
    group_by(frame) %>% 
    filter(!(num_detections == 0 & n() > 1)) %>% 
    ungroup()
  
  return(combined_df)
}

fix_date_jumps <- function(df) {
  df <- df %>%
    arrange(frame) %>%
    mutate(
      corrected_timestamp = complete_timestamp,
      date_corrected = FALSE
    )
  
  for (i in 2:nrow(df)) {
    if (df$corrected_timestamp[i] < df$corrected_timestamp[i - 1]) {
      df$corrected_timestamp[i] <- df$corrected_timestamp[i] + days(1)
      df$date_corrected[i] <- TRUE
    }
  }
  
  df <- df %>% 
    mutate(complete_timestamp = corrected_timestamp) %>% 
    subset(select = -c(corrected_timestamp, date_corrected))
}

custom_theme <- function() {
  theme_minimal(base_size = 15) +
    theme(
      panel.grid.major = element_line(color = "gray80"),
      panel.grid.minor = element_line(color = "gray90"),
      panel.background = element_rect(fill = "white"),
      plot.background = element_rect(fill = "white"),
      axis.title = element_text(size = 12, face = "bold"),
      axis.text = element_text(size = 10),
      legend.position = "right",
      legend.background = element_rect(fill = "white", color = NA),
      legend.key = element_rect(fill = "white", color = NA)
    )
  
}

# Define the function to create the plot with the custom theme
plot_smooth <- function(data, 
                        hd_line = FALSE, 
                        ld_line = FALSE, 
                        x_var, 
                        y_var, 
                        group_var, 
                        se = FALSE,
                        title = FALSE) {
  
  # Create the ggplot
  p <- ggplot(data = data, 
              aes(x = x_var, 
                  y = y_var, 
                  color = group_var)) +
    labs(title = title,
         x = x_var,
         y = y_var) + 
    geom_smooth(aes(color=group_var), span = 0.3, se = se) +
    theme_minimal() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          axis.line = element_line(colour = "black")) +
    scale_color_viridis_d() +
    # scale_x_continuous(expand = c(0, 0)) +
    scale_y_continuous(limits = c(0,100), expand = c(0, 0)) # Start y-axis at zero
  
  if (ld_line) {
    p <- p + geom_vline(xintercept = ld_zero_positions[["date"]], color = "grey")
  }
  
  if (hd_line) {
    p <- p + geom_vline(xintercept = hd_zero_positions[["date"]], color = "pink")
  }
  
  return(p)
}

##> Plot with X axis being calendar date (vline)

plot_calendar_date <- function(data_, y_, span = 0.3, title_, y_label, y_percent = FALSE, ylim = FALSE) {
  data <- data %>% 
    mutate(offset = row_number()*2)
  
  ggplot(data = data_,
         aes(x = date, 
             y = y_,
             group = rpi)) +
    labs(title = title_,
         x = "Calendar date",
         y = y_label,
         color = "Raspberry Pi") + 
    
    geom_jitter(size = 0.2, color = "grey90") +
    
    geom_vline(data = ld_zero_positions, 
                 aes(xintercept = as.Date(date), color = rpi, linetype = "Laying date"),
                 size = 0.7, show.legend = TRUE,
               position = position_dodge2(width = .5)) +
    # Vertical lines for hatching date (dashed line)
    geom_vline(data = hd_zero_positions, 
                 aes(xintercept = as.Date(date), 
                     color = rpi, 
                     linetype = "Hatching date"),
                 size = 0.7, show.legend = TRUE, 
                 position = position_dodge2(width = .5)) +
    
    # Smoothed line with color mapped to rpi
    geom_smooth(aes(color = rpi),
                method = "loess",
                span = span, se = FALSE) +
    
    theme_minimal() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          axis.line = element_line(colour = "black")) +
    
    # Color scale for rpi
    scale_color_viridis_d() +
    
    # Ensure both "Laying date" and "Hatching date" lines appear in the linetype legend
    scale_linetype_manual(values = c("Laying date" = "solid", "Hatching date" = "dashed"),
                          guide = guide_legend(title = NULL, 
                                               keyheight = unit(1.5, "lines"))) +
    
    guides(color = guide_legend(override.aes = list(size = 1, linetype = "solid"))) +
    
    
    # Customized x-axis breaks and formatting
    scale_x_date(breaks = as.Date(c("2023-03-15", "2023-04-01", "2023-04-15",
                                    "2023-05-01", "2023-05-15", "2023-06-01", 
                                    "2023-06-15")), 
                 labels = scales::date_format("%b %d"), expand = c(0, 0)) +
    
    # Start y-axis at zero
    if (y_percent == TRUE) {
      scale_y_continuous(limits = c(0,100), expand = c(0, 0))
      } else { 
        if (!ylim == FALSE) {
          scale_y_continuous(limits = c(0,ylim), expand = c(0, 0))
        } else {
          scale_y_continuous(expand = c(0, ylim)) 
          }
      }
}

##> Plot with X axis being relative to laying date (vline)

plot_rel_ld <- function(data_, y_, span = 0.3, title_, y_label, y_percent = FALSE, ylim = FALSE) {
  ggplot(data = data_,
         aes(x = ld_date,
             y = y_,
             group = rpi)) +
    labs(title = title_,
         x = "Date relative to the laying date",
         y = y_label,
         color = "Raspberry Pi") + 
    geom_jitter(size = 0.2, color = "grey90") +
    
    # Laying date line
    geom_vline(xintercept = 0, 
               color = "black", 
               linetype = "solid", 
               size = 0.5) +
    
    # Vertical lines for hatching date (dashed line)
    geom_vline(data = hd_zero_positions, 
               aes(xintercept = ld_date, 
                   color = rpi, 
                   linetype = "Hatching date"),
               size = 0.7, show.legend = TRUE, 
               position = position_dodge2(width = .5)) +
    
    # Smooth lines for attendance
    geom_smooth(aes(color = rpi),
                method = "loess",
                span = span, se = FALSE) +
    
    theme_minimal() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          axis.line = element_line(colour = "black")) +
    
    # Color scale for rpi
    scale_color_viridis_d() +
    
    # Ensure both "Laying date" and "Hatching date" lines appear in the linetype legend
    scale_linetype_manual(values = c("Laying date" = "solid", "Hatching date" = "dashed"),
                          guide = guide_legend(title = NULL, 
                                               keyheight = unit(1.5, "lines"))) +
    
    guides(color = guide_legend(override.aes = list(size = 1, linetype = "solid"))) +
    
    scale_x_continuous(expand = c(0, 0)) +
    
    # Start y-axis at zero
    if (y_percent == TRUE) {
      scale_y_continuous(limits = c(0,100), expand = c(0, 0))
    } else { 
      if (!ylim == FALSE) {
        scale_y_continuous(limits = c(0,ylim), expand = c(0, 0))
      } else {
        scale_y_continuous(expand = c(0, ylim)) 
      }
    }
}

##> Plot with X axis being relative to hatching date (vline)

plot_rel_hd <- function(data_, y_, span = 0.3, title_, y_label, y_percent = FALSE, ylim = FALSE) {
  ggplot(data = data_,
         aes(x = hd_date,
             y = y_,
             group = rpi)) +
    labs(title = title_,
         x = "Date relative to the hatching date",
         y = y_label,
         color = "Raspberry Pi") + 
    geom_jitter(size = 0.2, color = "grey90") +
    
    # Laying date line
    geom_vline(xintercept = 0, 
               color = "black", 
               linetype = "solid", 
               size = 0.5) +
    
    # Vertical lines for laying date (dashed line)
    geom_vline(data = ld_zero_positions, 
               aes(xintercept = hd_date, 
                   color = rpi, 
                   linetype = "Laying date"),
               size = 0.7, show.legend = TRUE, 
               position = position_dodge2(width = .5)) +
    
    # Smooth lines for attendance
    geom_smooth(aes(color = rpi),
                method = "loess",
                span = span, se = FALSE) +
    
    theme_minimal() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          axis.line = element_line(colour = "black")) +
    
    # Color scale for rpi
    scale_color_viridis_d() +
    
    # Ensure both "Laying date" and "Hatching date" lines appear in the linetype legend
    scale_linetype_manual(values = c("Hatching date" = "solid", "Laying date" = "dashed"),
                          guide = guide_legend(title = NULL, 
                                               keyheight = unit(1.5, "lines"))) +
    
    guides(color = guide_legend(override.aes = list(size = 1, linetype = "solid"))) +
    
    scale_x_continuous(expand = c(0, 0)) +

    # Start y-axis at zero
    if (y_percent == TRUE) {
      scale_y_continuous(limits = c(0,100), expand = c(0, 0))
    } else { 
      if (!ylim == FALSE) {
        scale_y_continuous(limits = c(0,ylim), expand = c(0, 0))
      } else {
        scale_y_continuous(expand = c(0, ylim)) 
      }
    }
}

  
  
  
  


##> Plot with X axis being calendar date

plot_calendar_date2 <- function(data_, y_, title_, y_label) {
  data <- data %>% 
    mutate(offset = row_number()*2)
  
  ggplot(data = data_,
         aes(x = date, 
             y = y_,
             group = rpi)) +
    labs(title = title_,
         x = "Calendar date",
         y = y_label,
         color = "Raspberry Pi") + 
    
    geom_jitter(size = 0.2, color = "grey90") +
    
    geom_segment(data = ld_zero_positions, 
                 aes(x = as.Date(date), xend = as.Date(date), y = 0, yend = 100, color = rpi, linetype = "Laying date"),
                 size = 0.7, show.legend = TRUE) +
    
    # Vertical lines for hatching date (dashed line)
    geom_segment(data = hd_zero_positions, 
               aes(x = as.Date(date), 
                   xend = as.Date(date), 
                   y = 0, 
                   yend = 100, 
                   color = rpi, 
                   linetype = "Hatching date"),
               size = 0.7, show.legend = TRUE, 
               position = position_dodge(width = .5)) +
    
    # Smoothed line with color mapped to rpi
    geom_smooth(aes(color = rpi),
                method = "loess",
                span = 0.3, se = FALSE) +
    
    theme_minimal() +
    theme(panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          axis.line = element_line(colour = "black")) +
    
    # Color scale for rpi
    scale_color_viridis_d() +
    
    # Ensure both "Laying date" and "Hatching date" lines appear in the linetype legend
    scale_linetype_manual(values = c("Laying date" = "solid", "Hatching date" = "dashed"),
                          guide = guide_legend(title = NULL, 
                                               keyheight = unit(1.5, "lines"))) +
    
    guides(color = guide_legend(override.aes = list(size = 1, linetype = "solid"))) +
    
    
    # Customized x-axis breaks and formatting
    scale_x_date(breaks = as.Date(c("2023-03-15", "2023-04-01", "2023-04-15",
                                    "2023-05-01", "2023-05-15", "2023-06-01", 
                                    "2023-06-15")), 
                 labels = scales::date_format("%b %d"), expand = c(0, 0)) +
    
    # Start y-axis at zero
    scale_y_continuous(limits = c(0,100), expand = c(0, 0))
}
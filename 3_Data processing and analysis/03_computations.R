##> Function to predict smoothed values ####
get_smooth_values <- function(data, x_new) {
  # Remove rows with NA values
  data <- data %>%
    filter(!is.na(date) & !is.na(attendance_1) & !is.na(attendance_2) & !is.na(available_frames))
  
  # Fit loess model
  model <- loess(((attendance_1 + attendance_2) / available_frames) * 100 ~ as.numeric(date), data = data, span = 0.3)
  return(predict(model, newdata = data.frame(date = as.numeric(x_new))))
}

visitation_attendance$date <- as.Date(visitation_attendance$date)

smoothed_values <- visitation_attendance %>%
  filter(ld_date == 0 | hd_date == 0) %>%
  group_by(rpi) %>%
  summarise(
    ld_smoothed = ifelse(any(ld_date == 0), get_smooth_values(visitation_attendance %>% filter(rpi == first(rpi)), first(date[ld_date == 0])), NA),
    hd_smoothed = ifelse(any(hd_date == 0), get_smooth_values(visitation_attendance %>% filter(rpi == first(rpi)), first(date[hd_date == 0])), NA),
    ld_date = ifelse(any(ld_date == 0), first(date[ld_date == 0]), NA),
    hd_date = ifelse(any(hd_date == 0), first(date[hd_date == 0]), NA)
  )

smoothed_values <- smoothed_values %>%
  mutate(ld_date = as.Date(ld_date, origin = "1970-01-01"),
         hd_date = as.Date(hd_date, origin = "1970-01-01"))


##> Model repitibility ####
library(rptR)

rep_data <- plot_data %>% 
  filter(interesting_period %in% c("b_ld", "1week_h", "2week_h"))
  # filter(interesting_period %in% c("b_ld", "1week_h"))


hist(rep_data$attendance_0/rep_data$available_frames*100)


rep1 <- rpt(data = rep_data, 
    attendance_gt0/available_frames*100 ~ interesting_period + (1 | rpi), 
    grname = "rpi", 
    datatype = "Gaussian")
rep1

plot(rep1, cex.main = 1)

rpt(data = rep_data, 
    attendance_2/available_frames*100 ~ (1 | rpi), 
    grname = "rpi", 
    datatype = "Poisson")



##> Check variation in behaviour in different breeding stages
library(lme4)

lmm <- lmer(data = visitation_attendance, attendance_gt0/available_frames*100 ~ date + (1 | rpi))
summary(lmm)

anova(lmm)

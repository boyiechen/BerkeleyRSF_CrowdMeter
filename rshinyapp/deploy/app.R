#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

Sys.setenv(TZ='Asia/Taipei')
library(shiny)
library(dplyr, warn.conflicts = FALSE)
library(ggplot2)
library(readr)
library(lubridate)
library(tidymodels)
time_now <- Sys.time()

### self-defined function
coalesce_join <- function(x, y, 
                          by = NULL, suffix = c(".x", ".y"), 
                          join = dplyr::full_join, ...) {
    joined <- join(x, y, by = by, suffix = suffix, ...)
    # names of desired output
    cols <- union(names(x), names(y))
    
    to_coalesce <- names(joined)[!names(joined) %in% cols]
    suffix_used <- suffix[ifelse(endsWith(to_coalesce, suffix[1]), 1, 2)]
    # remove suffixes and deduplicate
    to_coalesce <- unique(substr(
        to_coalesce, 
        1, 
        nchar(to_coalesce) - nchar(suffix_used)
    ))
    
    coalesced <- purrr::map_dfc(to_coalesce, ~dplyr::coalesce(
        joined[[paste0(.x, suffix[1])]], 
        joined[[paste0(.x, suffix[2])]]
    ))
    names(coalesced) <- to_coalesce
    
    dplyr::bind_cols(joined, coalesced)[cols]
}

### fetch data
url <- "http://13.112.96.0:8080/img/NTU_GYM_crowd_meter.csv"
df_raw <- read_csv(url)

### clean data
df <- df_raw %>% 
    # 1: Sun., 2: Mon., ..., 6: Sat.
    mutate(weekday = lubridate::wday(Timestamp)) %>% 
    filter(Timestamp >= as.Date("2022-03-01")) %>% 
    select(-"健身中心最適人數", -"室內游泳池最適人數")

# making the data as 300 seconds time frequency
df <- df %>% 
    arrange(Timestamp) %>% 
    mutate(by15 = cut(Timestamp, "15 min")) %>% 
    # make sure the data is in 5 min freq
    group_by(by5 = cut(Timestamp, "5 min")) %>% 
    summarise(count = mean(current_count),
              ratio = mean(capacity_ratio),
              temp = mean(temp),
              temp_feel = mean(temp_feel),
              temp_min = mean(temp_min),
              temp_max = mean(temp_max),
              pressure = mean(pressure),
              humidity = mean(humidity),
              weekday = head(weekday, 1),
              by15 = head(by15, 1),
    ) %>% 
    # create dummies
    mutate(by5 = as.POSIXct(by5)) %>% 
    mutate(by5 = lubridate::ymd_hms(by5)) %>% 
    mutate(hour = lubridate::hour(by5),
           minute = lubridate::minute(by5),) %>% 
    # create dummies
    mutate(by15 = as.POSIXct(by15)) %>% 
    mutate(by15 = lubridate::ymd_hms(by15)) %>% 
    mutate(minute15 = lubridate::minute(by15),) %>% 
    # if `count` less than 10, then assign 0
    mutate(count = ifelse(count<=10, 0, count))

### Modeling
df_model <- df %>% 
    mutate(weekday = as.factor(weekday),
           hour = as.factor(hour),
           minute = as.factor(minute)) %>% 
    select(by5, count, 
           temp, temp_feel, temp_min, temp_max, 
           pressure, humidity, 
           weekday, hour, minute)
# split training set and testing set
idx <- nrow(df) - 4032 # test set is two-week long
df_train <- df_model[1:idx,]
df_test <- df_model[-(1:idx),]
# pre-process: create lag variables
modelRecipe <-
    recipe(count ~., data = df_train) %>% 
    step_rm(by5) %>%
    step_lag(count, lag = 1:144) %>% 
    step_lag(temp, temp_feel, temp_min, temp_max,
             pressure, humidity,
             lag = 1:12) %>%
    step_rm(temp, temp_feel, temp_min, temp_max,
            pressure, humidity)
# after pre-processing (create predictors)
df_train_processed <- modelRecipe %>%
    prep(df_train) %>%
    bake(df_train)
df_test_processed <- modelRecipe %>%
    prep(df_test) %>%
    bake(df_test)
# parsnip
linear_reg_lm_spec <-
    linear_reg() %>%
    set_engine('lm')
# Fit the models
lmFit <- fit(linear_reg_lm_spec, count ~ ., data = df_train_processed)
# Linear Regression
df_eval_lm <- df_test_processed %>%
    dplyr::select(count) %>%
    bind_cols(predict(lmFit, df_test_processed)) %>% 
    bind_cols(df_test %>% select(by5)) %>% 
    filter(row_number() >= (4032 - 288*1.2) )
plot_lm <- df_eval_lm %>% 
    ggplot()+
    geom_line(aes(by5, count, col = "real"))+
    geom_line(aes(by5, .pred, col = "pred"))+
    ylim(c(-10, 200))
err_lm <- df_eval_lm %>% mutate(err = count - .pred) %>% select(err) %>% unlist
### Generate Real-time Prediction
df_pred <- df_test %>% 
    bind_rows(tail(df_test, 1) %>% 
                  mutate(by5 = by5 + 300,
                         count = NA,
                         temp = NA, temp_feel = NA, temp_min = NA, temp_max = NA,
                         pressure = NA, humidity = NA) %>% 
                  mutate(weekday = as.factor(lubridate::wday(by5)),
                         hour = as.factor(lubridate::hour(by5)),
                         minute = as.factor(lubridate::minute(by5)))
    )
df_pred_processed <- modelRecipe %>% prep(df_pred) %>% bake(df_pred)
# remark: 
# `df_pred` is a df contains real value except for the last row with `count=NA`
# `df_outcome` is a df contains only predicted values from the model estimation
df_outcome <- df_pred_processed %>%
    dplyr::select(count) %>%
    bind_cols(predict(lmFit, df_pred_processed)) %>% 
    bind_cols(df_pred %>% select(by5)) %>% 
    filter(row_number() >= (4032 - 288) )
# a new `df_pred`
df_pred <- df_pred %>% coalesce_join(
    (df_outcome %>% tail(1) %>% select(by5, count = .pred)),
    by = c("by5")
)
# repeating prediction
for(i in 1:72){ # predict an hour ahead
    df_pred <- df_pred %>% 
        bind_rows(tail(df_pred, 1) %>% 
                      mutate(by5 = by5 + 300,
                             count = NA,
                             temp = NA, temp_feel = NA, temp_min = NA, temp_max = NA,
                             pressure = NA, humidity = NA) %>% 
                      mutate(weekday = as.factor(lubridate::wday(by5)),
                             hour = as.factor(lubridate::hour(by5)),
                             minute = as.factor(lubridate::minute(by5)))
        )
    df_pred_processed <- modelRecipe %>% prep(df_pred) %>% bake(df_pred)
    df_pred_processed <- df_pred_processed %>%
        fill(!!colnames(df_pred_processed),
             .direction = "down") 
    df_outcome <- df_pred_processed %>%
        dplyr::select(count) %>%
        bind_cols(predict(lmFit, df_pred_processed)) %>% 
        bind_cols(df_pred %>% select(by5)) %>% 
        filter(row_number() >= (4032 - 288*1.2) )
    df_pred <- df_pred %>% coalesce_join(
        (df_outcome %>% tail(1) %>% select(by5, count = .pred)),
        by = c("by5")
    )
}

### Add s.e.
df_outcome_plot <- df_outcome %>%
    mutate(isPred = ifelse(count == .pred, 1, 0)) %>% 
    mutate(Peak = max(isPred * .pred),
           isPeak = ifelse(.pred == Peak, 1, 0),
    ) %>% 
    mutate(upper = ifelse(isPred == 1, 
                          .pred + 1.96*sd(err_lm),
                          NA),
           lower = ifelse(isPred == 1, 
                          .pred - 1.96*sd(err_lm),
                          NA)
    ) #%>% 
    #mutate(lower = ifelse(lower < 0, 0, lower))
peak_time <- (df_outcome_plot %>% filter(isPeak == 1) %>% select(by5))$by5
peak_count <- df_outcome_plot$Peak[1]

#####----- UI -----#####
# Define UI for application that draws a histogram
ui <- fluidPage(    
    
    # Give the page a title
    titlePanel("NTU GYM Instant Crowd Meter & Predictor"),
    
    # Generate a row with a sidebar
    sidebarLayout(      
        
        # Define the sidebar with one input
        sidebarPanel(
            helpText("How many people are inside NTU GYM now and what is the distribution for daily entrants?"),
            selectInput("wday", "Choose a week day to view the time series plot.",
                        choices=c("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")),
                        helpText("Notice that operation hours vary in different weekdays"),
            hr(),
            sliderInput("min_ahead",
                        "How far do you want the model to forecast?",
                        min = 1,  max = 288, value = 36),
            # sliderInput("K",
            #             "The number of the doors in this game:",
            #             min = 3,  max = 100,  value = 3)
        ),
        
        # The structure of the main panel
        # mainPanel(
        #     plotOutput("Plot")
        # )
        mainPanel(
            tabsetPanel(
                # tabPanel("Summary", dataTableOutput("dis")),
                tabPanel("Plot",
                         # fluidRow(...)
                         plotOutput("Plot_TODAY"),
                         plotOutput("Plot_WDAY")
                ),
                tabPanel("Prediction", 
                         # dataTableOutput("dis"),
                         textOutput("Text_GeneralPred"),
                         plotOutput("Plot_GeneralPrediction"),
                         textOutput("Text_SpecPred"),
                         plotOutput("Plot_SpecPred"),
                         textOutput("Text_PeakTime"),
                         textOutput("Text_Peak"),
                         )
            )
        )
    )
)

#----- Construct the plot -----#
# Define server logic required to draw a histogram
server <- function(input, output) {
    # Fill in the spot we created for a plot
    output$Plot_WDAY <- renderPlot({
        # Render a time series plot
        if(input$wday == "Sunday"){wday_input <- 1}
        if(input$wday == "Monday"){wday_input <- 2}
        if(input$wday == "Tuesday"){wday_input <- 3}
        if(input$wday == "Wednesday"){wday_input <- 4}
        if(input$wday == "Thursday"){wday_input <- 5}
        if(input$wday == "Friday"){wday_input <- 6}
        if(input$wday == "Saturday"){wday_input <- 7}
        
        ## time series plot for selected weekday
        df %>% 
            filter(weekday == wday_input) %>% 
            mutate(date_preserved = lubridate::date(max(by5))) %>% 
            group_by(hour, minute) %>%
            summarise(count = mean(count),
                      count_u = quantile(count, probs = 0.95),
                      count_l = quantile(count, probs = 0.05),
                      temp = mean(temp),
                      date_preserved = tail(date_preserved, 1),
            ) %>% 
            mutate(HM = paste0(hour, ":", minute)) %>% 
            mutate(HM = lubridate::hm(HM)) %>% 
            mutate(time = date_preserved + HM) %>% 
            ggplot()+
            # ppl count
            geom_line(aes(time, count, col = "avg. count"))+
            geom_line(aes(time, temp*2, col = "avg. temperature"))+
            scale_size_area(limits = c(0, 1000), max_size = 10, guide = NULL)+
            scale_y_continuous(
                name = "Count",
                # Add a second axis and specify its features
                sec.axis = sec_axis(~./2, name="Temperature (ºC)")
            )+
            labs(title = paste0("Number of people in NTU GYM: past ", input$wday, "s"))
    })

    output$Plot_TODAY <- renderPlot({
        df %>%
            filter(by5 >= as.Date(Sys.Date())) %>%
            filter(weekday == lubridate::wday(Sys.time())) %>%
            rename(time = by5) %>%
            ggplot(aes(x = time))+
            # ppl count
            geom_line(aes(y = count, col = "count"))+
            geom_line(aes(y = temp*2, col = "temperature"))+
            geom_vline(xintercept = max(df$by5), color = 'grey')+
            # geom_hline(aes(yintercept = 91, col = "limit"))+
            scale_y_continuous(
                name = "Count",
                # Add a second axis and specify its features
                sec.axis = sec_axis(~./2, name="Temperature (ºC)")
            )+
            labs(title = "Number of people in NTU GYM, Today")
    })
    
    ### For the second tab of the main panel
    # output$dis <- renderDataTable({})
    output$Text_GeneralPred <- renderText({
        "An autoregressive distributed lag, ADL(36, 12), model for the count data is applied for the real-time prediction.\n
         The graph lying in the upper panel shows how the model performs based on the last fully observed day. 
         The whole dataset is cut into two parts where the second part is two-week long and is not involved in training the model.
         We only display the last day available to show the model accuracy for simplicity.\n
         Note that the shaded area marks the model prediction, which is based on last available weather information and the count data for prediction is rolling basis." 
        })
    output$Plot_GeneralPrediction <- renderPlot({
        df_outcome %>%
            ggplot()+
            # adding prediction as shaded area
            geom_rect(data = subset(df_outcome, count == .pred),
                      aes(ymin = -Inf, ymax = Inf, xmin = by5, xmax = by5),
                      alpha = 0.2, color = 'grey')+
            geom_line(aes(by5, count, col = "real"))+
            geom_line(aes(by5, .pred, col = "pred"))+
            ylim(c(-20, 120))
        
    })
    output$Text_SpecPred <- renderText({
        "The graph at the lower panel shows the approximate 95% prediction interval. 
        The interval is not calculated with the rolling basis, thus it is wrong. The interval is more misleading as the predicting horizon goes further.
        The width of the interval is twice the standard error of residuals while evaluating the model with the test set multipled by 1.96.
        " 
    })
    output$Text_PeakTime <- renderText({
        paste0("The model forecasts that the peak time will be:", as.character(peak_time))
    })
    output$Text_Peak <- renderText({
        paste0("The model forecasts that the peak will be:", round(peak_count))
    })
    output$Plot_SpecPred <- renderPlot({
        df_outcome_plot %>% 
            ggplot()+
            # adding prediction as shaded area
            geom_rect(data = subset(df_outcome_plot, isPeak == 1),
                      aes(ymin = -Inf, ymax = Inf, xmin = by5, xmax = by5),
                      alpha = 0.2, color = 'grey')+
            geom_line(aes(by5, count, col = "real"))+
            geom_line(aes(by5, .pred, col = "pred"))+
            geom_line(aes(by5, upper),
                      color = "grey59", linetype = "dashed")+
            geom_line(aes(by5, lower),
                      color = "grey59", linetype = "dashed")+
            ylim(c(-20, 120))
    })
    
}

# Run the application 
shinyApp(ui = ui, server = server)

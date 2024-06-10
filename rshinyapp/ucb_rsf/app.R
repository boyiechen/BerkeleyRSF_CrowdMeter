# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#
rm(list = ls())

Sys.setenv(TZ='US/Pacific')
library(shiny)
library(dplyr, warn.conflicts = FALSE)
library(ggplot2)
library(readr)
library(lubridate)
    
### fetch data
df <- read_csv("https://github.com/boyiechen/BerkeleyRSF_CrowdMeter/raw/main/rshinyapp/cleanedData.csv")
df_outcome <- read_csv("https://github.com/boyiechen/BerkeleyRSF_CrowdMeter/raw/main/rshinyapp/reportData.csv")

peak_time <- (df_outcome %>% filter(isPeak == 1) %>% select(by5))$by5
peak_count <- df_outcome$Peak[1]

#####----- UI -----#####
# Define UI for application that draws a histogram
ui <- fluidPage(    
    
    # Give the page a title
    titlePanel("UC Berkeley RSF Instant Crowd Meter & Predictor"),
    
    # Generate a row with a sidebar
    sidebarLayout(      
        
        # Define the sidebar with one input
        sidebarPanel(
            helpText("How many people are inside RSF now and what is the distribution for daily entrants?"),
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
            ylim(c(-20, 160))
        
    })
    output$Text_SpecPred <- renderText({
        "The graph at the lower panel shows the approximate 95% prediction interval. 
        The interval is not calculated with the rolling basis, thus it is wrong. The interval is more misleading as the predicting horizon goes further.
        The width of the interval is twice the standard error of residuals while evaluating the model with the test set multipled by 1.96.
        " 
    })
    output$Text_PeakTime <- renderText({
        paste0("The model forecasts that the peak time will be: ", as.character(peak_time))
    })
    output$Text_Peak <- renderText({
        paste0("The model forecasts that the peak will be: ", round(peak_count))
    })
    output$Plot_SpecPred <- renderPlot({
        df_outcome %>% 
            ggplot()+
            # adding prediction as shaded area
            geom_rect(data = subset(df_outcome, isPeak == 1),
                      aes(ymin = -Inf, ymax = Inf, xmin = by5, xmax = by5),
                      alpha = 0.2, color = 'grey')+
            geom_line(aes(by5, count, col = "real"))+
            geom_line(aes(by5, .pred, col = "pred"))+
            geom_line(aes(by5, upper),
                      color = "grey59", linetype = "dashed")+
            geom_line(aes(by5, lower),
                      color = "grey59", linetype = "dashed")+
            ylim(c(-20, 160))
    })
    
}

# Run the application 
shinyApp(ui = ui, server = server)

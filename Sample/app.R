# ebm_0_dim.m
# 
# Energy Balance Model based on Equation 3.8
# from 'A Climate Modeling Primer', 1st Edition, 1987, 
# A. Henderson-Sellers and K. McGuffie
#



# print(paste0("Final Temperature: ", Temp[nsteps], " Degrees Centigrade"))


library(shiny)
#library(ggplot2)
library(plotly)


ui <- fluidPage(
  numericInput(inputId = "TStart",
               label = "Initial Temperature",
               value = 13.5),
  numericInput(inputId = "SXInit",
               label = "Solar Multiplier",
               value = 1),
  sliderInput(inputId = "AlbedoVal",
              label = "Albedo",
              value = 0.32, min = 0, max = 1),
  checkboxInput(inputId = "AlbedoButton",
                label = "Temperature Dependent Albedo"),
  numericInput(inputId = "SVal",
               label = "Solar Constant",
               value = 1370),
  numericInput(inputId = "SXLow",
               label = "Lowered Solar",
               value = 1),
  numericInput(inputId = "FirstYear",
               label = "First Year",
               value = 1),
  numericInput(inputId = "LastYear",
               label = "Last Year",
               value = 1),
  textOutput("HeatLoss"),
  numericInput(inputId = "AVal",
               label = "A",
               value = 204),
  numericInput(inputId = "BVal",
               label = "B",
               value = 2.17),
  checkboxInput(inputId = "BlackBodyButton",
                label = "Blackbody"),
  plotlyOutput("TCurve"),
  textOutput("FinalTemp"),
  textOutput("SteadyTemp")
  )

server <- function( input, output) {
  output$HeatLoss <- renderText("Heat Loss")
  
  output$TCurve <- renderPlotly({
    A = input$AVal                 # Radiative Heat Loss Coefficient
    B = input$BVal                 # Radiative Heat Loss Coefficient
    Cm = 2.08E08             # Heat Capacity
    S = input$SVal                 # Solar Constant
    Sigma = 5.6696E-8        # Stefan-Boltzmann Constant (in W/(m^2K^4))
    nsteps = 500
    dYears = .05
    TMin = -15
    TMax = 15
    alb_ice = .60
    alb_land = .32
    TIce = -10
    TLand = 10
    
    T0 = 273.15
    
    BlackBodyButton = input$BlackBodyButton
    AlbedoButton = input$AlbedoButton
    
    dt = dYears*365.25*24*60*60
    CallBack = 0
    # Time = zeros(nsteps,1)
    
    AlbedoTime <- c()
    
    Temp = input$TStart
    Time = 0
    for (n in 2:nsteps) {
      t = Temp[n-1]
      Time[n] = (n-1)*dYears
      if (Time[n] >= input$FirstYear & Time[n] < input$LastYear) {
        SX = input$SXLow
      } else {
        SX = input$SXInit
      }
      if (AlbedoButton == FALSE){
        albedo = input$AlbedoVal
      } else {
        if (t<TIce) {
          albedo = alb_ice
        } else if (t > TLand) {
          albedo = alb_land
        } else {
          albedo = alb_ice + (alb_land - alb_ice)*(t - TIce)/(TLand - TIce)
        }
      }
      
      PGain = S*SX*(1-albedo)/4
      if (BlackBodyButton == FALSE) {
        PLoss = A + B*t
      } else {
        PLoss = Sigma*(t+T0)^4
      }
      DeltaTemp = (PGain - PLoss)*(dt/Cm)
      Temp[n] = t + DeltaTemp
      AlbedoTime[n] = albedo
    }
    # plot(Time,Temp, xlab = "Time (Years)", ylab = "Temperature (Degrees C)", type = "n")
    # lines(Time,Temp, lwd=1.5, col = "red")
    
    # ggplot() +
    #   geom_line(aes(x = Time, y = Temp), colour = 'red') +
    #   xlab("Time (years)") +
    #   ylab("Temperature (Degrees C)")
    
    plot_ly(x = ~Time, y = ~Temp, type = 'scatter', mode = 'lines') %>%
      layout(xaxis = list(title = "Time (years)"),
             yaxis = list(title = "Temperature (Degrees C)"))
    
  })
  
  output$FinalTemp <- renderText({
    A = input$AVal                 # Radiative Heat Loss Coefficient
    B = input$BVal                 # Radiative Heat Loss Coefficient
    Cm = 2.08E08             # Heat Capacity
    S = input$SVal                 # Solar Constant
    Sigma = 5.6696E-8        # Stefan-Boltzmann Constant (in W/(m^2K^4))
    nsteps = 500
    dYears = .05
    TMin = -15
    TMax = 15
    alb_ice = .60
    alb_land = .32
    TIce = -10
    TLand = 10
    
    T0 = 273.15
    
    BlackBodyButton = input$BlackBodyButton
    AlbedoButton = input$AlbedoButton
    
    dt = dYears*365.25*24*60*60
    CallBack = 0
    # Time = zeros(nsteps,1)
    
    AlbedoTime <- c()
    
    Temp = input$TStart
    Time = 0
    for (n in 2:nsteps) {
      t = Temp[n-1]
      Time[n] = (n-1)*dYears
      if (Time[n] >= input$FirstYear & Time[n] < input$LastYear) {
        SX = input$SXLow
      } else {
        SX = input$SXInit
      }
      if (AlbedoButton == FALSE){
        albedo = input$AlbedoVal
      } else {
        if (t<TIce) {
          albedo = alb_ice
        } else if (t > TLand) {
          albedo = alb_land
        } else {
          albedo = alb_ice + (alb_land - alb_ice)*(t - TIce)/(TLand - TIce)
        }
      }
      
      PGain = S*SX*(1-albedo)/4
      if (BlackBodyButton == FALSE) {
        PLoss = A + B*t
      } else {
        PLoss = Sigma*(t+T0)^4
      }
      DeltaTemp = (PGain - PLoss)*(dt/Cm)
      Temp[n] = t + DeltaTemp
      AlbedoTime[n] = albedo
    }
    print(paste0("Final Temperature:    ",floor(Temp[nsteps]*1000)/1000,' C'))
  })
  
  output$SteadyTemp <- renderText({
    A = input$AVal                 # Radiative Heat Loss Coefficient
    B = input$BVal                 # Radiative Heat Loss Coefficient
    Cm = 2.08E08             # Heat Capacity
    S = input$SVal                 # Solar Constant
    Sigma = 5.6696E-8        # Stefan-Boltzmann Constant (in W/(m^2K^4))
    nsteps = 500
    dYears = .05
    TMin = -15
    TMax = 15
    alb_ice = .60
    alb_land = .32
    TIce = -10
    TLand = 10
    
    T0 = 273.15
    
    BlackBodyButton = input$BlackBodyButton
    AlbedoButton = input$AlbedoButton
    
    dt = dYears*365.25*24*60*60
    CallBack = 0
    # Time = zeros(nsteps,1)
    
    AlbedoTime <- c()
    
    Temp = input$TStart
    Time = 0
    for (n in 2:nsteps) {
      t = Temp[n-1]
      Time[n] = (n-1)*dYears
      if (Time[n] >= input$FirstYear & Time[n] < input$LastYear) {
        SX = input$SXLow
      } else {
        SX = input$SXInit
      }
      if (AlbedoButton == FALSE){
        albedo = input$AlbedoVal
      } else {
        if (t<TIce) {
          albedo = alb_ice
        } else if (t > TLand) {
          albedo = alb_land
        } else {
          albedo = alb_ice + (alb_land - alb_ice)*(t - TIce)/(TLand - TIce)
        }
      }
      
      PGain = S*SX*(1-albedo)/4
      if (BlackBodyButton == FALSE) {
        PLoss = A + B*t
      } else {
        PLoss = Sigma*(t+T0)^4
      }
      DeltaTemp = (PGain - PLoss)*(dt/Cm)
      Temp[n] = t + DeltaTemp
      AlbedoTime[n] = albedo
    }
    if (BlackBodyButton == FALSE) {
    TSteady = (S*SX*(1 - albedo)/4 - A)/B
    } else {
      TSteady = (S*SX*(1 - albedo)/4/Sigma)^0.25 - T0
    }
    print(paste0('Steady-State Temperature:    ', floor(TSteady*1000)/1000, ' C'))
  })
}

shinyApp(ui = ui, server = server)





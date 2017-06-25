library(shiny)
library(ggplot2)

# server logic: calc output based on inputs
function(input, output) {

  # use reactive() to ensure that dataset is updated whenever
  # inout$sampleSize changes
  dataset <- reactive({
    diamonds[sample(nrow(diamonds), input$sampleSize), ]
  })

  # renderPlot() does the plot rendering. duh.
  output$plot <- renderPlot({

    p <- ggplot(dataset(), aes_string(x=input$x, y=input$y)) +
      geom_point()

    if (input$color != 'None')
      p <- p + aes_string(color=input$color)

    facets <- paste(input$facet_row, '~', input$facet_col)
    if (facets != '. ~ .')
      p <- p + facet_grid(facets)

    if (input$jitter)
      p <- p + geom_jitter()
    if (input$smooth)
      p <- p + geom_smooth()

    print(p)

  }, height = 700)

}

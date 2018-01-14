# A heatmap of thresholds over the past 30 days

dummy.data <- rnorm(30, mean = 0.60, sd = 0.4)
dummy.data[which(dummy.data > 1.0)] <- 1.0

image(matrix(dummy.data, ncol = 1), xaxt = "n", yaxt = "n")

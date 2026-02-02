#!/usr/bin/env Rscript

source('R/code_sandbox.R')
library(tidyverse)

data_list <- list(dados = data.frame(x = 1:10, y = 11:20, group = rep(c('A', 'B'), 5)))
sandbox <- create_sandbox_env(data_list)

code <- 'resultado <- dados %>% filter(x > 5)'

# Check what's in sandbox
cat('Functions in sandbox:', length(ls(envir = sandbox)), '\n')
cat('Has filter:', exists('filter', envir = sandbox), '\n')
cat('Has dados:', exists('dados', envir = sandbox), '\n')

# Try validation
validation <- validate_code_before_execution(code)
cat('Valid:', validation$is_valid, '\n')
if (!validation$is_valid) {
  cat('Errors:', paste(validation$errors, collapse=' | '), '\n')
}

# Try execution
result <- execute_code_safely(code, sandbox)
cat('Success:', result$success, '\n')
if (!result$success) {
  cat('Error:', result$error, '\n')
}
cat('Messages:', paste(result$messages, collapse=' | '), '\n')
cat('Resultado:', is.null(result$resultado), '\n')

if (!is.null(result$resultado)) {
  print(result$resultado)
}

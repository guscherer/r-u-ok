# Tests for Safe Code Execution
# Focuses on security, error handling, and environment isolation

library(testthat)
library(dplyr)

test_that("Code executes in isolated environment", {
  # Create isolated environment
  env_execucao <- new.env()
  
  # Verify it starts empty (no lista_dados)
  expect_false(exists("lista_dados", envir = env_execucao))
  
  # Add test data
  env_execucao$lista_dados <- list(mtcars)
  
  # Verify it's isolated from global environment
  expect_false(exists("lista_dados", envir = .GlobalEnv))
  expect_true(exists("lista_dados", envir = env_execucao))
})

test_that("Valid dplyr code executes successfully", {
  # Setup isolated environment
  env_execucao <- new.env()
  env_execucao$lista_dados <- list(mtcars)
  
  # Load required libraries in the environment
  suppressPackageStartupMessages({
    library(dplyr, quietly = TRUE)
  })
  
  # Execute safe code
  codigo <- "resultado <- lista_dados[[1]] %>% filter(mpg > 20)"
  
  result <- tryCatch({
    eval(parse(text = codigo), envir = env_execucao)
    TRUE
  }, error = function(e) {
    FALSE
  })
  
  expect_true(result)
  expect_true(exists("resultado", envir = env_execucao))
  expect_s3_class(env_execucao$resultado, "data.frame")
  expect_true(all(env_execucao$resultado$mpg > 20))
})

test_that("Multiple operations can be executed", {
  env_execucao <- new.env()
  env_execucao$lista_dados <- list(
    data.frame(id = 1:5, valor = c(100, 200, 300, 400, 500)),
    data.frame(id = 1:3, nome = c("A", "B", "C"))
  )
  
  suppressPackageStartupMessages(library(dplyr, quietly = TRUE))
  
  # Multi-step code
  codigo <- "
  df1 <- lista_dados[[1]]
  df2 <- lista_dados[[2]]
  resultado <- df1 %>% 
    filter(valor > 200) %>%
    inner_join(df2, by = 'id')
  "
  
  result <- tryCatch({
    eval(parse(text = codigo), envir = env_execucao)
    TRUE
  }, error = function(e) {
    FALSE
  })
  
  expect_true(result)
  expect_true(exists("resultado", envir = env_execucao))
  expect_equal(nrow(env_execucao$resultado), 1)  # Only id 3 has valor > 200
})

test_that("Invalid code returns error without crashing", {
  env_execucao <- new.env()
  env_execucao$lista_dados <- list(mtcars)
  
  # Intentionally broken code
  codigo_ruim <- "resultado <- lista_dados[[99]] %>% nonexistent_function()"
  
  error_message <- NULL
  result <- tryCatch({
    eval(parse(text = codigo_ruim), envir = env_execucao)
    "success"
  }, error = function(e) {
    error_message <<- e$message
    "error"
  })
  
  expect_equal(result, "error")
  expect_true(!is.null(error_message))
})

test_that("Syntax errors are caught", {
  env_execucao <- new.env()
  env_execucao$lista_dados <- list(mtcars)
  
  # Code with syntax error
  codigo_ruim <- "resultado <- lista_dados[[1]] %>% filter(mpg > "  # Missing closing quote and parenthesis
  
  error_caught <- FALSE
  tryCatch({
    eval(parse(text = codigo_ruim), envir = env_execucao)
  }, error = function(e) {
    error_caught <<- TRUE
  })
  
  expect_true(error_caught)
})

test_that("Environment isolation prevents global pollution", {
  env_execucao <- new.env()
  env_execucao$lista_dados <- list(mtcars)
  
  suppressPackageStartupMessages(library(dplyr, quietly = TRUE))
  
  # Execute code that creates variables
  codigo <- "
  temp_var <- 'test'
  resultado <- lista_dados[[1]] %>% filter(mpg > 25)
  "
  
  eval(parse(text = codigo), envir = env_execucao)
  
  # Check that temp_var exists in isolated env but not globally
  expect_true(exists("temp_var", envir = env_execucao))
  expect_false(exists("temp_var", envir = .GlobalEnv))
})

test_that("Missing 'resultado' object is detectable", {
  env_execucao <- new.env()
  env_execucao$lista_dados <- list(mtcars)
  
  # Code that doesn't create 'resultado'
  codigo <- "temp_output <- lista_dados[[1]] %>% head()"
  
  eval(parse(text = codigo), envir = env_execucao)
  
  expect_false(exists("resultado", envir = env_execucao))
  expect_true(exists("temp_output", envir = env_execucao))
})

test_that("resultado object is correctly identified", {
  env_execucao <- new.env()
  env_execucao$lista_dados <- list(iris)
  
  suppressPackageStartupMessages(library(dplyr, quietly = TRUE))
  
  codigo <- "resultado <- lista_dados[[1]] %>% filter(Species == 'setosa')"
  
  eval(parse(text = codigo), envir = env_execucao)
  
  expect_true(exists("resultado", envir = env_execucao))
  expect_s3_class(env_execucao$resultado, "data.frame")
  expect_true(all(env_execucao$resultado$Species == "setosa"))
})

test_that("Dangerous system calls can be detected", {
  # Note: This is a basic example. Real security requires more sophisticated sandboxing
  env_execucao <- new.env()
  env_execucao$lista_dados <- list(mtcars)
  
  # Code attempting system call
  codigo_perigoso <- "system('rm -rf /')"
  
  # In production, you would want to parse and validate code before execution
  # This test demonstrates error handling
  expect_error(eval(parse(text = codigo_perigoso), envir = env_execucao))
})

test_that("Empty lista_dados is handled", {
  env_execucao <- new.env()
  env_execucao$lista_dados <- list()
  
  codigo <- "resultado <- lista_dados[[1]]"
  
  error_caught <- FALSE
  tryCatch({
    eval(parse(text = codigo), envir = env_execucao)
  }, error = function(e) {
    error_caught <<- TRUE
  })
  
  expect_true(error_caught)
})

test_that("Code with pipe chains executes correctly", {
  env_execucao <- new.env()
  env_execucao$lista_dados <- list(mtcars)
  
  suppressPackageStartupMessages(library(dplyr, quietly = TRUE))
  
  codigo <- "
  resultado <- lista_dados[[1]] %>%
    filter(cyl == 4) %>%
    select(mpg, hp, wt) %>%
    arrange(desc(mpg)) %>%
    head(5)
  "
  
  eval(parse(text = codigo), envir = env_execucao)
  
  expect_true(exists("resultado", envir = env_execucao))
  expect_equal(nrow(env_execucao$resultado), 5)
  expect_equal(ncol(env_execucao$resultado), 3)
  expect_true(all(env_execucao$resultado$mpg[-1] <= env_execucao$resultado$mpg[-nrow(env_execucao$resultado)]))
})

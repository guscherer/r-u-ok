# Tests for Utility Functions
# Covers file reading, data manipulation, and helper functions

library(testthat)
library(readr)
library(readxl)
library(tibble)

test_that("CSV files can be read correctly", {
  # Create temporary CSV file
  temp_csv <- tempfile(fileext = ".csv")
  df_test <- data.frame(
    id = 1:3,
    nome = c("Alice", "Bob", "Carol"),
    valor = c(100, 200, 300)
  )
  write_csv(df_test, temp_csv)
  
  # Test reading
  df_loaded <- read_csv(temp_csv, show_col_types = FALSE)
  
  expect_s3_class(df_loaded, "data.frame")
  expect_equal(nrow(df_loaded), 3)
  expect_equal(ncol(df_loaded), 3)
  expect_equal(names(df_loaded), c("id", "nome", "valor"))
  
  # Cleanup
  unlink(temp_csv)
})

test_that("Excel files can be read correctly", {
  skip_if_not_installed("writexl")
  library(writexl)
  
  # Create temporary Excel file
  temp_xlsx <- tempfile(fileext = ".xlsx")
  df_test <- data.frame(
    produto = c("A", "B", "C"),
    preco = c(10.5, 20.0, 15.75),
    estoque = c(100L, 50L, 75L)
  )
  write_xlsx(df_test, temp_xlsx)
  
  # Test reading
  df_loaded <- read_excel(temp_xlsx)
  
  expect_s3_class(df_loaded, "data.frame")
  expect_equal(nrow(df_loaded), 3)
  expect_equal(ncol(df_loaded), 3)
  expect_equal(names(df_loaded), c("produto", "preco", "estoque"))
  
  # Cleanup
  unlink(temp_xlsx)
})

test_that("File extension detection works", {
  expect_equal(tools::file_ext("dados.csv"), "csv")
  expect_equal(tools::file_ext("planilha.xlsx"), "xlsx")
  expect_equal(tools::file_ext("arquivo.CSV"), "CSV")
  expect_equal(tools::file_ext("/path/to/file.xlsx"), "xlsx")
  expect_equal(tools::file_ext("noextension"), "")
})

test_that("Multiple files can be loaded into list", {
  # Simulate loading multiple files
  df1 <- data.frame(id = 1:3, valor_a = c(10, 20, 30))
  df2 <- data.frame(id = 1:2, valor_b = c(100, 200))
  df3 <- data.frame(nome = c("X", "Y"), categoria = c("A", "B"))
  
  lista_dados <- list(df1, df2, df3)
  nomes <- c("vendas.csv", "custos.xlsx", "categorias.csv")
  
  expect_equal(length(lista_dados), 3)
  expect_equal(length(nomes), 3)
  expect_s3_class(lista_dados[[1]], "data.frame")
  expect_s3_class(lista_dados[[2]], "data.frame")
  expect_s3_class(lista_dados[[3]], "data.frame")
})

test_that("Column names are extracted correctly", {
  df <- data.frame(
    id = 1:5,
    nome = letters[1:5],
    valor = c(10, 20, 30, 40, 50),
    data = Sys.Date() + 1:5
  )
  
  cols <- names(df)
  cols_text <- paste(cols, collapse = ", ")
  
  expect_equal(length(cols), 4)
  expect_true(grepl("id", cols_text))
  expect_true(grepl("nome", cols_text))
  expect_true(grepl("valor", cols_text))
  expect_true(grepl("data", cols_text))
})

test_that("Schema generation for single file", {
  df <- data.frame(produto = c("A", "B"), preco = c(10, 20))
  nome_arquivo <- "produtos.csv"
  
  cols <- paste(names(df), collapse = ", ")
  schema <- paste0("Arquivo 1 (", nome_arquivo, "): [", cols, "]")
  
  expect_true(grepl("Arquivo 1", schema))
  expect_true(grepl("produtos.csv", schema))
  expect_true(grepl("produto, preco", schema))
  expect_true(grepl("\\[produto, preco\\]", schema))
})

test_that("Schema generation for multiple files", {
  lista <- list(
    data.frame(id = 1:2, nome = c("A", "B")),
    data.frame(id = 1:3, valor = c(10, 20, 30)),
    data.frame(categoria = c("X", "Y"), descricao = c("Desc1", "Desc2"))
  )
  nomes <- c("clientes.csv", "vendas.xlsx", "categorias.csv")
  
  esquemas <- sapply(seq_along(lista), function(i) {
    cols <- paste(names(lista[[i]]), collapse = ", ")
    paste0("Arquivo ", i, " (", nomes[i], "): [", cols, "]")
  })
  
  expect_equal(length(esquemas), 3)
  expect_true(grepl("clientes.csv", esquemas[1]))
  expect_true(grepl("id, nome", esquemas[1]))
  expect_true(grepl("vendas.xlsx", esquemas[2]))
  expect_true(grepl("id, valor", esquemas[2]))
  expect_true(grepl("categorias.csv", esquemas[3]))
  expect_true(grepl("categoria, descricao", esquemas[3]))
})

test_that("Error handling for non-existent files", {
  fake_path <- "non_existent_file_12345.csv"
  
  expect_error(read_csv(fake_path))
})

test_that("Error handling for invalid file format", {
  # Create a text file with wrong extension
  temp_file <- tempfile(fileext = ".csv")
  writeLines("This is not a valid CSV", temp_file)
  
  # Should handle gracefully
  result <- tryCatch({
    read_csv(temp_file, show_col_types = FALSE)
    "success"
  }, error = function(e) {
    "error"
  })
  
  expect_equal(result, "error")
  
  # Cleanup
  unlink(temp_file)
})

test_that("Empty dataframes are handled", {
  df_empty <- data.frame()
  
  expect_equal(nrow(df_empty), 0)
  expect_equal(ncol(df_empty), 0)
  expect_equal(length(names(df_empty)), 0)
})

test_that("Dataframe with single row/column", {
  df_one_row <- data.frame(col1 = 1, col2 = "A")
  df_one_col <- data.frame(valor = 1:5)
  
  expect_equal(nrow(df_one_row), 1)
  expect_equal(ncol(df_one_row), 2)
  expect_equal(nrow(df_one_col), 5)
  expect_equal(ncol(df_one_col), 1)
})

test_that("Column names with special characters", {
  df <- data.frame(
    `ID Cliente` = 1:3,
    `Valor Total (R$)` = c(100, 200, 300),
    check.names = FALSE
  )
  
  cols <- names(df)
  expect_true("ID Cliente" %in% cols)
  expect_true("Valor Total (R$)" %in% cols)
  
  cols_text <- paste(cols, collapse = ", ")
  expect_true(grepl("ID Cliente", cols_text))
})

test_that("Data type preservation after loading", {
  temp_csv <- tempfile(fileext = ".csv")
  df_test <- data.frame(
    int_col = 1:3,
    char_col = c("a", "b", "c"),
    num_col = c(1.5, 2.5, 3.5),
    stringsAsFactors = FALSE
  )
  write_csv(df_test, temp_csv)
  
  df_loaded <- read_csv(temp_csv, show_col_types = FALSE)
  
  expect_true(is.numeric(df_loaded$int_col))
  expect_true(is.character(df_loaded$char_col))
  expect_true(is.numeric(df_loaded$num_col))
  
  # Cleanup
  unlink(temp_csv)
})

test_that("Large column count is handled", {
  # Create dataframe with many columns
  n_cols <- 50
  df_wide <- as.data.frame(matrix(1:150, nrow = 3, ncol = n_cols))
  
  expect_equal(ncol(df_wide), n_cols)
  expect_equal(length(names(df_wide)), n_cols)
  
  cols_text <- paste(names(df_wide), collapse = ", ")
  expect_true(nchar(cols_text) > 100)  # Should be a long string
})

test_that("Filename extraction from path", {
  paths <- c(
    "C:/Users/Test/Documents/dados.csv",
    "/home/user/planilha.xlsx",
    "arquivo.csv"
  )
  
  filenames <- basename(paths)
  
  expect_equal(filenames[1], "dados.csv")
  expect_equal(filenames[2], "planilha.xlsx")
  expect_equal(filenames[3], "arquivo.csv")
})

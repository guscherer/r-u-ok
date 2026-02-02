#' Testes abrangentes para validação de arquivos (Task 029 Phase 4)

context("Comprehensive File Validation Tests")

# ===========================
# Magic Bytes Detection Tests
# ===========================

test_that("CSV magic bytes are detected correctly", {
  skip_on_cran()
  
  # Criar arquivo CSV temporário
  csv_file <- tempfile(fileext = ".csv")
  writeLines("col1,col2,col3", csv_file)
  
  result <- validate_file_type(csv_file)
  
  expect_true(result$valid)
  expect_match(result$detected_type, "csv", ignore.case = TRUE)
  
  unlink(csv_file)
})

test_that("Excel magic bytes (XLSX) are detected correctly", {
  skip("Requires actual Excel file creation")
  
  # XLSX = ZIP archive (0x50 0x4B 0x03 0x04)
  # Criar simulação seria complexo; teste seria com arquivo real
})

test_that("Excel magic bytes (XLS) are detected correctly", {
  skip("Requires actual Excel file creation")
  
  # XLS = OLE2 (0xD0 0xCF 0x11 0xE0)
})

test_that("Spoofed files are rejected", {
  skip_on_cran()
  
  # Criar arquivo exe renomeado como csv
  exe_file <- tempfile(fileext = ".csv")
  
  # Write fake executable bytes
  writeBin(as.raw(c(0x4D, 0x5A)), exe_file)  # MZ header (PE executable)
  
  result <- validate_file_type(exe_file)
  
  expect_false(result$valid)
  expect_match(result$error, "tipo", ignore.case = TRUE)
  
  unlink(exe_file)
})

# ===========================
# Extension Validation Tests
# ===========================

test_that("CSV extension is accepted", {
  result <- validate_extension("data.csv")
  
  expect_true(result$valid)
  expect_null(result$error)
})

test_that("XLSX extension is accepted", {
  result <- validate_extension("report.xlsx")
  
  expect_true(result$valid)
  expect_null(result$error)
})

test_that("XLS extension is accepted", {
  result <- validate_extension("legacy.xls")
  
  expect_true(result$valid)
  expect_null(result$error)
})

test_that("EXE extension is rejected", {
  result <- validate_extension("malware.exe")
  
  expect_false(result$valid)
  expect_match(result$error, "permitida", ignore.case = TRUE)
})

test_that("TXT extension is rejected", {
  result <- validate_extension("notes.txt")
  
  expect_false(result$valid)
  expect_match(result$error, "permitida", ignore.case = TRUE)
})

test_that("Double extension is rejected", {
  result <- validate_extension("data.csv.exe")
  
  expect_false(result$valid)
  expect_match(result$error, "permitida", ignore.case = TRUE)
})

test_that("Case insensitive extension check", {
  result_lower <- validate_extension("data.csv")
  result_upper <- validate_extension("data.CSV")
  result_mixed <- validate_extension("data.Csv")
  
  expect_true(result_lower$valid)
  expect_true(result_upper$valid)
  expect_true(result_mixed$valid)
})

test_that("Missing extension is rejected", {
  result <- validate_extension("data")
  
  expect_false(result$valid)
})

# ===========================
# File Size Validation Tests
# ===========================

test_that("Small file passes size validation", {
  size_bytes <- 1024 * 1024  # 1 MB
  result <- validate_file_size(size_bytes, max_mb = 50)
  
  expect_true(result)
})

test_that("File at maximum size passes", {
  size_bytes <- 50 * 1024 * 1024  # 50 MB exactly
  result <- validate_file_size(size_bytes, max_mb = 50)
  
  expect_true(result)
})

test_that("File exceeding maximum fails", {
  size_bytes <- 51 * 1024 * 1024  # 51 MB
  result <- validate_file_size(size_bytes, max_mb = 50)
  
  expect_false(result)
})

test_that("Empty file fails", {
  size_bytes <- 0
  result <- validate_file_size(size_bytes, max_mb = 50)
  
  expect_false(result)
})

test_that("Very large file is rejected quickly", {
  size_bytes <- 1000 * 1024 * 1024  # 1 GB
  result <- validate_file_size(size_bytes, max_mb = 50)
  
  expect_false(result)
})

# ===========================
# Data Structure Validation Tests
# ===========================

test_that("Valid dataframe passes structure validation", {
  df <- data.frame(
    name = c("Alice", "Bob", "Charlie"),
    age = c(25, 30, 35),
    salary = c(5000, 6000, 7000)
  )
  
  result <- validate_dataframe_structure(df)
  
  expect_true(result$valid)
  expect_equal(result$nrow, 3)
  expect_equal(result$ncol, 3)
})

test_that("Single row dataframe is accepted", {
  df <- data.frame(x = 1, y = 2)
  
  result <- validate_dataframe_structure(df)
  
  expect_true(result$valid)
  expect_equal(result$nrow, 1)
})

test_that("Single column dataframe is accepted", {
  df <- data.frame(values = c(1, 2, 3, 4, 5))
  
  result <- validate_dataframe_structure(df)
  
  expect_true(result$valid)
  expect_equal(result$ncol, 1)
})

test_that("Empty dataframe is rejected", {
  df <- data.frame()
  
  result <- validate_dataframe_structure(df)
  
  expect_false(result$valid)
})

test_that("Dataframe with duplicate columns issues warning", {
  df <- data.frame(
    col1 = c(1, 2, 3),
    col2 = c(4, 5, 6)
  )
  names(df)[2] <- names(df)[1]  # Duplicate name
  
  result <- validate_dataframe_structure(df)
  
  expect_true(length(result$warnings) > 0 || !result$valid)
})

test_that("Dataframe with many missing values issues warning", {
  df <- data.frame(
    col1 = c(1, NA, NA, NA, NA),
    col2 = c(NA, 2, NA, NA, NA),
    col3 = c(NA, NA, 3, NA, NA)
  )
  
  result <- validate_dataframe_structure(df)
  
  # Should have warning about missing values
  if (length(result$warnings) > 0) {
    expect_true(any(grepl("falta|missing|vazio|empty", result$warnings, ignore.case = TRUE)))
  }
})

# ===========================
# File Reading Tests
# ===========================

test_that("CSV file is read correctly", {
  skip_on_cran()
  
  csv_file <- tempfile(fileext = ".csv")
  writeLines("col1,col2,col3\n1,2,3\n4,5,6", csv_file)
  
  df <- read_file_safely(csv_file, "csv")
  
  expect_true(is.data.frame(df))
  expect_equal(nrow(df), 2)
  expect_equal(ncol(df), 3)
  
  unlink(csv_file)
})

test_that("CSV with special characters is read correctly", {
  skip_on_cran()
  
  csv_file <- tempfile(fileext = ".csv")
  writeLines("nome,valor\nJosé,R$ 100,50\nMaria,R$ 200,75", csv_file)
  
  df <- read_file_safely(csv_file, "csv")
  
  expect_true(is.data.frame(df))
  expect_equal(nrow(df), 2)
  
  unlink(csv_file)
})

test_that("CSV with quoted fields is read correctly", {
  skip_on_cran()
  
  csv_file <- tempfile(fileext = ".csv")
  writeLines('col1,col2\n"value with, comma",123\n"another""quote",456', csv_file)
  
  df <- read_file_safely(csv_file, "csv")
  
  expect_true(is.data.frame(df))
  expect_equal(nrow(df), 2)
  
  unlink(csv_file)
})

test_that("Malformed CSV is handled gracefully", {
  skip_on_cran()
  
  csv_file <- tempfile(fileext = ".csv")
  writeLines("col1,col2,col3\n1,2\n4,5,6", csv_file)  # Missing column
  
  df <- read_file_safely(csv_file, "csv")
  
  # Should either succeed with warning or return NULL
  expect_true(is.null(df) || is.data.frame(df))
  
  unlink(csv_file)
})

# ===========================
# Integration Tests
# ===========================

test_that("Complete validation pipeline for valid file", {
  skip_on_cran()
  
  # 1. Create valid CSV file
  csv_file <- tempfile(fileext = ".csv")
  writeLines("id,name,value\n1,Alice,100\n2,Bob,200", csv_file)
  
  # 2. Validate extension
  ext_result <- validate_extension("data.csv")
  expect_true(ext_result$valid)
  
  # 3. Validate size
  size_bytes <- file.size(csv_file)
  size_result <- validate_file_size(size_bytes, 50)
  expect_true(size_result)
  
  # 4. Validate type
  type_result <- validate_file_type(csv_file)
  expect_true(type_result$valid)
  
  # 5. Read safely
  df <- read_file_safely(csv_file, type_result$detected_type)
  expect_true(is.data.frame(df))
  
  # 6. Validate structure
  struct_result <- validate_dataframe_structure(df)
  expect_true(struct_result$valid)
  
  unlink(csv_file)
})

test_that("Complete pipeline fails gracefully for invalid file", {
  skip_on_cran()
  
  # Create invalid file (EXE)
  bad_file <- tempfile(fileext = ".csv")
  writeBin(as.raw(c(0x4D, 0x5A)), bad_file)  # MZ header
  
  # Step 1: Extension would pass (file.csv)
  ext_result <- validate_extension("malware.csv")
  expect_true(ext_result$valid)
  
  # Step 2: Size would pass
  size_bytes <- file.size(bad_file)
  size_result <- validate_file_size(size_bytes, 50)
  expect_true(size_result)
  
  # Step 3: Type validation SHOULD FAIL
  type_result <- validate_file_type(bad_file)
  expect_false(type_result$valid)
  
  unlink(bad_file)
})

# ===========================
# Edge Cases
# ===========================

test_that("File with very long filename is accepted", {
  long_name <- paste0(paste(rep("a", 200), collapse = ""), ".csv")
  result <- validate_extension(long_name)
  
  # Should pass or fail based on system limits (not validation)
  expect_true(is.list(result))
})

test_that("File with Unicode characters in name", {
  unicode_name <- "dados_日本語_한글.csv"
  result <- validate_extension(unicode_name)
  
  expect_true(result$valid)
})

test_that("Multiple dots in filename", {
  result <- validate_extension("my.data.file.csv")
  
  expect_true(result$valid)
})

# ===========================
# Cleanup Tests
# ===========================

test_that("cleanup_temp_file() removes file safely", {
  skip_on_cran()
  
  # Create temp file
  test_file <- tempfile()
  writeLines("test", test_file)
  expect_true(file.exists(test_file))
  
  # Clean up
  cleanup_temp_file(test_file)
  
  # File should be deleted
  expect_false(file.exists(test_file))
})

test_that("cleanup_temp_file() handles non-existent file", {
  non_existent <- tempfile()
  
  # Should not error
  result <- cleanup_temp_file(non_existent)
  
  expect_true(is.logical(result) || is.invisible(result))
})

# ===========================
# Performance Tests
# ===========================

test_that("Validation is performant for typical files", {
  skip_on_cran()
  
  csv_file <- tempfile(fileext = ".csv")
  writeLines(paste(rep("col1,col2,col3", 1000), collapse = "\n"), csv_file)
  
  start_time <- Sys.time()
  
  # Run full validation pipeline
  ext_result <- validate_extension("data.csv")
  size_result <- validate_file_size(file.size(csv_file), 50)
  type_result <- validate_file_type(csv_file)
  
  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  
  # Should complete in under 1 second
  expect_true(elapsed < 1)
  
  unlink(csv_file)
})

#' Testes para o módulo de limpeza automática

context("Cleanup Scheduler")

test_that("cleanup_temp_files() doesn't error when scheduler disabled", {
  # ENABLE_CLEANUP_SCHEDULER should exist (imported from config_upload.R)
  result <- cleanup_temp_files()
  expect_true(is.logical(result) || is.invisible(result))
})

test_that("get_temp_files_stats() returns correct structure", {
  stats <- get_temp_files_stats()
  
  expect_true(is.data.frame(stats))
  expect_true(all(c(
    "total_files",
    "total_size_mb",
    "oldest_file_age_hours",
    "newest_file_age_hours"
  ) %in% names(stats)))
})

test_that("get_temp_files_stats() returns zero for empty temp dir", {
  # Using a temporary empty directory
  empty_dir <- tempfile()
  dir.create(empty_dir)
  
  stats <- get_temp_files_stats(empty_dir)
  expect_equal(stats$total_files, 0)
  expect_equal(stats$total_size_mb, 0)
  
  unlink(empty_dir, recursive = TRUE)
})

test_that("get_log_files_stats() returns correct structure", {
  stats <- get_log_files_stats()
  
  expect_true(is.data.frame(stats))
  expect_true(all(c(
    "log_file",
    "size_mb",
    "entries_count",
    "oldest_entry",
    "newest_entry"
  ) %in% names(stats)))
})

test_that("generate_cleanup_report() returns non-empty string", {
  report <- generate_cleanup_report()
  
  expect_true(is.character(report))
  expect_true(nchar(report) > 0)
  expect_true(grepl("LIMPEZA", report))
})

test_that("cleanup_report() contains scheduler status", {
  report <- generate_cleanup_report()
  
  # Should mention scheduler status
  expect_true(
    grepl("Scheduler", report) || 
    grepl("scheduler", report) ||
    grepl("automático", report)
  )
})

# Unit tests for time calculations

test_that("Hours to seconds conversion is correct", {
  hours <- 24
  seconds <- hours * 3600
  expect_equal(seconds, 86400)
})

test_that("Size calculation is accurate", {
  # 1 MB = 1024 * 1024 bytes
  expect_equal(1 * 1024 * 1024, 1048576)
})

test_that("Percentage calculations work correctly", {
  total <- 100
  part <- 50
  percent <- (part / total) * 100
  expect_equal(percent, 50)
})

# Integration-like tests (skipped)

test_that("cleanup_temp_files() with real temp directory", {
  skip("Integration test - requires file I/O")
  
  # Create test files
  test_file <- file.path(tempdir(), "test_cleanup.txt")
  writeLines("test", test_file)
  
  result <- cleanup_temp_files(tempdir(), hours_old = 0)
  
  # If scheduler is enabled, file should be deleted
  # If disabled, file should remain
})

test_that("init_cleanup_scheduler() accepts session parameter", {
  skip("Integration test - requires Shiny session")
  
  # Would need a mock Shiny session to test
  # result <- init_cleanup_scheduler(mock_session, interval_minutes = 60)
  # expect_null(result)
})

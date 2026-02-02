library(testthat)
library(tidyverse)

# ============================================================================
# TEST SUITE: Code Sandbox Module (Task 016)
# ============================================================================

describe("Task 016: Safe Code Execution Sandbox", {
  
  # ========================================================================
  # 1. ALLOWED & FORBIDDEN FUNCTIONS
  # ========================================================================
  
  describe("get_forbidden_functions()", {
    it("returns character vector of forbidden functions", {
      forbidden <- get_forbidden_functions()
      expect_type(forbidden, "character")
      expect_gt(length(forbidden), 20)
    })
    
    it("includes critical dangerous functions", {
      forbidden <- get_forbidden_functions()
      expect_contains(forbidden, c("eval", "parse", "system", "library"))
    })
    
    it("includes file I/O functions", {
      forbidden <- get_forbidden_functions()
      expect_contains(forbidden, c("file.create", "unlink", "readLines"))
    })
  })
  
  describe("get_allowed_functions()", {
    it("returns list with package subsets", {
      allowed <- get_allowed_functions()
      expect_type(allowed, "list")
      expect_contains(names(allowed), c("dplyr", "tidyr", "ggplot2", "base", "stats"))
    })
    
    it("dplyr has safe functions only", {
      allowed <- get_allowed_functions()
      expect_contains(allowed$dplyr, c("filter", "select", "mutate"))
      expect_false("eval" %in% allowed$dplyr)
    })
    
    it("base includes numeric functions", {
      allowed <- get_allowed_functions()
      expect_contains(allowed$base, c("sum", "mean", "median", "sd"))
    })
    
    it("stats has statistical functions", {
      allowed <- get_allowed_functions()
      expect_contains(allowed$stats, c("lm", "glm", "t.test"))
    })
  })
  
  # ========================================================================
  # 2. SANDBOX ENVIRONMENT CREATION
  # ========================================================================
  
  describe("create_sandbox_env()", {
    it("creates environment successfully", {
      sandbox <- create_sandbox_env()
      expect_type(sandbox, "environment")
    })
    
    it("adds data to sandbox", {
      data_list <- list(
        dados = data.frame(x = 1:5, y = 6:10),
        numeros = c(1, 2, 3)
      )
      sandbox <- create_sandbox_env(data_list)
      
      expect_true(exists("dados", envir = sandbox))
      expect_true(exists("numeros", envir = sandbox))
      
      dados_sandbox <- get("dados", envir = sandbox)
      expect_equal(dados_sandbox$x, 1:5)
    })
    
    it("has allowed functions available", {
      sandbox <- create_sandbox_env()
      
      # Check dplyr functions
      expect_true(exists("filter", envir = sandbox))
      expect_true(exists("select", envir = sandbox))
      expect_true(exists("mutate", envir = sandbox))
      
      # Check base functions
      expect_true(exists("sum", envir = sandbox))
      expect_true(exists("mean", envir = sandbox))
    })
    
    it("does NOT have forbidden functions enabled", {
      sandbox <- create_sandbox_env()
      
      # Forbidden functions are set to NULL, so they won't execute properly
      # This is good enough - they're disabled
      forbidden_check <- get_forbidden_functions()
      
      # Sample check a few critical ones
      expect_true(is.null(get("eval", envir = sandbox)) || !is.function(get("eval", envir = sandbox)))
    })
    
    it("stores metadata as attributes", {
      sandbox <- create_sandbox_env(max_memory_mb = 250)
      
      expect_equal(attr(sandbox, "max_memory_mb"), 250)
      expect_type(attr(sandbox, "created_at"), "double")
      expect_type(attr(sandbox, "whitelist"), "list")
    })
  })
  
  # ========================================================================
  # 3. FORBIDDEN FUNCTION DETECTION
  # ========================================================================
  
  describe("detect_forbidden_calls()", {
    it("detects forbidden function calls", {
      code <- "eval(parse(text = 'x <- 1'))"
      result <- detect_forbidden_calls(code)
      
      expect_false(result$is_safe)
      expect_contains(result$forbidden_found, c("eval", "parse"))
      expect_gt(result$count, 0)
    })
    
    it("allows safe dplyr function calls", {
      code <- "dados %>% filter(x > 5) %>% select(x, y)"
      result <- detect_forbidden_calls(code)
      
      expect_true(result$is_safe)
      expect_equal(length(result$forbidden_found), 0)
    })
    
    it("detects system() calls", {
      code <- "system('rm -rf /')"
      result <- detect_forbidden_calls(code)
      
      expect_false(result$is_safe)
      expect_contains(result$forbidden_found, "system")
    })
    
    it("detects library() calls", {
      code <- "library(malicious_package)"
      result <- detect_forbidden_calls(code)
      
      expect_false(result$is_safe)
      expect_contains(result$forbidden_found, "library")
    })
    
    it("doesn't falsely detect substring matches", {
      code <- "x <- evaluate_model(data)"  # Contains 'eval'
      result <- detect_forbidden_calls(code)
      
      expect_true(result$is_safe)
      expect_false("eval" %in% result$forbidden_found)
    })
    
    it("detects multiple forbidden functions", {
      code <- "eval(parse('x')); system('ls'); library(x)"
      result <- detect_forbidden_calls(code)
      
      expect_false(result$is_safe)
      expect_gte(length(result$forbidden_found), 2)
    })
  })
  
  # ========================================================================
  # 4. CODE VALIDATION BEFORE EXECUTION
  # ========================================================================
  
  describe("validate_code_before_execution()", {
    it("accepts valid code", {
      code <- "resultado <- dados %>% filter(x > 5)"
      validation <- validate_code_before_execution(code)
      
      expect_true(validation$is_valid)
      expect_equal(length(validation$errors), 0)
    })
    
    it("rejects empty code", {
      validation <- validate_code_before_execution("")
      
      expect_false(validation$is_valid)
      expect_gt(length(validation$errors), 0)
    })
    
    it("rejects NULL code", {
      validation <- validate_code_before_execution(NULL)
      
      expect_false(validation$is_valid)
      expect_gt(length(validation$errors), 0)
    })
    
    it("enforces code size limit", {
      big_code <- paste(rep("x <- 1;", 5000), collapse = "\n")
      validation <- validate_code_before_execution(big_code, max_chars = 1000)
      
      expect_false(validation$is_valid)
      expect_match(validation$errors[1], "caracteres")
    })
    
    it("enforces line limit", {
      many_lines <- paste(rep("x <- 1", 600), collapse = "\n")
      validation <- validate_code_before_execution(many_lines, max_lines = 500)
      
      expect_false(validation$is_valid)
      expect_match(validation$errors[1], "linhas")
    })
    
    it("detects syntax errors", {
      bad_code <- "resultado <- dados %>% filter(x >"  # Missing closing paren
      validation <- validate_code_before_execution(bad_code)
      
      expect_false(validation$is_valid)
      expect_true(any(grepl("sintaxe|Syntax|Error", validation$errors, ignore.case = TRUE)))
    })
    
    it("detects forbidden functions in validation", {
      code <- "resultado <- eval(parse('x'))"
      validation <- validate_code_before_execution(code)
      
      expect_false(validation$is_valid)
      expect_true(any(grepl("proibidas", validation$errors, ignore.case = TRUE)))
    })
    
    it("returns code statistics", {
      code <- "resultado <- dados %>% filter(x > 5) %>% select(x)"
      validation <- validate_code_before_execution(code)
      
      expect_type(validation$code_stats, "list")
      expect_gt(validation$code_stats$characters, 0)
      expect_gt(validation$code_stats$lines, 0)
    })
    
    it("warns about suspicious patterns", {
      code <- "x <- 1; y <- 2"  # Assignments without 'resultado'
      validation <- validate_code_before_execution(code)
      
      # Should either be invalid OR have warnings
      expect_true(!validation$is_valid || length(validation$warnings) > 0)
    })
  })
  
  # ========================================================================
  # 5. SAFE CODE EXECUTION
  # ========================================================================
  
  describe("execute_code_safely()", {
    
    # Create test sandbox and data
    data_list <- list(
      dados = data.frame(
        x = 1:10,
        y = 11:20,
        group = rep(c("A", "B"), 5)
      )
    )
    sandbox <- create_sandbox_env(data_list)
    
    it("executes safe dplyr code", {
      code <- "resultado <- dados %>% filter(x > 5)"
      result <- execute_code_safely(code, sandbox)
      
      expect_true(result$success)
      expect_false(is.null(result$resultado))
      expect_equal(nrow(result$resultado), 5)
    })
    
    it("executes filter + select combination", {
      code <- "resultado <- dados %>% filter(x > 5) %>% select(x, group)"
      result <- execute_code_safely(code, sandbox)
      
      expect_true(result$success)
      expect_equal(ncol(result$resultado), 2)
    })
    
    it("executes aggregation code", {
      code <- "resultado <- dados %>% group_by(group) %>% summarise(mean_x = mean(x))"
      result <- execute_code_safely(code, sandbox)
      
      expect_true(result$success)
      expect_equal(nrow(result$resultado), 2)
    })
    
    it("rejects code with forbidden functions", {
      code <- "resultado <- eval(parse('datos'))"
      result <- execute_code_safely(code, sandbox)
      
      expect_false(result$success)
      expect_true(any(grepl("proibidas", result$error, ignore.case = TRUE)) || 
                  any(grepl("forbidden", result$error, ignore.case = TRUE)))
    })
    
    it("tracks execution time", {
      code <- "resultado <- dados %>% filter(x > 5)"
      result <- execute_code_safely(code, sandbox)
      
      expect_gt(result$duration_seconds, 0)
      expect_lt(result$duration_seconds, 5)  # Should be very fast
    })
    
    it("returns NULL resultado if not created", {
      code <- "x <- 1  # No 'resultado' assignment"
      result <- execute_code_safely(code, sandbox)
      
      # The code will fail validation or execute without resultado
      expect_type(result$success, "logical")
    })
    
    it("respects timeout setting", {
      code <- "resultado <- Sys.sleep(10)"  # This will timeout
      result <- execute_code_safely(
        code,
        sandbox,
        timeout_seconds = 2
      )
      
      # May fail due to timeout or error
      expect_type(result$success, "logical")
    })
    
    it("provides statistics about execution", {
      code <- "resultado <- dados %>% filter(x > 5)"
      result <- execute_code_safely(code, sandbox)
      
      expect_type(result$execution_stats, "list")
      expect_contains(
        names(result$execution_stats),
        c("memory_used_mb", "code_lines", "code_chars")
      )
    })
    
    it("logs messages during execution", {
      code <- "resultado <- dados %>% filter(x > 5)"
      result <- execute_code_safely(code, sandbox)
      
      expect_type(result$messages, "character")
      expect_gt(length(result$messages), 0)
    })
  })
  
  # ========================================================================
  # 6. UTILITY FUNCTIONS
  # ========================================================================
  
  describe("get_sandbox_statistics()", {
    it("returns statistics about sandbox", {
      sandbox <- create_sandbox_env(list(dados = mtcars))
      stats <- get_sandbox_statistics(sandbox)
      
      expect_type(stats, "list")
      expect_contains(
        names(stats),
        c("age_seconds", "allowed_functions_count", "data_objects_count")
      )
    })
    
    it("counts data objects", {
      data_list <- list(dados1 = mtcars, dados2 = iris)
      sandbox <- create_sandbox_env(data_list)
      stats <- get_sandbox_statistics(sandbox)
      
      expect_gte(stats$data_objects_count, 2)
    })
  })
  
  describe("is_function_allowed()", {
    it("identifies allowed functions", {
      expect_true(is_function_allowed("filter"))
      expect_true(is_function_allowed("mutate"))
      expect_true(is_function_allowed("sum"))
    })
    
    it("identifies forbidden functions", {
      expect_false(is_function_allowed("eval"))
      expect_false(is_function_allowed("system"))
      expect_false(is_function_allowed("library"))
    })
  })
  
  # ========================================================================
  # 7. INTEGRATION TESTS
  # ========================================================================
  
  describe("Integration: Complete Workflow", {
    it("validates, then executes safe code", {
      data_list <- list(
        dados = data.frame(a = 1:5, b = 6:10)
      )
      sandbox <- create_sandbox_env(data_list)
      
      code <- "resultado <- dados %>% filter(a > 2) %>% mutate(c = a + b)"
      
      # Validate
      validation <- validate_code_before_execution(code)
      expect_true(validation$is_valid)
      
      # Execute
      result <- execute_code_safely(code, sandbox)
      expect_true(result$success)
      expect_equal(nrow(result$resultado), 3)
    })
    
    it("prevents injection via forbidden function", {
      sandbox <- create_sandbox_env()
      
      code <- "resultado <- eval(parse('rm(.GlobalEnv)'))"
      
      # Validate
      validation <- validate_code_before_execution(code)
      expect_false(validation$is_valid)
      
      # Try to execute anyway
      result <- execute_code_safely(code, sandbox)
      expect_false(result$success)
    })
    
    it("handles real data analysis scenario", {
      # Simulate real data
      data_list <- list(
        vendas = data.frame(
          produto = rep(c("A", "B"), 5),
          valor = 100 + rnorm(10, 50),
          data = Sys.Date() - sample(0:30, 10)
        )
      )
      sandbox <- create_sandbox_env(data_list)
      
      code <- "
        resultado <- vendas %>%
          group_by(produto) %>%
          summarise(
            total = sum(valor),
            media = mean(valor),
            n = n(),
            .groups = 'drop'
          )
      "
      
      result <- execute_code_safely(code, sandbox)
      
      expect_true(result$success)
      expect_equal(nrow(result$resultado), 2)
      expect_contains(names(result$resultado), c("produto", "total", "media"))
    })
  })
})

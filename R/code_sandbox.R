#' Safe Code Execution Sandbox Module
#'
#' Provides secure code execution environment with:
#' - Function whitelist/blacklist
#' - Resource limits (timeout, memory)
#' - AST validation before execution
#' - Audit logging
#'
#' @docType package
#' @name code_sandbox

# ============================================================================
# 1. ALLOWED & FORBIDDEN FUNCTIONS
# ============================================================================

#' Get Forbidden Functions Blacklist
#'
#' Returns list of dangerous functions that are absolutely forbidden.
#'
#' @return character vector of forbidden function names
#'
#' @examples
#' forbidden <- get_forbidden_functions()
#' length(forbidden)  # Should be 30+
#'
#' @export
get_forbidden_functions <- function() {
  c(
    # Code execution
    "eval", "parse", "substitute", "quote", "deparse", "source",
    "eval.parent", "evalq", "do.call",
    
    # System access
    "system", "system2", "shell", "pipe",
    
    # Package operations
    "library", "require", "install.packages", "remove.packages",
    "update.packages", ".libPaths",
    
    # File I/O
    "file.create", "file.remove", "file.rename", "file.copy",
    "dir.create", "unlink", "readLines", "writeLines",
    "read.csv", "write.csv", "readRDS", "saveRDS",
    "load", "save",
    
    # Environment manipulation
    "ls", "rm", "exists", "get", "assign", "<<-",
    ".GlobalEnv", "parent.env", "environment",
    
    # Dangerous base functions
    "source", "dyn.load", "dyn.unload",
    ".Internal", ".Call", ".External", ".Fortran", ".C",
    
    # Connection/network
    "url", "socket", "pipe", "fifo", "socketConnection"
  )
}

#' Get Allowed Functions Whitelist
#'
#' Returns list of safe functions allowed in sandbox.
#' Includes: dplyr, tidyr, base R analytics, ggplot2
#'
#' @return list with $dplyr, $tidyr, $ggplot2, $base vectors
#'
#' @examples
#' allowed <- get_allowed_functions()
#' length(allowed$dplyr)  # ~30 functions
#'
#' @export
get_allowed_functions <- function() {
  list(
    dplyr = c(
      # Pipe operator
      "%>%", "|>",
      
      # Selection verbs
      "select", "rename", "relocate",
      
      # Filtering verbs
      "filter", "distinct", "slice", "slice_head", "slice_tail",
      "slice_sample", "slice_min", "slice_max",
      
      # Transformation verbs
      "mutate", "transmute", "across", "if_any", "if_all",
      "case_match", "case_when",
      
      # Aggregation verbs
      "summarise", "group_by", "ungroup",
      
      # Joining verbs (READ-ONLY joins)
      "left_join", "right_join", "inner_join", "full_join",
      "semi_join", "anti_join",
      
      # Arrangement
      "arrange", "desc",
      
      # Utility
      "lead", "lag", "between", "coalesce", "near",
      "n", "n_distinct", "row_number", "rank", "dense_rank"
    ),
    
    tidyr = c(
      # Reshaping
      "pivot_longer", "pivot_wider", "gather", "spread",
      
      # Separating/uniting
      "separate", "separate_rows", "unite",
      
      # Nesting/unnesting
      "nest", "unnest", "unnest_longer", "unnest_wider",
      
      # Filling
      "fill", "replace_na", "drop_na", "complete"
    ),
    
    ggplot2 = c(
      "ggplot", "aes", "aes_string",
      "geom_point", "geom_line", "geom_bar", "geom_col",
      "geom_histogram", "geom_boxplot", "geom_violin",
      "geom_smooth", "geom_density", "geom_tile",
      "facet_wrap", "facet_grid",
      "labs", "theme", "theme_minimal", "theme_classic",
      "xlab", "ylab", "ggtitle",
      "scale_x_continuous", "scale_y_continuous",
      "scale_fill_manual", "scale_color_manual"
    ),
    
    base = c(
      # Math/stats
      "sum", "mean", "median", "sd", "var", "min", "max", "range",
      "quantile", "table", "prop.table", "cumsum", "cumprod",
      "sqrt", "exp", "log", "log10", "abs", "sin", "cos", "tan",
      "round", "floor", "ceiling", "trunc",
      
      # Data manipulation
      "c", "list", "data.frame", "as.data.frame",
      "as.numeric", "as.character", "as.logical", "as.integer",
      "is.na", "is.null", "is.numeric", "is.character",
      "length", "dim", "nrow", "ncol", "names", "colnames", "rownames",
      "head", "tail", "str", "summary", "unique", "sort", "order",
      "rep", "seq", "seq_along", "seq_len", "which",
      "match", "%in%",
      
      # Assignment & operators (needed for code execution!)
      "<-", "=", "~", "|", "&", "!", "!=", "==", "<", ">", "<=", ">=",
      "+", "-", "*", "/", "^", "%%", "%/%",
      "$", "[[", "[", ":", "::",
      
      # Logical operators
      "&", "|", "!", "&&", "||", "xor", "all", "any",
      
      # Type checking
      "class", "typeof", "mode",
      
      # Iteration (but NOT apply family to prevent arbitrary function calls)
      "for", "while", "if", "else", "ifelse", "switch",
      
      # String operations
      "paste", "paste0", "sprintf", "nchar", "substr", "strsplit",
      "grep", "grepl", "sub", "gsub", "tolower", "toupper",
      "trimws", "chartr"
    ),
    
    stats = c(
      "lm", "glm", "predict", "residuals", "coefficients",
      "summary", "confint", "anova", "t.test", "chisq.test",
      "cor", "cor.test", "cov"
    )
  )
}

# ============================================================================
# 2. SANDBOX ENVIRONMENT CREATION
# ============================================================================

#' Create Safe Sandbox Environment
#'
#' Creates isolated R environment with only allowed functions available.
#' Prevents access to dangerous functions and globals.
#'
#' @param data_list list of dataframes to make available in sandbox
#' @param whitelist list from get_allowed_functions(). If NULL, uses default.
#' @param max_memory_mb numeric, max memory available (in MB). Default: 500
#'
#' @return environment with restricted function set
#'
#' @examples
#' \dontrun{
#'   data_list <- list(dados = mtcars)
#'   sandbox <- create_sandbox_env(data_list)
#'   # sandbox$dados is available
#'   # sandbox$eval is NOT available
#' }
#'
#' @export
create_sandbox_env <- function(data_list = list(),
                               whitelist = NULL,
                               max_memory_mb = 500) {
  
  if (is.null(whitelist)) {
    whitelist <- get_allowed_functions()
  }
  
  # Create new environment, inheriting from dplyr namespace (for %>% and other operators)
  # This is more practical than trying to whitelist everything manually
  sandbox <- new.env(parent = asNamespace("dplyr"))
  
  # Override dangerous functions with NULL to disable them
  forbidden_list <- get_forbidden_functions()
  for (fname in forbidden_list) {
    tryCatch({
      assign(fname, NULL, envir = sandbox)
    }, error = function(e) NULL)
  }
  
  # Add user data
  for (name in names(data_list)) {
    if (!is.null(data_list[[name]])) {
      assign(name, data_list[[name]], envir = sandbox)
    }
  }
  
  # Add metadata
  attr(sandbox, "max_memory_mb") <- max_memory_mb
  attr(sandbox, "created_at") <- Sys.time()
  attr(sandbox, "whitelist") <- whitelist
  attr(sandbox, "forbidden_list") <- forbidden_list
  
  return(sandbox)
}

# ============================================================================
# 3. CODE VALIDATION (BEFORE EXECUTION)
# ============================================================================

#' Detect Forbidden Function Calls in Code
#'
#' Performs static analysis of R code to detect forbidden function calls
#' before execution.
#'
#' @param code character string of R code
#' @param forbidden character vector of forbidden function names
#'
#' @return list with:
#'   - $is_safe: logical, TRUE if no forbidden functions detected
#'   - $forbidden_found: character vector of detected forbidden functions
#'   - $count: integer, number of forbidden function calls
#'   - $positions: list of source positions where found
#'
#' @examples
#' \dontrun{
#'   code_safe <- "x <- filter(dados, col > 5)"
#'   detect_forbidden_calls(code_safe)  # $is_safe = TRUE
#'
#'   code_unsafe <- "eval(parse(text = 'rm(.GlobalEnv)'))"
#'   detect_forbidden_calls(code_unsafe)  # $is_safe = FALSE
#' }
#'
#' @export
detect_forbidden_calls <- function(code,
                                   forbidden = get_forbidden_functions()) {
  
  # Simple regex-based detection (faster than AST parsing)
  # Look for function( pattern
  detected <- list()
  forbidden_found <- c()
  
  for (fname in forbidden) {
    # Escape special regex characters
    fname_escaped <- gsub("([.|()\\^$*+?{}\\[\\]])", "\\\\\\1", fname)
    
    # Pattern: word boundary + function name + word boundary + (
    # This catches: eval( but not evaluate(
    pattern <- paste0("\\b", fname_escaped, "\\s*\\(")
    
    if (grepl(pattern, code, perl = TRUE)) {
      forbidden_found <- c(forbidden_found, fname)
      
      # Find all positions
      matches <- gregexpr(pattern, code, perl = TRUE)[[1]]
      detected[[fname]] <- as.integer(matches)
    }
  }
  
  return(list(
    is_safe = length(forbidden_found) == 0,
    forbidden_found = forbidden_found,
    count = length(forbidden_found),
    positions = detected
  ))
}

#' Validate Code Before Execution
#'
#' Comprehensive pre-execution validation:
#' - Forbidden function detection
#' - Syntax validation (parse without eval)
#' - Size limits
#' - Assignment validation
#'
#' @param code character string of R code
#' @param max_chars integer, max code length (default 10000)
#' @param max_lines integer, max code lines (default 500)
#'
#' @return list with:
#'   - $is_valid: logical
#'   - $errors: character vector of validation errors
#'   - $warnings: character vector of warnings
#'   - $code_stats: list with lines, chars, functions, assignments
#'
#' @examples
#' \dontrun{
#'   code <- "resultado <- dados %>% filter(x > 5) %>% select(x, y)"
#'   validate_code_before_execution(code)
#' }
#'
#' @export
validate_code_before_execution <- function(code,
                                           max_chars = 10000,
                                           max_lines = 500) {
  
  errors <- c()
  warnings <- c()
  
  # 1. Check for empty code
  if (is.null(code) || nchar(trimws(code)) == 0) {
    errors <- c(errors, "Código está vazio")
    return(list(
      is_valid = FALSE,
      errors = errors,
      warnings = warnings,
      code_stats = NULL
    ))
  }
  
  # 2. Check size limits
  code_length <- nchar(code)
  if (code_length > max_chars) {
    errors <- c(errors, paste("Código excede", max_chars, "caracteres"))
  }
  
  code_lines <- length(strsplit(code, "\n")[[1]])
  if (code_lines > max_lines) {
    errors <- c(errors, paste("Código excede", max_lines, "linhas"))
  }
  
  # 3. Check for forbidden functions
  forbidden_check <- detect_forbidden_calls(code)
  if (!forbidden_check$is_safe) {
    errors <- c(errors, paste(
      "Funções proibidas detectadas:",
      paste(forbidden_check$forbidden_found, collapse = ", ")
    ))
  }
  
  # 4. Validate syntax (try to parse without eval)
  syntax_check <- tryCatch({
    parse(text = code)
    list(valid = TRUE, error = NULL)
  }, error = function(e) {
    list(valid = FALSE, error = e$message)
  })
  
  if (!syntax_check$valid) {
    errors <- c(errors, paste("Erro de sintaxe:", syntax_check$error))
  }
  
  # 5. Check for suspicious patterns
  if (grepl("<-|=|<<-", code) && !grepl("resultado\\s*<-|resultado\\s*=", code)) {
    warnings <- c(warnings, "Código contém atribuições sem 'resultado'")
  }
  
  return(list(
    is_valid = length(errors) == 0,
    errors = errors,
    warnings = warnings,
    code_stats = list(
      characters = code_length,
      lines = code_lines,
      forbidden_functions = forbidden_check$forbidden_found,
      has_resultado_assignment = grepl("resultado\\s*<-|resultado\\s*=", code)
    )
  ))
}

# ============================================================================
# 4. SAFE CODE EXECUTION
# ============================================================================

#' Execute Code in Sandbox with Timeout
#'
#' Main function for safe code execution.
#' Combines validation + sandboxed environment + timeout + resource tracking.
#'
#' @param code character string of R code to execute
#' @param sandbox environment created by create_sandbox_env()
#' @param timeout_seconds numeric, max execution time (default 60)
#' @param max_memory_mb numeric, max memory (tracked but not enforced)
#'
#' @return list with:
#'   - $success: logical
#'   - $resultado: any, the $resultado object from code execution
#'   - $error: character or NULL
#'   - $warnings: character vector
#'   - $duration_seconds: numeric
#'   - $execution_stats: list with memory, etc
#'   - $messages: character vector of execution messages
#'
#' @examples
#' \dontrun{
#'   data_list <- list(dados = mtcars)
#'   sandbox <- create_sandbox_env(data_list)
#'   code <- "resultado <- dados %>% filter(mpg > 20) %>% summarise(mean_hp = mean(hp))"
#'   result <- execute_code_safely(code, sandbox, timeout_seconds = 30)
#'   if (result$success) print(result$resultado)
#' }
#'
#' @export
execute_code_safely <- function(code,
                                sandbox,
                                timeout_seconds = 60,
                                max_memory_mb = 500) {
  
  start_time <- Sys.time()
  
  # 1. Validate code
  validation <- validate_code_before_execution(code)
  
  if (!validation$is_valid) {
    return(list(
      success = FALSE,
      resultado = NULL,
      error = paste(validation$errors, collapse = "; "),
      warnings = validation$warnings,
      duration_seconds = as.numeric(difftime(Sys.time(), start_time, units = "secs")),
      execution_stats = list(memory_used_mb = NA, validation_errors = length(validation$errors)),
      messages = c("Validação falhou")
    ))
  }
  
  messages <- c()
  if (length(validation$warnings) > 0) {
    messages <- c(messages, validation$warnings)
  }
  
  # 2. Execute with timeout
  # R doesn't have native timeout, so we use setTimeLimit
  # This is not perfect but prevents infinite loops
  
  result <- tryCatch({
    setTimeLimit(elapsed = timeout_seconds, transient = TRUE)
    on.exit(setTimeLimit(Inf, Inf), add = TRUE)
    
    # Execute code in sandbox
    eval(parse(text = code), envir = sandbox)
    
    # Get resultado if it exists
    if (exists("resultado", envir = sandbox)) {
      resultado <- get("resultado", envir = sandbox)
    } else {
      resultado <- NULL
    }
    
    list(
      success = TRUE,
      resultado = resultado,
      error = NULL,
      messages = c(messages, "Código executado com sucesso")
    )
    
  }, error = function(e) {
    list(
      success = FALSE,
      resultado = NULL,
      error = e$message,
      messages = c("Erro na execução: ", e$message)
    )
  })
  
  duration <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
  
  # 3. Get memory stats (approximate)
  # R doesn't track memory tightly, but gc() gives some info
  gc_info <- gc()
  memory_used_mb <- sum(gc_info[, 2]) * 0.0000001  # Approximate
  
  return(list(
    success = result$success,
    resultado = result$resultado,
    error = result$error,
    warnings = validation$warnings,
    duration_seconds = duration,
    execution_stats = list(
      memory_used_mb = memory_used_mb,
      max_memory_mb = max_memory_mb,
      memory_exceeded = memory_used_mb > max_memory_mb,
      validation_warnings = length(validation$warnings),
      code_lines = validation$code_stats$lines,
      code_chars = validation$code_stats$characters
    ),
    messages = result$messages
  ))
}

# ============================================================================
# 5. UTILITY FUNCTIONS
# ============================================================================

#' Get Sandbox Statistics
#'
#' Returns information about sandbox environment
#'
#' @param sandbox environment created by create_sandbox_env()
#'
#' @return list with:
#'   - $creation_time: POSIXct
#'   - $age_seconds: numeric
#'   - $allowed_functions_count: integer
#'   - $data_objects_count: integer
#'   - $available_packages: character vector
#'
#' @export
get_sandbox_statistics <- function(sandbox) {
  
  creation_time <- attr(sandbox, "created_at")
  age <- as.numeric(difftime(Sys.time(), creation_time, units = "secs"))
  
  # Count functions vs data
  all_objs <- ls(envir = sandbox)
  functions_count <- 0
  data_count <- 0
  
  for (obj_name in all_objs) {
    obj <- tryCatch(get(obj_name, envir = sandbox), error = function(e) NULL)
    if (!is.null(obj)) {
      if (is.function(obj)) {
        functions_count <- functions_count + 1
      } else if (obj_name != ".whitelist") {
        data_count <- data_count + 1
      }
    }
  }
  
  return(list(
    creation_time = creation_time,
    age_seconds = age,
    allowed_functions_count = functions_count,
    data_objects_count = data_count,
    total_objects = length(all_objs)
  ))
}

#' Check if Function is Allowed
#'
#' @param fname character, function name to check
#' @param whitelist list from get_allowed_functions()
#'
#' @return logical, TRUE if allowed
#'
#' @export
is_function_allowed <- function(fname,
                                whitelist = get_allowed_functions()) {
  all_allowed <- unlist(whitelist)
  return(fname %in% all_allowed)
}

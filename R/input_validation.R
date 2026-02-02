#' Input Validation & Prompt Injection Prevention Module
#'
#' Sanitização completa de entrada e detecção de tentativas de prompt injection.
#' Implementa múltiplas camadas de defesa contra ataques a modelos de linguagem.
#'
#' @details
#' Camadas implementadas:
#' 1. Limite de tamanho (evita DoS por entrada grande)
#' 2. Detecção de padrões perigosos (regex-based)
#' 3. Whitelist de caracteres (remove caracteres suspeitos)
#' 4. Análise de código gerado (pre-execution review)
#' 5. Sanitização de nomes de colunas (prevenção de injection via dados)
#'
#' @keywords internal

# ============================================================================
# CONSTANTES DE CONFIGURAÇÃO
# ============================================================================

MAX_PROMPT_LENGTH <- 2000
MAX_COLUMN_NAME_LENGTH <- 100
MAX_TOTAL_COLUMNS <- 50
MAX_SCHEMA_LENGTH <- 5000
MIN_PROMPT_LENGTH <- 10

# Caracteres permitidos (whitelist)
# Suporta: letras (PT-BR/ES), números, pontuação comum
ALLOWED_CHARS_PATTERN <- "[a-zA-Z0-9àáâãäåèéêëìíîïòóôõöùúûüýþÿñçœæÀÁÂÃÄÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜŸÑ\\s.,:;!?()\\[\\]{}'\"-]"

# ============================================================================
# PADRÕES PERIGOSOS (REGEX PATTERNS)
# ============================================================================

#' Obter banco de dados de padrões de ataque
#'
#' Define todos os padrões de regex para detecção de prompt injection
#' e atividades suspeitas.
#'
#' @return Lista aninhada com categorias de padrões
#'
#' @keywords internal
get_attack_patterns_db <- function() {
  list(
    # ========== PADRÕES CRÍTICOS (Bloqueio Total) ==========
    critical = list(
      system_commands = list(
        pattern = "\\b(system|system2|shell|pipe|popen|shell\\.exec|exec)\\s*\\(",
        description = "Execução de comandos do SO",
        regex_options = "ignore.case"
      ),
      
      package_install = list(
        pattern = "\\b(install\\.packages|devtools::install|remotes::install|pak::pak)\\s*\\(",
        description = "Instalação de pacotes (potencial RCE)",
        regex_options = "ignore.case"
      ),
      
      env_escape = list(
        pattern = "\\b(parent\\.env|get_env|globalenv|baseenv|ls\\(|exists\\(|get\\(|assign\\()\\s*\\(",
        description = "Acesso a environment/variáveis globais",
        regex_options = "ignore.case"
      ),
      
      code_eval = list(
        pattern = "\\b(eval|parse|source|load|do\\.call)\\s*\\(",
        description = "Execução de código dinâmico",
        regex_options = "ignore.case"
      ),
      
      token_smuggling = list(
        pattern = "<\\|im_(start|end)\\|>|<\\{|}|\\n\\n###",
        description = "Tentativa de manipular tokens da API",
        regex_options = NULL
      ),
      
      sql_injection = list(
        pattern = "(DROP|DELETE|INSERT|UPDATE|CREATE)\\s+(TABLE|DATABASE|SCHEMA)",
        description = "Padrões de SQL injection",
        regex_options = "ignore.case"
      )
    ),
    
    # ========== PADRÕES DE JAILBREAK (Avisar/Rejeitar) ==========
    jailbreak = list(
      instruction_override = list(
        pattern = "\\b(ignore|forget|disregard|override|neglect)\\s+(all\\s+)?previous|previous.*instruction",
        description = "Tentativa de sobrescrever instruções",
        regex_options = "ignore.case"
      ),
      
      role_playing = list(
        pattern = "\\b(pretend|assume\\s+role|act\\s+as|roleplay|unrestricted|no\\s+constraint|no\\s+safety|without\\s+restriction|unlocked)\\b",
        description = "Jailbreak via role-playing",
        regex_options = "ignore.case"
      ),
      
      prompt_leakage = list(
        pattern = "\\b(system.*prompt|original.*instruction|your.*instruction|reveal|show.*prompt|what.*are.*your)\\b",
        description = "Tentativa de vazar instruções do sistema",
        regex_options = "ignore.case"
      ),
      
      data_exfiltration = list(
        pattern = "\\b(send.*to|post.*to|upload.*to|output.*to|external.*api|webhook|attacker|steal|leak|exfilt)\\b",
        description = "Tentativa de exfiltração de dados",
        regex_options = "ignore.case"
      )
    ),
    
    # ========== PADRÕES SUSPEITOS (Avisar) ==========
    suspicious = list(
      file_operations = list(
        pattern = "\\b(read\\.csv|read_csv|readxl|write\\.csv|write_csv|setwd|getwd|list\\.files)\\s*\\(",
        description = "Operações de arquivo - validar contexto",
        regex_options = "ignore.case"
      ),
      
      network_operations = list(
        pattern = "\\b(curl|httr|httr2|download\\.file|GET|POST|PUT)\\s*\\(",
        description = "Operações de rede - validar contexto",
        regex_options = "ignore.case"
      ),
      
      data_serialization = list(
        pattern = "\\b(saveRDS|readRDS|pickle|toJSON|fromJSON)\\s*\\(",
        description = "Serialização/desserialização - validar contexto",
        regex_options = "ignore.case"
      )
    )
  )
}

# ============================================================================
# FUNÇÃO 1: VALIDAÇÃO DE TAMANHO
# ============================================================================

#' Validar tamanho do prompt
#'
#' Verifica se o prompt está dentro dos limites de tamanho permitidos.
#'
#' @param prompt String contendo o prompt do usuário
#' @param max_length Comprimento máximo em caracteres
#' @param min_length Comprimento mínimo em caracteres
#'
#' @return Lista com `valid` (logical) e `message` (character)
#'
#' @examples
#' validate_prompt_size("Filtre dados com vendas > 1000")  # TRUE
#' validate_prompt_size("")                                 # FALSE - muito curto
#' validate_prompt_size(strrep("a", 3000))                 # FALSE - muito longo
#'
#' @export
validate_prompt_size <- function(prompt, 
                                 max_length = MAX_PROMPT_LENGTH, 
                                 min_length = MIN_PROMPT_LENGTH) {
  
  if (!is.character(prompt) || length(prompt) != 1) {
    return(list(
      valid = FALSE,
      message = "Prompt inválido - deve ser uma única string"
    ))
  }
  
  prompt_length <- nchar(prompt)
  
  if (prompt_length < min_length) {
    return(list(
      valid = FALSE,
      message = sprintf("Prompt muito curto (%d < %d caracteres mínimo)", 
                       prompt_length, min_length)
    ))
  }
  
  if (prompt_length > max_length) {
    return(list(
      valid = FALSE,
      message = sprintf("Prompt muito longo (%d > %d caracteres máximo)", 
                       prompt_length, max_length)
    ))
  }
  
  return(list(
    valid = TRUE,
    message = sprintf("✓ Tamanho válido (%d caracteres)", prompt_length),
    character_count = prompt_length
  ))
}

# ============================================================================
# FUNÇÃO 2: DETECÇÃO DE PADRÕES DE INJECTION
# ============================================================================

#' Detectar padrões de prompt injection
#'
#' Analisa o texto em busca de padrões conhecidos de ataque.
#'
#' @param text String a ser analisada
#' @param pattern_db Lista de padrões (saída de get_attack_patterns_db)
#' @param stop_on_critical Lógico - parar na primeira crítica?
#'
#' @return Lista com `detected` (logical), `patterns` (df), `severity` (max)
#'
#' @details
#' Retorna dataframe com colunas:
#' - `category` : critical, jailbreak, suspicious
#' - `pattern_name` : nome do padrão
#' - `description` : descrição
#' - `matches` : número de matches encontrados
#'
#' @export
detect_injection_patterns <- function(text, 
                                      pattern_db = NULL,
                                      stop_on_critical = TRUE) {
  
  if (is.null(pattern_db)) {
    pattern_db <- get_attack_patterns_db()
  }
  
  if (!is.character(text) || length(text) != 1) {
    return(list(
      detected = FALSE,
      patterns = data.frame(),
      severity = "NONE",
      message = "Texto inválido"
    ))
  }
  
  text_lower <- tolower(text)
  detected_patterns <- data.frame()
  max_severity <- "NONE"
  
  # Iterar sobre categorias
  for (category_name in names(pattern_db)) {
    category <- pattern_db[[category_name]]
    category_severity <- switch(category_name,
                               critical = "CRITICAL",
                               jailbreak = "HIGH",
                               suspicious = "MEDIUM",
                               "LOW")
    
    # Iterar sobre padrões na categoria
    for (pattern_name in names(category)) {
      pattern_obj <- category[[pattern_name]]
      pattern <- pattern_obj$pattern
      
      # Contar matches
      matches <- gregexpr(pattern, text_lower, ignore.case = TRUE)
      match_count <- length(matches[[1]]) - (if(matches[[1]][1] == -1) 1 else 0)
      
      if (match_count > 0) {
        detected_patterns <- rbind(detected_patterns, data.frame(
          category = category_name,
          pattern_name = pattern_name,
          description = pattern_obj$description,
          matches = match_count,
          severity = category_severity,
          stringsAsFactors = FALSE
        ))
        
        max_severity <- switch(category_severity,
                              CRITICAL = "CRITICAL",
                              HIGH = if(max_severity != "CRITICAL") "HIGH" else "CRITICAL",
                              MEDIUM = if(max_severity %in% c("NONE", "LOW")) "MEDIUM" else max_severity,
                              LOW = if(max_severity == "NONE") "LOW" else max_severity)
        
        if (stop_on_critical && category_severity == "CRITICAL") {
          break
        }
      }
    }
    
    if (stop_on_critical && max_severity == "CRITICAL") {
      break
    }
  }
  
  detected <- nrow(detected_patterns) > 0
  
  return(list(
    detected = detected,
    patterns = detected_patterns,
    severity = max_severity,
    total_patterns_found = nrow(detected_patterns),
    message = if (detected) 
      sprintf("⚠️ Detectados %d padrões (%s)", nrow(detected_patterns), max_severity)
    else 
      "✓ Nenhum padrão suspeito detectado"
  ))
}

# ============================================================================
# FUNÇÃO 3: WHITELIST DE CARACTERES
# ============================================================================

#' Sanitizar texto removendo caracteres perigosos
#'
#' Remove ou substitui caracteres fora da whitelist permitida.
#'
#' @param text String a sanitizar
#' @param remove_mode "remove" = deletar caracteres inválidos,
#'                    "substitute" = substituir por espaço
#' @param allowed_pattern Regex de caracteres permitidos
#'
#' @return String sanitizada
#'
#' @details
#' A whitelist padrão permite:
#' - Letras: a-z, A-Z, acentos PT-BR/ES
#' - Números: 0-9
#' - Pontuação: . , : ; ! ? ( ) [ ] { } ' " -
#' - Espaço em branco
#'
#' Remove:
#' - Caracteres de controle
#' - Escapes de strings (\\, \\n, \\t)
#' - Caracteres especiais (|, &, $, `)
#' - Aspas desemparelhadas
#'
#' @export
sanitize_text <- function(text, 
                         remove_mode = "substitute",
                         allowed_pattern = ALLOWED_CHARS_PATTERN) {
  
  if (!is.character(text)) {
    return("")
  }
  
  text_vec <- as.character(text)
  result <- sapply(text_vec, function(txt) {
    if (is.na(txt) || txt == "") return("")
    
    # Remove caracteres de controle
    txt <- gsub("[\x00-\x1F\x7F]", "", txt)
    
    # Remove ou substitui caracteres fora do whitelist
    if (remove_mode == "remove") {
      txt <- gsub(paste0("[^", allowed_pattern, "]"), "", txt)
    } else {
      txt <- gsub(paste0("[^", allowed_pattern, "]"), " ", txt)
    }
    
    # Remover espaços múltiplos
    txt <- gsub("\\s+", " ", txt)
    
    # Trim
    txt <- trimws(txt)
    
    return(txt)
  }, USE.NAMES = FALSE)
  
  return(result)
}

# ============================================================================
# FUNÇÃO 4: SANITIZAÇÃO DE NOMES DE COLUNAS
# ============================================================================

#' Sanitizar nomes de colunas de um dataframe
#'
#' Verifica e limpa nomes de colunas que possam ser usados em injection.
#'
#' @param df Dataframe para sanitizar
#' @param max_length Comprimento máximo de nome
#' @param auto_fix Lógico - corrigir nomes inválidos automaticamente?
#'
#' @return Dataframe com nomes de coluna sanitizados, ou lista de erro
#'
#' @details
#' Validações:
#' - Comprimento não excede max_length
#' - Sem caracteres especiais perigosos
#' - Sem espaços em branco no início/fim
#' - Sem nomes duplicados (adiciona sufixo)
#' - Sem nomes vazios
#'
#' @export
sanitize_column_names <- function(df, 
                                 max_length = MAX_COLUMN_NAME_LENGTH,
                                 auto_fix = TRUE) {
  
  if (!is.data.frame(df)) {
    return(list(
      valid = FALSE,
      error = "Entrada não é um dataframe",
      df = df
    ))
  }
  
  if (ncol(df) > MAX_TOTAL_COLUMNS) {
    return(list(
      valid = FALSE,
      error = sprintf("Número de colunas (%d) excede limite (%d)", 
                     ncol(df), MAX_TOTAL_COLUMNS),
      df = df
    ))
  }
  
  original_names <- names(df)
  new_names <- character(length(original_names))
  
  for (i in seq_along(original_names)) {
    name <- original_names[i]
    
    # 1. Converter para character
    name <- as.character(name)
    
    # 2. Trim
    name <- trimws(name)
    
    # 3. Limitar comprimento
    if (nchar(name) > max_length) {
      name <- substr(name, 1, max_length)
    }
    
    # 4. Remover caracteres perigosos
    name <- gsub("[<>\"';`\\(\\){}|&$#*^~]", "_", name)
    
    # 5. Se ficou vazio, usar nome padrão
    if (name == "" || is.na(name)) {
      name <- paste0("col_", i)
    }
    
    new_names[i] <- name
  }
  
  # 6. Remover duplicatas (adicionar sufixo)
  new_names <- make.names(new_names, unique = TRUE)
  
  # 7. Aplicar ao dataframe
  names(df) <- new_names
  
  sanitization_log <- data.frame(
    original = original_names,
    sanitized = new_names,
    changed = original_names != new_names,
    stringsAsFactors = FALSE
  )
  
  return(list(
    valid = TRUE,
    df = df,
    log = sanitization_log,
    message = sprintf("✓ %d colunas validadas (%d modificadas)", 
                     ncol(df), sum(sanitization_log$changed))
  ))
}

# ============================================================================
# FUNÇÃO 5: ANÁLISE DE CÓDIGO GERADO
# ============================================================================

#' Analisar segurança de código R gerado
#'
#' Verifica o código antes da execução para detectar funções/padrões perigosos.
#'
#' @param code_string String contendo código R
#' @param forbidden_functions Vetor de nomes de funções a bloquear
#' @param warn_on_suspicious Avisar sobre funções suspeitas?
#'
#' @return Lista com `safe` (logical), `issues` (df), `severity` (max)
#'
#' @details
#' Funções bloqueadas por padrão:
#' - system, system2, shell (execução de SO)
#' - eval, parse, source, load (código dinâmico)
#' - install.packages, devtools::install (instalação de pacotes)
#' - parent.env, globalenv, assign, get (escape de environment)
#'
#' Funções suspeitas:
#' - readLines, read.csv, write.csv (I/O de arquivo)
#' - curl, httr, download.file (I/O de rede)
#' - saveRDS, readRDS (serialização)
#'
#' @export
analyze_code_safety <- function(code_string,
                               forbidden_functions = NULL,
                               warn_on_suspicious = TRUE) {
  
  if (!is.character(code_string) || length(code_string) != 1) {
    return(list(
      safe = FALSE,
      issues = data.frame(),
      message = "Código inválido"
    ))
  }
  
  # Padrões perigosos em código
  dangerous_patterns <- list(
    forbidden = c(
      "\\bsystem\\s*\\(",
      "\\bsystem2\\s*\\(",
      "\\bshell\\s*\\(",
      "\\beval\\s*\\(",
      "\\bparse\\s*\\(",
      "\\bsource\\s*\\(",
      "\\bload\\s*\\(",
      "\\binstall\\.packages\\s*\\(",
      "\\bparent\\.env\\s*\\(",
      "\\bglobalenv\\s*\\(",
      "\\bassign\\s*\\(",
      "\\bget\\s*\\(",
      "\\bdo\\.call\\s*\\("
    ),
    suspicious = c(
      "\\bread\\.csv\\s*\\(",
      "\\bread_csv\\s*\\(",
      "\\bwrite\\.csv\\s*\\(",
      "\\bwrite_csv\\s*\\(",
      "\\bsetwd\\s*\\(",
      "\\bgetwd\\s*\\(",
      "\\blist\\.files\\s*\\(",
      "\\bfile\\.exists\\s*\\(",
      "\\bcurl\\s*\\(",
      "\\bhttr\\s*\\(",
      "\\bsaveRDS\\s*\\(",
      "\\breadRDS\\s*\\("
    )
  )
  
  if (!is.null(forbidden_functions)) {
    forbidden_patterns <- paste0("\\b", forbidden_functions, "\\s*\\(")
    dangerous_patterns$forbidden <- c(dangerous_patterns$forbidden, forbidden_patterns)
  }
  
  code_lower <- tolower(code_string)
  issues <- data.frame()
  max_severity <- "NONE"
  
  # Verificar funções proibidas
  for (pattern in dangerous_patterns$forbidden) {
    matches <- gregexpr(pattern, code_lower, ignore.case = TRUE)
    if (matches[[1]][1] != -1) {
      match_count <- length(matches[[1]])
      func_name <- gsub("\\\\b|\\\\s.*", "", pattern)
      
      issues <- rbind(issues, data.frame(
        function_name = func_name,
        description = "Função proibida - potencial RCE",
        severity = "CRITICAL",
        pattern = pattern,
        matches = match_count,
        stringsAsFactors = FALSE
      ))
      
      max_severity <- "CRITICAL"
    }
  }
  
  # Verificar funções suspeitas
  if (warn_on_suspicious && max_severity != "CRITICAL") {
    for (pattern in dangerous_patterns$suspicious) {
      matches <- gregexpr(pattern, code_lower, ignore.case = TRUE)
      if (matches[[1]][1] != -1) {
        match_count <- length(matches[[1]])
        func_name <- gsub("\\\\b|\\\\s.*", "", pattern)
        
        issues <- rbind(issues, data.frame(
          function_name = func_name,
          description = "Função suspeita - verificar contexto",
          severity = "MEDIUM",
          pattern = pattern,
          matches = match_count,
          stringsAsFactors = FALSE
        ))
        
        if (max_severity == "NONE") max_severity <- "MEDIUM"
      }
    }
  }
  
  safe <- max_severity != "CRITICAL"
  
  return(list(
    safe = safe,
    issues = issues,
    severity = max_severity,
    total_issues = nrow(issues),
    message = if (safe) 
      sprintf("✓ Código seguro (%s)", 
             if(nrow(issues) > 0) sprintf("%d avisos", nrow(issues)) else "sem problemas")
    else 
      sprintf("❌ Código perigoso detectado (%d problemas críticos)", 
             sum(issues$severity == "CRITICAL"))
  ))
}

# ============================================================================
# FUNÇÃO 6: VALIDAÇÃO COMPLETA DE ENTRADA
# ============================================================================

#' Executar validação completa de entrada do usuário
#'
#' Valida o prompt através de todas as camadas de defesa.
#'
#' @param prompt String com o pedido do usuário
#' @param column_names Vetor com nomes de colunas dos dados (opcional)
#' @param log_details Incluir detalhes no log?
#'
#' @return Lista com `valid` (logical), `message` (character), `details` (list)
#'
#' @details
#' Executa na seguinte ordem:
#' 1. Validação de tamanho
#' 2. Sanitização de caracteres
#' 3. Detecção de padrões
#' 4. Sanitização de colunas (se fornecidas)
#'
#' Retorna lista com:
#' - `valid` : T/F se passou em todas as validações
#' - `message` : mensagem amigável
#' - `passed_layers` : número de camadas bem-sucedidas
#' - `total_layers` : número total de camadas
#' - `details` : detalhes de cada camada
#' - `sanitized_prompt` : prompt após sanitização (se válido)
#'
#' @export
validate_user_input <- function(prompt,
                               column_names = NULL,
                               log_details = TRUE) {
  
  result <- list(
    valid = TRUE,
    passed_layers = 0,
    total_layers = 3,
    details = list(),
    message = character()
  )
  
  # ========== CAMADA 1: Validação de Tamanho ==========
  size_result <- validate_prompt_size(prompt)
  result$details$size = size_result
  
  if (!size_result$valid) {
    result$valid <- FALSE
    result$message <- c(result$message, size_result$message)
    return(result)
  }
  result$passed_layers <- result$passed_layers + 1
  
  # ========== CAMADA 2: Sanitização de Caracteres ==========
  sanitized_prompt <- sanitize_text(prompt)
  result$details$sanitized_prompt <- sanitized_prompt
  
  if (sanitized_prompt != prompt && nchar(sanitized_prompt) < MIN_PROMPT_LENGTH) {
    result$valid <- FALSE
    result$message <- c(result$message, 
                       "Prompt contém caracteres inválidos e ficou muito curto após sanitização")
    return(result)
  }
  result$passed_layers <- result$passed_layers + 1
  
  # ========== CAMADA 3: Detecção de Padrões ==========
  patterns_result <- detect_injection_patterns(prompt)
  result$details$patterns <- patterns_result
  
  if (patterns_result$detected) {
    result$valid <- FALSE
    result$message <- c(result$message, patterns_result$message)
    result$message <- c(result$message, 
                       sprintf("Padrões detectados: %s", 
                              paste(patterns_result$patterns$pattern_name, 
                                   collapse = ", ")))
    return(result)
  }
  result$passed_layers <- result$passed_layers + 1
  
  # ========== CAMADA 4: Validação de Nomes de Colunas (Opcional) ==========
  if (!is.null(column_names)) {
    result$total_layers <- result$total_layers + 1
    
    # Criar dataframe temporário para validar
    temp_df <- as.data.frame(matrix(nrow = 0, ncol = length(column_names)))
    names(temp_df) <- column_names
    
    col_result <- sanitize_column_names(temp_df)
    result$details$columns <- col_result
    
    if (!col_result$valid) {
      result$valid <- FALSE
      result$message <- c(result$message, col_result$error)
      return(result)
    }
    result$passed_layers <- result$passed_layers + 1
  }
  
  # ========== CONSTRUIR MENSAGEM FINAL ==========
  if (result$valid) {
    result$message <- sprintf("✓ Entrada válida (%d/%d camadas)", 
                             result$passed_layers, result$total_layers)
    result$sanitized_prompt <- sanitized_prompt
  } else {
    result$message <- paste(result$message, collapse = " | ")
  }
  
  return(result)
}

# ============================================================================
# FUNÇÃO 7: FUNÇÕES DE UTILIDADE
# ============================================================================

#' Obter resumo da detecção
#'
#' Formata resultados de detecção para exibição
#'
#' @param detection_result Saída de detect_injection_patterns()
#'
#' @return String formatada para exibição
#'
#' @keywords internal
format_detection_summary <- function(detection_result) {
  
  if (!detection_result$detected) {
    return("✓ Seguro: nenhum padrão de ataque detectado")
  }
  
  patterns_df <- detection_result$patterns
  summary <- sprintf(
    "⚠️ ALERTA: %d padrão(ões) suspeito(s) detectado(s) [%s]\n\n",
    nrow(patterns_df),
    detection_result$severity
  )
  
  for (i in 1:nrow(patterns_df)) {
    row <- patterns_df[i, ]
    summary <- paste0(
      summary,
      sprintf("[%s] %s (%s)\n", 
             row$severity, row$pattern_name, row$description),
      sprintf("    Ocorrências: %d\n\n", row$matches)
    )
  }
  
  return(summary)
}

#' Obter funções perigosas encontradas em código
#'
#' Extrai lista de funções potencialmente perigosas
#'
#' @param analysis_result Saída de analyze_code_safety()
#'
#' @return Vetor de nomes de funções, ou character(0)
#'
#' @keywords internal
get_dangerous_functions <- function(analysis_result) {
  
  if (nrow(analysis_result$issues) == 0) {
    return(character(0))
  }
  
  return(unique(analysis_result$issues$function_name))
}

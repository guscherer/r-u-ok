#' Security Event Logging Module
#'
#' Logging estruturado de eventos de segurança com alertas automáticos.
#' Implementa JSON Lines para auditoria e compliance.
#'
#' @details
#' Eventos registrados:
#' - Tentativas de prompt injection
#' - Violações de rate limiting
#' - Código perigoso detectado
#' - Falhas de validação
#' - Execução de código (sucesso/erro)
#' - Atividades suspeitas
#'
#' Formato: JSON Lines (uma linha JSON por evento)
#' Local: `logs/security.jsonl`
#'
#' @keywords internal

# ============================================================================
# CONSTANTES DE CONFIGURAÇÃO
# ============================================================================

# Diretório de logs
SECURITY_LOG_DIR <- "logs"
SECURITY_LOG_FILE <- file.path(SECURITY_LOG_DIR, "security.jsonl")

# Habilitar/desabilitar logging
SECURITY_LOGGING_ENABLED <- TRUE

# Limites para alertas automáticos
ALERT_THRESHOLD_INJECTION_ATTEMPTS <- 5      # em 1 minuto
ALERT_THRESHOLD_RATE_LIMIT_VIOLATIONS <- 3   # em 1 minuto
ALERT_THRESHOLD_ERROR_RATE <- 0.5            # 50% de erro

# ============================================================================
# VARIÁVEIS GLOBAIS
# ============================================================================

.security_logger <- NULL

# ============================================================================
# FUNÇÃO 1: INICIALIZAR LOGGER
# ============================================================================

#' Inicializar logger de segurança
#'
#' Cria estrutura de logging e arquivo de log
#'
#' @param log_dir Diretório para armazenar logs
#' @param enable Habilitar logging?
#'
#' @return invisibly TRUE
#'
#' @details
#' Cria:
#' - Diretório de logs (se não existir)
#' - Arquivo security.jsonl (append mode)
#' - Estrutura de rastreamento em memória
#'
#' @export
init_security_logger <- function(log_dir = SECURITY_LOG_DIR,
                                enable = SECURITY_LOGGING_ENABLED) {
  
  # Criar diretório se não existir
  if (!dir.exists(log_dir)) {
    tryCatch({
      dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
    }, error = function(e) {
      warning("Não foi possível criar diretório de logs: ", e$message)
    })
  }
  
  .security_logger <<- list(
    enabled = enable,
    log_dir = log_dir,
    log_file = file.path(log_dir, "security.jsonl"),
    
    # Rastreamento em memória para alertas
    events_cache = list(
      injection_attempts = data.frame(
        timestamp = as.POSIXct(character()),
        session_id = character(),
        pattern = character(),
        stringsAsFactors = FALSE
      ),
      rate_limit_violations = data.frame(
        timestamp = as.POSIXct(character()),
        session_id = character(),
        limit_type = character(),
        stringsAsFactors = FALSE
      ),
      dangerous_code = data.frame(
        timestamp = as.POSIXct(character()),
        session_id = character(),
        function_detected = character(),
        stringsAsFactors = FALSE
      ),
      execution_errors = data.frame(
        timestamp = as.POSIXct(character()),
        session_id = character(),
        error_type = character(),
        stringsAsFactors = FALSE
      )
    ),
    
    config = list(
      alert_injection = ALERT_THRESHOLD_INJECTION_ATTEMPTS,
      alert_rate_limit = ALERT_THRESHOLD_RATE_LIMIT_VIOLATIONS,
      alert_error_rate = ALERT_THRESHOLD_ERROR_RATE
    )
  )
  
  invisible(TRUE)
}

# ============================================================================
# FUNÇÃO 2: REGISTRAR EVENTO DE SEGURANÇA
# ============================================================================

#' Registrar evento de segurança
#'
#' Log estruturado de evento de segurança em JSON Lines
#'
#' @param event_type Tipo de evento (injection, rate_limit, dangerous_code, etc)
#' @param severity Severidade (INFO, LOW, MEDIUM, HIGH, CRITICAL)
#' @param session_id ID da sessão
#' @param ip_address Endereço IP (opcional)
#' @param details Lista com detalhes específicos do evento
#' @param timestamp Timestamp (padrão: agora)
#'
#' @return invisibly TRUE
#'
#' @details
#' Registra em arquivo JSON Lines com campos padronizados:
#' - timestamp: ISO 8601
#' - event_type: categoria de evento
#' - severity: nível de severidade
#' - session_id: ID da sessão
#' - ip_address: IP da requisição
#' - details: dados específicos do evento
#' - auto_response: ação automática tomada
#'
#' @export
log_security_event <- function(event_type,
                              severity = "INFO",
                              session_id = NULL,
                              ip_address = NULL,
                              details = list(),
                              timestamp = Sys.time()) {
  
  if (is.null(.security_logger) || !.security_logger$enabled) {
    return(invisible(FALSE))
  }
  
  tryCatch({
    # Validações
    if (!event_type %in% c("injection_attempt", "rate_limit", "dangerous_code",
                          "validation_failure", "code_execution", "suspicious_activity",
                          "error", "warning")) {
      event_type <- "unknown"
    }
    
    if (!severity %in% c("INFO", "LOW", "MEDIUM", "HIGH", "CRITICAL")) {
      severity <- "INFO"
    }
    
    # Construir evento
    event <- list(
      timestamp = format(timestamp, "%Y-%m-%dT%H:%M:%OSZ"),
      event_type = event_type,
      severity = severity,
      session_id = as.character(session_id),
      ip_address = as.character(ip_address),
      details = details
    )
    
    # Serializar para JSON
    json_line <- jsonlite::toJSON(event, auto_unbox = TRUE, pretty = FALSE)
    
    # Escrever no arquivo (append)
    write(json_line, file = .security_logger$log_file, append = TRUE)
    
    # Rastrear em memória para alertas
    .track_event_for_alerts(event_type, severity, session_id, details)
    
    # Verificar se deve disparar alertas
    .check_and_fire_alerts(event_type, session_id)
    
    return(invisible(TRUE))
    
  }, error = function(e) {
    warning("Erro ao registrar evento de segurança: ", e$message)
    return(invisible(FALSE))
  })
}

# ============================================================================
# FUNÇÃO 3: LOG DE TENTATIVA DE INJECTION
# ============================================================================

#' Registrar tentativa de prompt injection
#'
#' Log especializado para eventos de injection
#'
#' @param prompt Prompt suspeito (será truncado)
#' @param pattern_detected Padrão que foi detectado
#' @param session_id ID da sessão
#' @param ip_address IP da requisição
#' @param additional_info Lista com informações adicionais
#'
#' @return invisibly TRUE
#'
#' @export
log_injection_attempt <- function(prompt,
                                 pattern_detected,
                                 session_id,
                                 ip_address = NULL,
                                 additional_info = list()) {
  
  # Truncar prompt para privacidade (primeiros 200 chars)
  prompt_truncated <- substr(prompt, 1, 200)
  if (nchar(prompt) > 200) {
    prompt_truncated <- paste0(prompt_truncated, "...")
  }
  
  details <- c(
    list(
      pattern = pattern_detected,
      prompt_first_chars = prompt_truncated,
      prompt_length = nchar(prompt)
    ),
    additional_info
  )
  
  log_security_event(
    event_type = "injection_attempt",
    severity = "HIGH",
    session_id = session_id,
    ip_address = ip_address,
    details = details
  )
  
  invisible(TRUE)
}

# ============================================================================
# FUNÇÃO 4: LOG DE VIOLAÇÃO DE RATE LIMIT
# ============================================================================

#' Registrar violação de rate limiting
#'
#' Log especializado para eventos de rate limit
#'
#' @param limit_type "session", "ip", ou "global"
#' @param session_id ID da sessão
#' @param ip_address IP da requisição
#' @param current_count Número atual de requisições
#' @param limit Limite estabelecido
#'
#' @return invisibly TRUE
#'
#' @export
log_rate_limit_exceeded <- function(limit_type,
                                   session_id = NULL,
                                   ip_address = NULL,
                                   current_count = NA,
                                   limit = NA) {
  
  details <- list(
    limit_type = limit_type,
    current_count = current_count,
    limit = limit,
    percent_of_limit = if(!is.na(current_count) && !is.na(limit))
      round(current_count / limit * 100, 1) else NA
  )
  
  log_security_event(
    event_type = "rate_limit",
    severity = "MEDIUM",
    session_id = session_id,
    ip_address = ip_address,
    details = details
  )
  
  invisible(TRUE)
}

# ============================================================================
# FUNÇÃO 5: LOG DE CÓDIGO PERIGOSO
# ============================================================================

#' Registrar detecção de código perigoso
#'
#' Log especializado para código suspeito detectado
#'
#' @param dangerous_functions Vetor de funções perigosas encontradas
#' @param code_snippet Trecho de código (será truncado)
#' @param session_id ID da sessão
#' @param ip_address IP da requisição
#' @param action_taken "blocked" ou "warning"
#'
#' @return invisibly TRUE
#'
#' @export
log_dangerous_code_detected <- function(dangerous_functions,
                                       code_snippet = NULL,
                                       session_id = NULL,
                                       ip_address = NULL,
                                       action_taken = "blocked") {
  
  # Truncar código para privacidade
  code_truncated <- NA
  if (!is.null(code_snippet) && code_snippet != "") {
    code_truncated <- substr(code_snippet, 1, 300)
    if (nchar(code_snippet) > 300) {
      code_truncated <- paste0(code_truncated, "...")
    }
  }
  
  details <- list(
    dangerous_functions = paste(dangerous_functions, collapse = ", "),
    function_count = length(dangerous_functions),
    code_length = if(!is.null(code_snippet)) nchar(code_snippet) else NA,
    code_first_chars = code_truncated,
    action_taken = action_taken
  )
  
  log_security_event(
    event_type = "dangerous_code",
    severity = "CRITICAL",
    session_id = session_id,
    ip_address = ip_address,
    details = details
  )
  
  invisible(TRUE)
}

# ============================================================================
# FUNÇÃO 6: LOG DE EXECUÇÃO DE CÓDIGO
# ============================================================================

#' Registrar execução de código
#'
#' Log de sucesso ou erro em execução de código dinâmico
#'
#' @param execution_status "success" ou "error"
#' @param session_id ID da sessão
#' @param execution_time_ms Tempo de execução em milissegundos
#' @param memory_used_mb Memória utilizada em MB (opcional)
#' @param error_message Mensagem de erro (se houver)
#' @param code_length Comprimento do código executado
#'
#' @return invisibly TRUE
#'
#' @export
log_code_execution <- function(execution_status,
                              session_id,
                              execution_time_ms = NA,
                              memory_used_mb = NA,
                              error_message = NULL,
                              code_length = NA) {
  
  severity <- if(execution_status == "success") "INFO" else "MEDIUM"
  
  details <- list(
    execution_status = execution_status,
    execution_time_ms = execution_time_ms,
    memory_used_mb = memory_used_mb,
    code_length = code_length,
    error_message = error_message
  )
  
  log_security_event(
    event_type = "code_execution",
    severity = severity,
    session_id = session_id,
    details = details
  )
  
  invisible(TRUE)
}

# ============================================================================
# FUNÇÃO 7: RASTREAMENTO PARA ALERTAS
# ============================================================================

#' Rastrear evento para detecção de alertas
#'
#' Armazena evento em memória para análise de padrões
#'
#' @param event_type Tipo de evento
#' @param severity Severidade
#' @param session_id ID da sessão
#' @param details Detalhes do evento
#'
#' @keywords internal
.track_event_for_alerts <- function(event_type, severity, session_id, details) {
  
  if (is.null(.security_logger)) return(invisible(FALSE))
  
  current_time <- Sys.time()
  
  if (event_type == "injection_attempt") {
    pattern <- details$pattern
    new_event <- data.frame(
      timestamp = current_time,
      session_id = as.character(session_id),
      pattern = as.character(pattern),
      stringsAsFactors = FALSE
    )
    .security_logger$events_cache$injection_attempts <<- rbind(
      .security_logger$events_cache$injection_attempts,
      new_event
    )
    
  } else if (event_type == "rate_limit") {
    limit_type <- details$limit_type
    new_event <- data.frame(
      timestamp = current_time,
      session_id = as.character(session_id),
      limit_type = as.character(limit_type),
      stringsAsFactors = FALSE
    )
    .security_logger$events_cache$rate_limit_violations <<- rbind(
      .security_logger$events_cache$rate_limit_violations,
      new_event
    )
    
  } else if (event_type == "dangerous_code") {
    new_event <- data.frame(
      timestamp = current_time,
      session_id = as.character(session_id),
      function_detected = as.character(details$dangerous_functions),
      stringsAsFactors = FALSE
    )
    .security_logger$events_cache$dangerous_code <<- rbind(
      .security_logger$events_cache$dangerous_code,
      new_event
    )
  }
  
  # Limpar eventos antigos (> 5 minutos)
  cutoff <- current_time - 300
  .security_logger$events_cache$injection_attempts <<- 
    .security_logger$events_cache$injection_attempts[
      .security_logger$events_cache$injection_attempts$timestamp > cutoff,
    ]
  .security_logger$events_cache$rate_limit_violations <<- 
    .security_logger$events_cache$rate_limit_violations[
      .security_logger$events_cache$rate_limit_violations$timestamp > cutoff,
    ]
  .security_logger$events_cache$dangerous_code <<- 
    .security_logger$events_cache$dangerous_code[
      .security_logger$events_cache$dangerous_code$timestamp > cutoff,
    ]
  
  invisible(TRUE)
}

# ============================================================================
# FUNÇÃO 8: VERIFICAR E DISPARAR ALERTAS
# ============================================================================

#' Verificar se deve disparar alerta
#'
#' Analisa padrões para detectar ataques em andamento
#'
#' @param event_type Tipo de evento
#' @param session_id ID da sessão
#'
#' @keywords internal
.check_and_fire_alerts <- function(event_type, session_id) {
  
  if (is.null(.security_logger)) return(invisible(FALSE))
  
  alerts_to_fire <- character()
  
  if (event_type == "injection_attempt") {
    # Verificar se há múltiplas tentativas em 1 minuto
    one_min_ago <- Sys.time() - 60
    recent_attempts <- .security_logger$events_cache$injection_attempts[
      .security_logger$events_cache$injection_attempts$timestamp > one_min_ago &
      .security_logger$events_cache$injection_attempts$session_id == session_id,
    ]
    
    if (nrow(recent_attempts) >= .security_logger$config$alert_injection) {
      alerts_to_fire <- c(alerts_to_fire, "ATTACK_PATTERN_DETECTED")
    }
  }
  
  if (event_type == "rate_limit") {
    # Verificar se há múltiplas violações em 1 minuto
    one_min_ago <- Sys.time() - 60
    recent_violations <- .security_logger$events_cache$rate_limit_violations[
      .security_logger$events_cache$rate_limit_violations$timestamp > one_min_ago &
      .security_logger$events_cache$rate_limit_violations$session_id == session_id,
    ]
    
    if (nrow(recent_violations) >= .security_logger$config$alert_rate_limit) {
      alerts_to_fire <- c(alerts_to_fire, "REPEATED_RATE_LIMIT_VIOLATIONS")
    }
  }
  
  # Disparar alertas
  for (alert in alerts_to_fire) {
    log_security_event(
      event_type = "alert",
      severity = "CRITICAL",
      session_id = session_id,
      details = list(
        alert_type = alert,
        recommended_action = "Review session activity and consider blocking"
      )
    )
  }
  
  invisible(TRUE)
}

# ============================================================================
# FUNÇÃO 9: RECUPERAR EVENTOS DE LOG
# ============================================================================

#' Recuperar eventos de log para análise
#'
#' Lê arquivo de log e filtra por critérios
#'
#' @param event_type Filtrar por tipo de evento (NULL = todos)
#' @param severity Filtrar por severidade (NULL = todos)
#' @param session_id Filtrar por sessão (NULL = todos)
#' @param hours Horas para voltar (padrão: 24)
#' @param max_rows Máximo de linhas a retornar
#'
#' @return Data.frame com eventos, ou NULL se arquivo não existe
#'
#' @export
get_security_events <- function(event_type = NULL,
                               severity = NULL,
                               session_id = NULL,
                               hours = 24,
                               max_rows = 1000) {
  
  if (is.null(.security_logger)) {
    return(NULL)
  }
  
  log_file <- .security_logger$log_file
  
  if (!file.exists(log_file)) {
    return(NULL)
  }
  
  tryCatch({
    # Ler arquivo (pode ser grande, então limite)
    lines <- readLines(log_file, warn = FALSE)
    
    if (length(lines) > max_rows) {
      lines <- tail(lines, max_rows)
    }
    
    # Parsear JSON
    events <- lapply(lines, function(line) {
      tryCatch({
        jsonlite::fromJSON(line)
      }, error = function(e) NULL)
    })
    
    # Remover NULLs
    events <- events[!sapply(events, is.null)]
    
    if (length(events) == 0) {
      return(NULL)
    }
    
    # Converter para data.frame
    df <- do.call(rbind, lapply(events, function(e) {
      data.frame(
        timestamp = e$timestamp,
        event_type = e$event_type,
        severity = e$severity,
        session_id = e$session_id,
        ip_address = e$ip_address,
        stringsAsFactors = FALSE
      )
    }))
    
    # Filtrar por critérios
    if (!is.null(event_type)) {
      df <- df[df$event_type == event_type, ]
    }
    
    if (!is.null(severity)) {
      df <- df[df$severity == severity, ]
    }
    
    if (!is.null(session_id)) {
      df <- df[df$session_id == session_id, ]
    }
    
    # Filtrar por tempo
    cutoff_time <- format(Sys.time() - (3600 * hours), "%Y-%m-%dT%H:%M")
    df <- df[df$timestamp >= cutoff_time, ]
    
    return(df)
    
  }, error = function(e) {
    warning("Erro ao ler log de segurança: ", e$message)
    return(NULL)
  })
}

# ============================================================================
# FUNÇÃO 10: GERAR RELATÓRIO DE SEGURANÇA
# ============================================================================

#' Gerar relatório de segurança
#'
#' Cria sumário de eventos de segurança
#'
#' @param hours Horas para analisar (padrão: 24)
#'
#' @return Lista com estatísticas de segurança
#'
#' @export
get_security_report <- function(hours = 24) {
  
  if (is.null(.security_logger)) {
    return(list(initialized = FALSE))
  }
  
  events <- get_security_events(hours = hours, max_rows = 10000)
  
  if (is.null(events) || nrow(events) == 0) {
    return(list(
      period_hours = hours,
      total_events = 0,
      by_severity = data.frame(),
      by_type = data.frame()
    ))
  }
  
  report <- list(
    period_hours = hours,
    total_events = nrow(events),
    
    by_severity = as.data.frame(table(events$severity)),
    by_type = as.data.frame(table(events$event_type)),
    
    critical_events = sum(events$severity == "CRITICAL"),
    high_events = sum(events$severity == "HIGH"),
    medium_events = sum(events$severity == "MEDIUM"),
    
    injection_attempts = sum(events$event_type == "injection_attempt"),
    rate_limit_violations = sum(events$event_type == "rate_limit"),
    dangerous_code_detections = sum(events$event_type == "dangerous_code"),
    
    unique_sessions = length(unique(events$session_id)),
    unique_ips = length(unique(events$ip_address))
  )
  
  return(report)
}

#' Rate Limiting Implementation
#'
#' Implementa controle de taxa de requisições usando Token Bucket com
#' janela deslizante. Previne abuso de API e DDoS.
#'
#' @details
#' Algoritmo: Token Bucket
#' - Cada sessão/IP recebe um "bucket" de tokens
#' - Cada requisição consome tokens
#' - Tokens são reabastecidos continuamente (1 token por segundo)
#' - Burst é permitido até limite máximo
#'
#' Rastreamento em 3 dimensões:
#' 1. Por sessão Shiny (user)
#' 2. Por IP (network)
#' 3. Global (server)
#'
#' @keywords internal

# ============================================================================
# CONSTANTES DE CONFIGURAÇÃO
# ============================================================================

# Limites de taxa padrão (em requisições por minuto)
DEFAULT_RATE_LIMIT_PER_MINUTE <- 10      # Por sessão
DEFAULT_RATE_LIMIT_GLOBAL <- 100         # Total do servidor
DEFAULT_RATE_LIMIT_PER_IP <- 30          # Por endereço IP

# Controle de burst
DEFAULT_BURST_LIMIT_REQUESTS <- 3        # Permitir até 3 requisições
DEFAULT_BURST_LIMIT_SECONDS <- 5         # Em 5 segundos

# Janela de rastreamento
RATE_LIMIT_WINDOW_MINUTES <- 1

# ============================================================================
# VARIÁVEIS GLOBAIS (Estado em Memória)
# ============================================================================

# Armazenar estado do rate limiter
.rate_limiter <- NULL

#' Inicializar Rate Limiter
#'
#' Cria estrutura de dados para rastreamento de requisições.
#' Deve ser chamado uma única vez na inicialização da aplicação.
#'
#' @param per_minute Limite por sessão (requisições/minuto)
#' @param global_limit Limite global do servidor
#' @param per_ip_limit Limite por IP
#' @param burst_requests Número máximo de requisições em burst
#' @param burst_seconds Janela de tempo para burst
#'
#' @return invisibly TRUE
#'
#' @details
#' Cria ambiente global com:
#' - `session_tracker` : data.frame com rastreamento por sessão
#' - `ip_tracker` : data.frame com rastreamento por IP
#' - `global_counter` : número total de requisições
#' - `config` : configurações de limite
#'
#' @export
init_rate_limiter <- function(per_minute = DEFAULT_RATE_LIMIT_PER_MINUTE,
                              global_limit = DEFAULT_RATE_LIMIT_GLOBAL,
                              per_ip_limit = DEFAULT_RATE_LIMIT_PER_IP,
                              burst_requests = DEFAULT_BURST_LIMIT_REQUESTS,
                              burst_seconds = DEFAULT_BURST_LIMIT_SECONDS) {
  
  .rate_limiter <<- list(
    session_tracker = data.frame(
      session_id = character(),
      timestamp = as.numeric(character()),
      request_count = numeric(),
      last_reset = as.numeric(character()),
      status = character(),
      stringsAsFactors = FALSE
    ),
    
    ip_tracker = data.frame(
      ip_address = character(),
      timestamp = as.numeric(character()),
      request_count = numeric(),
      last_reset = as.numeric(character()),
      status = character(),
      stringsAsFactors = FALSE
    ),
    
    burst_tracker = data.frame(
      id = character(),
      id_type = character(),  # "session" ou "ip"
      burst_requests = numeric(),
      burst_window_start = as.numeric(character()),
      stringsAsFactors = FALSE
    ),
    
    global_counter = 0,
    last_reset_global = Sys.time(),
    
    config = list(
      per_minute = per_minute,
      global_limit = global_limit,
      per_ip_limit = per_ip_limit,
      burst_requests = burst_requests,
      burst_seconds = burst_seconds,
      window_minutes = RATE_LIMIT_WINDOW_MINUTES
    )
  )
  
  invisible(TRUE)
}

# ============================================================================
# FUNÇÃO 1: VERIFICAR LIMITE DE TAXA
# ============================================================================

#' Verificar se requisição é permitida
#'
#' Valida se uma nova requisição pode ser feita sem violar limites de taxa.
#'
#' @param session_id Identificador de sessão (único por usuário)
#' @param ip_address Endereço IP da requisição (opcional)
#'
#' @return Lista com `allowed` (logical) e `reason` (character)
#'
#' @details
#' Verifica:
#' 1. Limite global do servidor
#' 2. Limite por sessão/usuário
#' 3. Limite por IP (se fornecido)
#' 4. Limite de burst
#'
#' Nega se qualquer limite for violado.
#' Retorna razão específica da negação.
#'
#' @export
check_rate_limit <- function(session_id, ip_address = NULL) {
  
  if (is.null(.rate_limiter)) {
    init_rate_limiter()
  }
  
  if (!is.character(session_id) || session_id == "") {
    return(list(
      allowed = FALSE,
      reason = "Session ID inválido"
    ))
  }
  
  current_time <- Sys.time()
  window_start <- current_time - (60 * .rate_limiter$config$window_minutes)
  
  # ========== VERIFICAÇÃO 1: Limite Global ==========
  if (.rate_limiter$global_counter >= .rate_limiter$config$global_limit) {
    # Verificar se janela expirou
    if (current_time - .rate_limiter$last_reset_global > 60) {
      .rate_limiter$global_counter <<- 0
      .rate_limiter$last_reset_global <<- current_time
    } else {
      return(list(
        allowed = FALSE,
        reason = sprintf("Limite global (%d req/min) atingido",
                        .rate_limiter$config$global_limit),
        limit_type = "global"
      ))
    }
  }
  
  # ========== VERIFICAÇÃO 2: Limite por Sessão ==========
  session_data <- .rate_limiter$session_tracker[
    .rate_limiter$session_tracker$session_id == session_id, 
  ]
  
  if (nrow(session_data) > 0) {
    # Sessão existe - verificar janela
    last_req_time <- as.POSIXct(session_data$last_reset[1], origin = "1970-01-01")
    time_since_last <- as.numeric(difftime(current_time, last_req_time, units = "secs"))
    
    if (time_since_last < 60) {
      # Dentro da janela
      if (session_data$request_count[1] >= .rate_limiter$config$per_minute) {
        return(list(
          allowed = FALSE,
          reason = sprintf("Limite por usuário (%d req/min) atingido",
                          .rate_limiter$config$per_minute),
          limit_type = "session",
          session_count = session_data$request_count[1],
          reset_in_seconds = as.integer(60 - time_since_last)
        ))
      }
    } else {
      # Janela expirou - resetar
      .rate_limiter$session_tracker[
        .rate_limiter$session_tracker$session_id == session_id,
        "request_count"
      ] <<- 0
      .rate_limiter$session_tracker[
        .rate_limiter$session_tracker$session_id == session_id,
        "last_reset"
      ] <<- as.numeric(current_time)
    }
  } else {
    # Nova sessão - adicionar
    .rate_limiter$session_tracker <<- rbind(
      .rate_limiter$session_tracker,
      data.frame(
        session_id = session_id,
        timestamp = as.numeric(current_time),
        request_count = 0,
        last_reset = as.numeric(current_time),
        status = "active",
        stringsAsFactors = FALSE
      )
    )
  }
  
  # ========== VERIFICAÇÃO 3: Limite por IP ==========
  if (!is.null(ip_address) && ip_address != "") {
    ip_data <- .rate_limiter$ip_tracker[
      .rate_limiter$ip_tracker$ip_address == ip_address,
    ]
    
    if (nrow(ip_data) > 0) {
      last_req_time <- as.POSIXct(ip_data$last_reset[1], origin = "1970-01-01")
      time_since_last <- as.numeric(difftime(current_time, last_req_time, units = "secs"))
      
      if (time_since_last < 60) {
        if (ip_data$request_count[1] >= .rate_limiter$config$per_ip_limit) {
          return(list(
            allowed = FALSE,
            reason = sprintf("Limite por IP (%d req/min) atingido",
                            .rate_limiter$config$per_ip_limit),
            limit_type = "ip",
            ip_count = ip_data$request_count[1],
            reset_in_seconds = as.integer(60 - time_since_last)
          ))
        }
      } else {
        .rate_limiter$ip_tracker[
          .rate_limiter$ip_tracker$ip_address == ip_address,
          "request_count"
        ] <<- 0
        .rate_limiter$ip_tracker[
          .rate_limiter$ip_tracker$ip_address == ip_address,
          "last_reset"
        ] <<- as.numeric(current_time)
      }
    } else {
      .rate_limiter$ip_tracker <<- rbind(
        .rate_limiter$ip_tracker,
        data.frame(
          ip_address = ip_address,
          timestamp = as.numeric(current_time),
          request_count = 0,
          last_reset = as.numeric(current_time),
          status = "active",
          stringsAsFactors = FALSE
        )
      )
    }
  }
  
  # ========== VERIFICAÇÃO 4: Limite de Burst ==========
  burst_check <- .check_burst_limit(session_id, ip_address, current_time)
  if (!burst_check$allowed) {
    return(burst_check)
  }
  
  # ========== TODAS AS VERIFICAÇÕES PASSARAM ==========
  record_request(session_id, ip_address)
  
  return(list(
    allowed = TRUE,
    reason = "✓ Requisição permitida",
    session_count_updated = TRUE
  ))
}

# ============================================================================
# FUNÇÃO 2: REGISTRAR REQUISIÇÃO
# ============================================================================

#' Registrar nova requisição
#'
#' Incrementa contadores após verificação bem-sucedida
#'
#' @param session_id ID da sessão
#' @param ip_address IP da requisição (opcional)
#'
#' @return invisibly TRUE
#'
#' @keywords internal
record_request <- function(session_id, ip_address = NULL) {
  
  if (is.null(.rate_limiter)) {
    return(invisible(FALSE))
  }
  
  current_time <- Sys.time()
  
  # Incrementar contador da sessão
  session_row <- which(.rate_limiter$session_tracker$session_id == session_id)
  if (length(session_row) > 0) {
    .rate_limiter$session_tracker[session_row, "request_count"] <<- 
      .rate_limiter$session_tracker[session_row, "request_count"] + 1
  }
  
  # Incrementar contador do IP
  if (!is.null(ip_address) && ip_address != "") {
    ip_row <- which(.rate_limiter$ip_tracker$ip_address == ip_address)
    if (length(ip_row) > 0) {
      .rate_limiter$ip_tracker[ip_row, "request_count"] <<- 
        .rate_limiter$ip_tracker[ip_row, "request_count"] + 1
    }
  }
  
  # Incrementar contador global
  .rate_limiter$global_counter <<- .rate_limiter$global_counter + 1
  
  invisible(TRUE)
}

# ============================================================================
# FUNÇÃO 3: VERIFICAR LIMITE DE BURST
# ============================================================================

#' Verificar limite de burst
#'
#' Evita múltiplas requisições em sequência rápida
#'
#' @param session_id ID da sessão
#' @param ip_address IP (opcional)
#' @param current_time Timestamp atual
#'
#' @return Lista com `allowed` (logical) e `reason` (character)
#'
#' @keywords internal
.check_burst_limit <- function(session_id, ip_address = NULL, current_time = Sys.time()) {
  
  burst_window_start <- current_time - .rate_limiter$config$burst_seconds
  
  # Verificar burst da sessão
  session_burst <- .rate_limiter$burst_tracker[
    .rate_limiter$burst_tracker$id == session_id &
    .rate_limiter$burst_tracker$id_type == "session" &
    .rate_limiter$burst_tracker$burst_window_start > as.numeric(burst_window_start),
  ]
  
  if (nrow(session_burst) > 0) {
    if (session_burst$burst_requests[1] >= .rate_limiter$config$burst_requests) {
      return(list(
        allowed = FALSE,
        reason = sprintf(
          "Limite de burst (%d req em %d seg) atingido. Aguarde.",
          .rate_limiter$config$burst_requests,
          .rate_limiter$config$burst_seconds
        ),
        limit_type = "burst"
      ))
    }
    # Incrementar burst existente
    .rate_limiter$burst_tracker[
      .rate_limiter$burst_tracker$id == session_id &
      .rate_limiter$burst_tracker$id_type == "session" &
      .rate_limiter$burst_tracker$burst_window_start > as.numeric(burst_window_start),
      "burst_requests"
    ] <<- session_burst$burst_requests[1] + 1
  } else {
    # Novo burst
    .rate_limiter$burst_tracker <<- rbind(
      .rate_limiter$burst_tracker,
      data.frame(
        id = session_id,
        id_type = "session",
        burst_requests = 1,
        burst_window_start = as.numeric(current_time),
        stringsAsFactors = FALSE
      )
    )
  }
  
  # Limpeza: remover entradas expiradas
  .rate_limiter$burst_tracker <<- .rate_limiter$burst_tracker[
    .rate_limiter$burst_tracker$burst_window_start > as.numeric(burst_window_start),
  ]
  
  return(list(allowed = TRUE))
}

# ============================================================================
# FUNÇÃO 4: OBTER STATUS DO RATE LIMIT
# ============================================================================

#' Obter status atual de rate limiting
#'
#' Retorna informações sobre limite de taxa para exibição
#'
#' @param session_id ID da sessão (opcional)
#' @param ip_address IP (opcional)
#'
#' @return Lista com status de limite para cada dimensão
#'
#' @export
get_rate_limit_status <- function(session_id = NULL, ip_address = NULL) {
  
  if (is.null(.rate_limiter)) {
    return(list(
      initialized = FALSE,
      message = "Rate limiter não inicializado"
    ))
  }
  
  status <- list(
    initialized = TRUE,
    global = list(
      current = .rate_limiter$global_counter,
      limit = .rate_limiter$config$global_limit,
      percent = round(.rate_limiter$global_counter / 
                     .rate_limiter$config$global_limit * 100, 1)
    )
  )
  
  # Status por sessão
  if (!is.null(session_id) && session_id != "") {
    session_data <- .rate_limiter$session_tracker[
      .rate_limiter$session_tracker$session_id == session_id,
    ]
    
    if (nrow(session_data) > 0) {
      status$session <- list(
        session_id = session_id,
        current = session_data$request_count[1],
        limit = .rate_limiter$config$per_minute,
        percent = round(session_data$request_count[1] / 
                       .rate_limiter$config$per_minute * 100, 1),
        active_since = as.POSIXct(session_data$timestamp[1], origin = "1970-01-01")
      )
    }
  }
  
  # Status por IP
  if (!is.null(ip_address) && ip_address != "") {
    ip_data <- .rate_limiter$ip_tracker[
      .rate_limiter$ip_tracker$ip_address == ip_address,
    ]
    
    if (nrow(ip_data) > 0) {
      status$ip <- list(
        ip_address = ip_address,
        current = ip_data$request_count[1],
        limit = .rate_limiter$config$per_ip_limit,
        percent = round(ip_data$request_count[1] / 
                       .rate_limiter$config$per_ip_limit * 100, 1),
        active_since = as.POSIXct(ip_data$timestamp[1], origin = "1970-01-01")
      )
    }
  }
  
  return(status)
}

# ============================================================================
# FUNÇÃO 5: RESETAR LIMITES (ADMIN)
# ============================================================================

#' Resetar limites de taxa
#'
#' Remove entradas antigas ou reseta limite específico.
#' Requer cuidado em produção.
#'
#' @param reset_type "global" (tudo), "session" (uma sessão), "ip" (um IP)
#' @param target Identificador (session_id ou ip_address)
#'
#' @return invisibly TRUE
#'
#' @details
#' Tipos de reset:
#' - "global" : reseta tudo e remove entradas antigas
#' - "session" : reseta uma sessão específica
#' - "ip" : reseta um IP específico
#' - "expired" : remove apenas entradas expiradas
#'
#' @export
reset_rate_limits <- function(reset_type = "expired", target = NULL) {
  
  if (is.null(.rate_limiter)) {
    return(invisible(FALSE))
  }
  
  current_time <- Sys.time()
  cutoff_time <- current_time - 120  # 2 minutos
  
  if (reset_type == "global") {
    # Resetar tudo
    .rate_limiter$session_tracker <<- 
      .rate_limiter$session_tracker[0,]
    .rate_limiter$ip_tracker <<- 
      .rate_limiter$ip_tracker[0,]
    .rate_limiter$burst_tracker <<- 
      .rate_limiter$burst_tracker[0,]
    .rate_limiter$global_counter <<- 0
    .rate_limiter$last_reset_global <<- current_time
    
  } else if (reset_type == "session" && !is.null(target)) {
    # Resetar uma sessão
    .rate_limiter$session_tracker <<- 
      .rate_limiter$session_tracker[
        .rate_limiter$session_tracker$session_id != target,
      ]
    
  } else if (reset_type == "ip" && !is.null(target)) {
    # Resetar um IP
    .rate_limiter$ip_tracker <<- 
      .rate_limiter$ip_tracker[
        .rate_limiter$ip_tracker$ip_address != target,
      ]
    
  } else if (reset_type == "expired") {
    # Remover entradas antigas
    .rate_limiter$session_tracker <<- 
      .rate_limiter$session_tracker[
        as.POSIXct(.rate_limiter$session_tracker$last_reset, 
                   origin = "1970-01-01") > cutoff_time,
      ]
    .rate_limiter$ip_tracker <<- 
      .rate_limiter$ip_tracker[
        as.POSIXct(.rate_limiter$ip_tracker$last_reset, 
                   origin = "1970-01-01") > cutoff_time,
      ]
  }
  
  invisible(TRUE)
}

# ============================================================================
# FUNÇÃO 6: FORMATAR STATUS PARA EXIBIÇÃO
# ============================================================================

#' Formatar status de rate limiting para UI
#'
#' Cria mensagem legível para exibir ao usuário
#'
#' @param status Saída de get_rate_limit_status()
#'
#' @return String formatada
#'
#' @keywords internal
format_rate_limit_status <- function(status) {
  
  if (!status$initialized) {
    return("Rate limiter não disponível")
  }
  
  msg <- sprintf(
    "Global: %d/%d (%.0f%%)",
    status$global$current,
    status$global$limit,
    status$global$percent
  )
  
  if (!is.null(status$session)) {
    msg <- paste0(msg, sprintf(
      " | Sua sessão: %d/%d (%.0f%%)",
      status$session$current,
      status$session$limit,
      status$session$percent
    ))
  }
  
  if (!is.null(status$ip)) {
    msg <- paste0(msg, sprintf(
      " | Seu IP: %d/%d (%.0f%%)",
      status$ip$current,
      status$ip$limit,
      status$ip$percent
    ))
  }
  
  return(msg)
}

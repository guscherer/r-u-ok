#' Logging e Auditoria de Uploads de Arquivos
#'
#' Este módulo implementa registro estruturado de todas as operações
#' de upload para auditoria e monitoramento de segurança.

#' Registrar evento de upload
#'
#' Cria entrada de log estruturada para cada upload
#'
#' @param filename Nome do arquivo
#' @param size_mb Tamanho em MB
#' @param file_type Tipo detectado (csv/excel)
#' @param validation_passed TRUE se passou em validação
#' @param error_message Mensagem de erro (se houver)
#' @param session_id ID da sessão (opcional)
#'
#' @return invisibly TRUE
#'
#' @keywords internal
log_file_upload <- function(filename, size_mb = NA, file_type = NA, 
                            validation_passed = FALSE, error_message = NULL,
                            session_id = NULL) {
  
  if (!ENABLE_FILE_LOGGING) {
    return(invisible(TRUE))
  }
  
  tryCatch({
    log_dir <- get_log_dir()
    log_file <- file.path(log_dir, "file_uploads.csv")
    
    # Criar linha de log
    log_entry <- data.frame(
      timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
      filename = as.character(filename),
      size_mb = if (is.na(size_mb)) NA_character_ else round(size_mb, 2),
      file_type = as.character(file_type),
      validation_passed = as.logical(validation_passed),
      error_message = as.character(if (is.null(error_message)) "" else error_message),
      session_id = as.character(if (is.null(session_id)) "" else session_id),
      stringsAsFactors = FALSE
    )
    
    # Append ao arquivo de log
    if (file.exists(log_file)) {
      # Adicionar nova linha
      write.table(
        log_entry,
        file = log_file,
        append = TRUE,
        sep = ",",
        col.names = FALSE,
        row.names = FALSE,
        quote = TRUE
      )
    } else {
      # Criar novo arquivo com header
      write.csv(
        log_entry,
        file = log_file,
        row.names = FALSE,
        quote = TRUE
      )
    }
    
    return(invisible(TRUE))
    
  }, error = function(e) {
    warning("Erro ao registrar log de upload: ", e$message)
    return(invisible(FALSE))
  })
}


#' Obter estatísticas de uploads da sessão
#'
#' Retorna resumo dos uploads do arquivo de log
#'
#' @param max_rows Máximo de linhas a retornar (padrão: 100)
#' @param session_id Filtrar por ID de sessão (opcional)
#'
#' @return data.frame com histórico de uploads
#'
#' @export
get_upload_statistics <- function(max_rows = 100, session_id = NULL) {
  log_dir <- get_log_dir()
  log_file <- file.path(log_dir, "file_uploads.csv")
  
  if (!file.exists(log_file)) {
    return(data.frame())
  }
  
  tryCatch({
    logs <- utils::read.csv(log_file, stringsAsFactors = FALSE)
    
    # Converter timestamp
    logs$timestamp <- as.POSIXct(logs$timestamp, format = "%Y-%m-%d %H:%M:%S")
    
    # Filtrar por sessão se especificado
    if (!is.null(session_id)) {
      logs <- logs[logs$session_id == session_id, ]
    }
    
    # Ordenar por timestamp (mais recente primeiro)
    logs <- logs[order(logs$timestamp, decreasing = TRUE), ]
    
    # Limitar a max_rows
    if (nrow(logs) > max_rows) {
      logs <- logs[1:max_rows, ]
    }
    
    return(logs)
    
  }, error = function(e) {
    warning("Erro ao ler estatísticas de upload: ", e$message)
    return(data.frame())
  })
}


#' Calcular estatísticas agregadas de uploads
#'
#' Retorna resumo de estatísticas
#'
#' @return Lista com estatísticas
#'
#' @export
get_upload_summary <- function() {
  logs <- get_upload_statistics(max_rows = Inf)
  
  if (nrow(logs) == 0) {
    return(list(
      total_uploads = 0,
      successful = 0,
      failed = 0,
      total_size_mb = 0,
      avg_size_mb = 0,
      csv_count = 0,
      excel_count = 0
    ))
  }
  
  list(
    total_uploads = nrow(logs),
    successful = sum(logs$validation_passed, na.rm = TRUE),
    failed = sum(!logs$validation_passed, na.rm = TRUE),
    total_size_mb = sum(as.numeric(logs$size_mb), na.rm = TRUE),
    avg_size_mb = mean(as.numeric(logs$size_mb), na.rm = TRUE),
    csv_count = sum(logs$file_type == "csv", na.rm = TRUE),
    excel_count = sum(logs$file_type == "excel", na.rm = TRUE)
  )
}


#' Limpar arquivo de log antigo
#'
#' Remove entradas de log mais antigas que N dias
#'
#' @param older_than_days Mínimo de dias antes de deletar
#'
#' @return invisibly TRUE
#'
#' @keywords internal
cleanup_old_logs <- function(older_than_days = 30) {
  log_dir <- get_log_dir()
  log_file <- file.path(log_dir, "file_uploads.csv")
  
  if (!file.exists(log_file)) {
    return(invisible(TRUE))
  }
  
  tryCatch({
    logs <- utils::read.csv(log_file, stringsAsFactors = FALSE)
    logs$timestamp <- as.POSIXct(logs$timestamp, format = "%Y-%m-%d %H:%M:%S")
    
    # Manter apenas entradas recentes
    cutoff_date <- Sys.time() - (older_than_days * 24 * 3600)
    logs_to_keep <- logs[logs$timestamp > cutoff_date, ]
    
    # Reescrever arquivo
    if (nrow(logs_to_keep) > 0) {
      write.csv(logs_to_keep, file = log_file, row.names = FALSE)
    } else {
      unlink(log_file)
    }
    
    return(invisible(TRUE))
    
  }, error = function(e) {
    warning("Erro ao limpar logs: ", e$message)
    return(invisible(FALSE))
  })
}


#' Verificar taxa de uploads (rate limiting)
#'
#' Detecta padrão de abuso baseado em taxa de uploads
#'
#' @param session_id ID da sessão para verificar
#' @param within_minutes Janela de tempo para verificar (padrão: 60 min)
#' @param max_uploads Máximo de uploads permitido nessa janela
#'
#' @return TRUE se dentro do limite, FALSE se excedeu
#'
#' @keywords internal
check_rate_limit <- function(session_id, within_minutes = 60, 
                             max_uploads = MAX_UPLOADS_PER_HOUR) {
  logs <- get_upload_statistics(max_rows = Inf, session_id = session_id)
  
  if (nrow(logs) == 0) {
    return(TRUE)  # Primeira requisição
  }
  
  # Converter timestamp
  logs$timestamp <- as.POSIXct(logs$timestamp, format = "%Y-%m-%d %H:%M:%S")
  
  # Contar uploads na janela de tempo
  cutoff_time <- Sys.time() - (within_minutes * 60)
  recent_uploads <- sum(logs$timestamp > cutoff_time)
  
  if (recent_uploads >= max_uploads) {
    warning(sprintf(
      "Rate limit excedido: %d uploads em %d minutos (max: %d)",
      recent_uploads, within_minutes, max_uploads
    ))
    return(FALSE)
  }
  
  return(TRUE)
}


#' Gerar relatório de upload para auditoria
#'
#' Cria resumo em formato legível para auditoria
#'
#' @param output_file Arquivo para salvar relatório (opcional)
#'
#' @return character: relatório em texto
#'
#' @export
generate_upload_audit_report <- function(output_file = NULL) {
  summary <- get_upload_summary()
  logs <- get_upload_statistics(max_rows = Inf)
  
  # Construir relatório
  report <- sprintf(
    "=== RELATÓRIO DE UPLOADS - AUDITORIA ===\n\n",
    
    "Gerado em: %s\n\n",
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    
    "ESTATÍSTICAS GERAIS:\n",
    "Total de uploads: %d\n",
    "✓ Bem-sucedidos: %d (%.1f%%)\n",
    "✗ Falhados: %d (%.1f%%)\n",
    "Tamanho total: %.2f MB\n",
    "Tamanho médio: %.2f MB\n\n",
    
    "POR TIPO:\n",
    "CSV: %d arquivos\n",
    "Excel: %d arquivos\n\n",
    
    "ÚLTIMOS 10 UPLOADS:\n"
  )
  
  report <- sprintf(report,
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    summary$total_uploads,
    summary$successful, 
    if (summary$total_uploads > 0) 100 * summary$successful / summary$total_uploads else 0,
    summary$failed,
    if (summary$total_uploads > 0) 100 * summary$failed / summary$total_uploads else 0,
    summary$total_size_mb,
    if (summary$total_uploads > 0) summary$avg_size_mb else 0,
    summary$csv_count,
    summary$excel_count
  )
  
  # Adicionar últimos uploads
  if (nrow(logs) > 0) {
    last_logs <- logs[1:min(10, nrow(logs)), ]
    report <- paste0(report, 
      paste(sprintf(
        "%s | %s | %s | %s | %s\n",
        last_logs$timestamp,
        last_logs$filename,
        last_logs$file_type,
        last_logs$size_mb,
        ifelse(last_logs$validation_passed, "✓", "✗")
      ), collapse = "")
    )
  }
  
  # Salvar se especificado
  if (!is.null(output_file)) {
    writeLines(report, con = output_file)
    message("Relatório salvo em: ", output_file)
  }
  
  return(report)
}

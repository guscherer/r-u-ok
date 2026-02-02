#' Limpeza Automática de Arquivos Temporários
#'
#' Este módulo implementa um scheduler que remove automaticamente
#' arquivos temporários e logs antigos.

# ===========================
# Cleanup de Arquivos Temporários
# ===========================

#' Limpar arquivos temporários expirados
#'
#' Remove arquivos da sessão que foram marcados há mais de N horas
#'
#' @param temp_dir Diretório de temporários (padrão: tempdir())
#' @param hours_old Mínimo de horas antes de deletar (padrão: TEMP_FILE_RETENTION_HOURS)
#'
#' @return invisibly TRUE
#'
#' @keywords internal
cleanup_temp_files <- function(temp_dir = tempdir(), 
                               hours_old = TEMP_FILE_RETENTION_HOURS) {
  
  if (!ENABLE_CLEANUP_SCHEDULER) {
    return(invisible(TRUE))
  }
  
  tryCatch({
    if (!dir.exists(temp_dir)) {
      return(invisible(TRUE))
    }
    
    # Obter todos os arquivos no diretório temporário
    files <- list.files(temp_dir, full.names = TRUE, recursive = FALSE)
    
    if (length(files) == 0) {
      return(invisible(TRUE))
    }
    
    # Obter informações de modificação
    file_info <- file.info(files)
    now <- Sys.time()
    cutoff_time <- now - (hours_old * 3600)
    
    # Filtrar arquivos expirados
    old_files <- rownames(file_info)[file_info$mtime < cutoff_time]
    
    if (length(old_files) == 0) {
      return(invisible(TRUE))
    }
    
    # Deletar arquivos antigos
    for (file in old_files) {
      tryCatch({
        unlink(file)
      }, error = function(e) {
        warning("Erro ao deletar arquivo temporário: ", file, " - ", e$message)
      })
    }
    
    # Log de limpeza
    cleaned_count <- length(old_files)
    message(sprintf("Limpeza completada: %d arquivos temporários deletados", cleaned_count))
    
    return(invisible(TRUE))
    
  }, error = function(e) {
    warning("Erro durante limpeza de temporários: ", e$message)
    return(invisible(FALSE))
  })
}


# ===========================
# Scheduler para Limpeza Periódica
# ===========================

#' Inicializar scheduler de limpeza automática
#'
#' Cria um timer reativo no Shiny que executará limpeza periodicamente
#'
#' @param session Sessão Shiny
#' @param interval_minutes Intervalo em minutos (padrão: 60)
#'
#' @return invisibly NULL
#'
#' @details
#' Deve ser chamado dentro de um shinyServer para funcionar
#'
#' @examples
#' \dontrun{
#' # Em shinyServer():
#' init_cleanup_scheduler(session, interval_minutes = 60)
#' }
#'
#' @keywords internal
init_cleanup_scheduler <- function(session, interval_minutes = 60) {
  
  if (!ENABLE_CLEANUP_SCHEDULER) {
    return(invisible(NULL))
  }
  
  # Criar timer reativo
  shiny::observe({
    # Timer executado a cada N minutos
    shiny::invalidateLater(interval_minutes * 60 * 1000)
    
    tryCatch({
      # Executar limpeza
      cleanup_temp_files()
      cleanup_old_logs(older_than_days = 30)
      
      # Log de execução
      timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
      message(sprintf("[%s] Scheduler executado com sucesso", timestamp))
      
    }, error = function(e) {
      warning("Erro no scheduler de limpeza: ", e$message)
    })
  })
  
  return(invisible(NULL))
}


# ===========================
# Estatísticas de Limpeza
# ===========================

#' Obter informações sobre arquivos temporários
#'
#' Retorna estatísticas de tamanho e contagem
#'
#' @param temp_dir Diretório de temporários
#'
#' @return data.frame com estatísticas
#'
#' @export
get_temp_files_stats <- function(temp_dir = tempdir()) {
  
  if (!dir.exists(temp_dir)) {
    return(data.frame(
      total_files = 0,
      total_size_mb = 0,
      oldest_file_age_hours = NA_real_,
      newest_file_age_hours = NA_real_
    ))
  }
  
  files <- list.files(temp_dir, full.names = TRUE, recursive = FALSE)
  
  if (length(files) == 0) {
    return(data.frame(
      total_files = 0,
      total_size_mb = 0,
      oldest_file_age_hours = NA_real_,
      newest_file_age_hours = NA_real_
    ))
  }
  
  file_info <- file.info(files)
  total_size <- sum(file_info$size, na.rm = TRUE)
  now <- Sys.time()
  
  ages_hours <- as.numeric(difftime(now, file_info$mtime, units = "hours"))
  
  data.frame(
    total_files = nrow(file_info),
    total_size_mb = round(total_size / (1024 * 1024), 2),
    oldest_file_age_hours = max(ages_hours, na.rm = TRUE),
    newest_file_age_hours = min(ages_hours, na.rm = TRUE)
  )
}


#' Obter informações sobre arquivos de log
#'
#' Retorna tamanho e informações do arquivo de log
#'
#' @return data.frame com estatísticas do log
#'
#' @export
get_log_files_stats <- function() {
  
  log_dir <- get_log_dir()
  
  if (!dir.exists(log_dir)) {
    return(data.frame(
      log_file = NA_character_,
      size_mb = 0,
      entries_count = 0,
      oldest_entry = NA_character_,
      newest_entry = NA_character_
    ))
  }
  
  log_file <- file.path(log_dir, "file_uploads.csv")
  
  if (!file.exists(log_file)) {
    return(data.frame(
      log_file = NA_character_,
      size_mb = 0,
      entries_count = 0,
      oldest_entry = NA_character_,
      newest_entry = NA_character_
    ))
  }
  
  tryCatch({
    file_size <- file.size(log_file)
    logs <- utils::read.csv(log_file, stringsAsFactors = FALSE)
    
    oldest <- min(logs$timestamp, na.rm = TRUE)
    newest <- max(logs$timestamp, na.rm = TRUE)
    
    data.frame(
      log_file = basename(log_file),
      size_mb = round(file_size / (1024 * 1024), 2),
      entries_count = nrow(logs),
      oldest_entry = as.character(oldest),
      newest_entry = as.character(newest)
    )
    
  }, error = function(e) {
    data.frame(
      log_file = NA_character_,
      size_mb = 0,
      entries_count = 0,
      oldest_entry = NA_character_,
      newest_entry = NA_character_
    )
  })
}


#' Gerar relatório de limpeza
#'
#' Cria relatório sobre arquivos temporários e logs
#'
#' @return character: relatório formatado
#'
#' @export
generate_cleanup_report <- function() {
  
  temp_stats <- get_temp_files_stats()
  log_stats <- get_log_files_stats()
  
  report <- sprintf(
    "=== RELATÓRIO DE LIMPEZA ===\n\n",
    "Gerado em: %s\n\n",
    
    "ARQUIVOS TEMPORÁRIOS:\n",
    "Total de arquivos: %d\n",
    "Tamanho total: %.2f MB\n",
    "Arquivo mais antigo: %.1f horas atrás\n",
    "Arquivo mais novo: %.1f horas atrás\n\n",
    
    "ARQUIVO DE LOG:\n",
    "Nome: %s\n",
    "Tamanho: %.2f MB\n",
    "Total de entradas: %d\n",
    "Registro mais antigo: %s\n",
    "Registro mais novo: %s\n\n",
    
    "RECOMENDAÇÕES:\n"
  )
  
  report <- sprintf(report,
    format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    temp_stats$total_files,
    temp_stats$total_size_mb,
    if (is.na(temp_stats$oldest_file_age_hours)) 0 else temp_stats$oldest_file_age_hours,
    if (is.na(temp_stats$newest_file_age_hours)) 0 else temp_stats$newest_file_age_hours,
    if (is.na(log_stats$log_file)) "(nenhum)" else log_stats$log_file,
    log_stats$size_mb,
    log_stats$entries_count,
    if (is.na(log_stats$oldest_entry)) "(N/A)" else log_stats$oldest_entry,
    if (is.na(log_stats$newest_entry)) "(N/A)" else log_stats$newest_entry
  )
  
  # Adicionar recomendações
  if (temp_stats$total_size_mb > 100) {
    report <- paste0(report, "⚠️ Muitos arquivos temporários (>100 MB). Considere limpeza.\n")
  }
  
  if (log_stats$size_mb > 50) {
    report <- paste0(report, "⚠️ Arquivo de log está grande (>50 MB). Considere rotação.\n")
  }
  
  if (!ENABLE_CLEANUP_SCHEDULER) {
    report <- paste0(report, "ℹ️ Scheduler automático está desabilitado.\n")
  } else {
    report <- paste0(report, "✓ Scheduler automático está habilitado.\n")
  }
  
  return(report)
}

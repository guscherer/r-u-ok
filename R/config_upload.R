#' Configurações de Segurança para Upload de Arquivos
#'
#' Este módulo define constantes e limites de segurança para validação
#' de uploads de arquivos.

# ===========================
# Whitelist de Tipos Permitidos
# ===========================

FILE_TYPE_WHITELIST <- c("csv", "xls", "xlsx")

# ===========================
# Limites de Tamanho
# ===========================

# Tamanho máximo por arquivo (em MB)
MAX_FILE_SIZE_MB <- as.numeric(
  Sys.getenv("MAX_UPLOAD_SIZE_MB", unset = "50")
)

# Tamanho máximo para requisição HTTP (por segurança do Shiny)
# Deve ser ligeiramente maior que MAX_FILE_SIZE_MB
MAX_REQUEST_SIZE_BYTES <- (MAX_FILE_SIZE_MB + 2) * 1024 * 1024

# Número máximo de arquivos em um upload
MAX_FILES_PER_UPLOAD <- as.numeric(
  Sys.getenv("MAX_FILES_PER_UPLOAD", unset = "10")
)

# ===========================
# Rate Limiting
# ===========================

# Máximo de uploads por hora
MAX_UPLOADS_PER_HOUR <- as.numeric(
  Sys.getenv("MAX_UPLOADS_PER_HOUR", unset = "50")
)

# ===========================
# Limpeza de Arquivos Temporários
# ===========================

# Horas para manter arquivos temporários antes de deletar
TEMP_FILE_RETENTION_HOURS <- as.numeric(
  Sys.getenv("TEMP_FILE_RETENTION_HOURS", unset = "24")
)

# Habilitar limpeza automática de temp files
ENABLE_CLEANUP_SCHEDULER <- as.logical(
  Sys.getenv("ENABLE_CLEANUP_SCHEDULER", unset = "true")
)

# ===========================
# Logging
# ===========================

# Habilitar logging estruturado de uploads
ENABLE_FILE_LOGGING <- as.logical(
  Sys.getenv("ENABLE_FILE_LOGGING", unset = "true")
)

# Diretório para logs
UPLOAD_LOG_DIR <- ".auto-claude/logs"

# ===========================
# Magic Bytes (Assinaturas de Arquivo)
# ===========================

MAGIC_BYTES_PATTERNS <- list(
  # CSV: Text ASCII, começa com caracteres imprimíveis
  csv = list(
    patterns = list(
      # BOM UTF-8
      c(0xEF, 0xBB, 0xBF),
      # ASCII/UTF-8 normal (first char printable)
      NULL  # Will be checked differently
    ),
    description = "CSV (Text)",
    extensions = c("csv")
  ),
  
  # Excel (XLSX/XLS): PKZip signature ou OLE signature
  excel = list(
    patterns = list(
      # XLSX = ZIP archive (PK signature)
      c(0x50, 0x4B, 0x03, 0x04),
      # XLS = OLE2 signature
      c(0xD0, 0xCF, 0x11, 0xE0)
    ),
    description = "Excel (XLSX/XLS)",
    extensions = c("xls", "xlsx")
  )
)

# ===========================
# Funções de Configuração
# ===========================

#' Obter tamanho máximo de upload em bytes
get_max_upload_bytes <- function() {
  MAX_FILE_SIZE_MB * 1024 * 1024
}

#' Obter caminho do diretório de logs
get_log_dir <- function() {
  if (!dir.exists(UPLOAD_LOG_DIR)) {
    dir.create(UPLOAD_LOG_DIR, recursive = TRUE, showWarnings = FALSE)
  }
  UPLOAD_LOG_DIR
}

#' Imprimir configurações atuais
print_upload_config <- function() {
  cat("\n=== CONFIGURAÇÕES DE UPLOAD ===\n")
  cat("Tamanho máximo por arquivo:", MAX_FILE_SIZE_MB, "MB\n")
  cat("Máximo de arquivos por upload:", MAX_FILES_PER_UPLOAD, "\n")
  cat("Máximo de uploads por hora:", MAX_UPLOADS_PER_HOUR, "\n")
  cat("Retenção de temp files:", TEMP_FILE_RETENTION_HOURS, "horas\n")
  cat("Logging habilitado:", ENABLE_FILE_LOGGING, "\n")
  cat("Cleanup automático:", ENABLE_CLEANUP_SCHEDULER, "\n")
  cat("Tipos permitidos:", paste(FILE_TYPE_WHITELIST, collapse = ", "), "\n")
  cat("===============================\n\n")
}

# ===========================
# ML Detection Settings
# ===========================

# Habilitar detecção ML (complementar ao regex)
ENABLE_ML_DETECTION <- as.logical(
  Sys.getenv("ENABLE_ML_DETECTION", unset = "true")
)

# Threshold para ML detection (0-100, quanto maior, mais conservador)
ML_DETECTION_THRESHOLD <- as.numeric(
  Sys.getenv("ML_DETECTION_THRESHOLD", unset = "40")
)

# Modo de ML: "warn" (apenas avisar) ou "block" (bloquear)
ML_DETECTION_MODE <- Sys.getenv("ML_DETECTION_MODE", unset = "warn")

# Habilitar logging de ML detection
ENABLE_ML_LOGGING <- as.logical(
  Sys.getenv("ENABLE_ML_LOGGING", unset = "true")
)

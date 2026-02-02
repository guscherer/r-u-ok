#' Validação Segura de Uploads de Arquivos
#'
#' Este módulo implementa validações em múltiplas camadas para arquivos
#' carregados, incluindo verificação de tipo, tamanho e conteúdo.

#' Validar extensão do arquivo
#'
#' Verifica se a extensão está na whitelist permitida
#'
#' @param filename Nome do arquivo com extensão
#'
#' @return Lista com `valid` (logical) e `type` (character: "csv" ou "excel")
#'         ou mensagem de erro
#'
#' @examples
#' validate_extension("dados.csv")     # list(valid = TRUE, type = "csv")
#' validate_extension("dados.txt")     # list(valid = FALSE, error = "...")
#'
#' @export
validate_extension <- function(filename) {
  if (!is.character(filename) || length(filename) != 1) {
    return(list(valid = FALSE, error = "Nome do arquivo inválido"))
  }
  
  ext <- tolower(tools::file_ext(filename))
  
  if (ext == "") {
    return(list(valid = FALSE, error = "Arquivo sem extensão"))
  }
  
  if (ext == "csv") {
    return(list(valid = TRUE, type = "csv"))
  } else if (ext %in% c("xls", "xlsx")) {
    return(list(valid = TRUE, type = "excel"))
  } else {
    return(list(
      valid = FALSE,
      error = paste0(
        "Tipo de arquivo não permitido: .", ext, "\n",
        "Use: .csv, .xls ou .xlsx"
      )
    ))
  }
}


#' Validar tamanho do arquivo
#'
#' Verifica se o arquivo não excede o limite de tamanho
#'
#' @param size_bytes Tamanho do arquivo em bytes
#' @param max_mb Tamanho máximo em MB (padrão: MAX_FILE_SIZE_MB)
#'
#' @return TRUE se válido, FALSE caso contrário (com warning)
#'
#' @export
validate_file_size <- function(size_bytes, max_mb = NULL) {
  if (is.null(max_mb)) {
    max_mb <- MAX_FILE_SIZE_MB
  }
  
  if (!is.numeric(size_bytes) || size_bytes < 0) {
    warning("Tamanho de arquivo inválido")
    return(FALSE)
  }
  
  size_mb <- size_bytes / (1024 * 1024)
  
  if (size_mb > max_mb) {
    warning(
      sprintf(
        "Arquivo excede limite (%.1f MB > %.0f MB)",
        size_mb, max_mb
      )
    )
    return(FALSE)
  }
  
  if (size_bytes == 0) {
    warning("Arquivo está vazio (0 bytes)")
    return(FALSE)
  }
  
  return(TRUE)
}


#' Validar magic bytes do arquivo
#'
#' Verifica a assinatura binária do arquivo para detectar tipo real,
#' independente da extensão
#'
#' @param file_path Caminho absoluto do arquivo
#'
#' @return Lista com `valid` (TRUE/FALSE) e `detected_type` (csv/excel)
#'         ou mensagem de erro
#'
#' @details
#' Detecta:
#' - CSV: UTF-8 BOM ou texto ASCII
#' - Excel: ZIP (XLSX) ou OLE2 (XLS)
#'
#' @export
validate_file_type <- function(file_path) {
  if (!file.exists(file_path)) {
    return(list(valid = FALSE, error = "Arquivo não encontrado"))
  }
  
  tryCatch({
    # Ler primeiros 8 bytes
    conn <- file(file_path, "rb")
    on.exit(close(conn), add = TRUE)
    magic_bytes <- readBin(conn, "raw", n = 8)
    
    # Verificar se tem conteúdo
    if (length(magic_bytes) == 0) {
      return(list(valid = FALSE, error = "Arquivo vazio"))
    }
    
    # Verificar XLSX (PK signature = 0x50 0x4B)
    if (length(magic_bytes) >= 2 && 
        magic_bytes[1] == 0x50 && magic_bytes[2] == 0x4B) {
      return(list(valid = TRUE, detected_type = "excel"))
    }
    
    # Verificar XLS (OLE2 signature = 0xD0 0xCF 0x11 0xE0)
    if (length(magic_bytes) >= 4 && 
        magic_bytes[1] == 0xD0 && magic_bytes[2] == 0xCF && 
        magic_bytes[3] == 0x11 && magic_bytes[4] == 0xE0) {
      return(list(valid = TRUE, detected_type = "excel"))
    }
    
    # Verificar CSV (UTF-8 BOM = 0xEF 0xBB 0xBF)
    if (length(magic_bytes) >= 3 && 
        magic_bytes[1] == 0xEF && magic_bytes[2] == 0xBB && 
        magic_bytes[3] == 0xBF) {
      return(list(valid = TRUE, detected_type = "csv"))
    }
    
    # Verificar se é texto ASCII (CSV sem BOM)
    # Qualquer byte abaixo de 0x09 (tab) ou > 0x7F (ASCII) para não-CSV
    non_ascii_count <- sum(magic_bytes < 0x09 | 
                          (magic_bytes > 0x0D & magic_bytes < 0x20) |
                          magic_bytes > 0x7F)
    
    # CSV pode ter alguns bytes de controle (LF, CR), mas não muitos
    if (non_ascii_count <= 2) {  # Tolerância para LF/CR
      return(list(valid = TRUE, detected_type = "csv"))
    }
    
    # Se chegou aqui, tipo não reconhecido
    hex_repr <- paste(sprintf("%02X", magic_bytes[1:min(4, length(magic_bytes))]), 
                      collapse = " ")
    return(list(
      valid = FALSE,
      error = paste0(
        "Tipo de arquivo não reconhecido. Assinatura: ", hex_repr
      )
    ))
    
  }, error = function(e) {
    return(list(valid = FALSE, error = paste("Erro ao validar arquivo:", e$message)))
  })
}


#' Ler arquivo com validação de segurança
#'
#' Wrapper seguro de read_csv/read_excel com validação de estrutura
#'
#' @param file_path Caminho do arquivo
#' @param file_type Tipo detectado ("csv" ou "excel")
#'
#' @return data.frame se bem-sucedido, NULL se falhar (com warning)
#'
#' @export
read_file_safely <- function(file_path, file_type) {
  if (!file.exists(file_path)) {
    warning("Arquivo não existe: ", file_path)
    return(NULL)
  }
  
  tryCatch({
    if (file_type == "csv") {
      df <- readr::read_csv(
        file_path,
        show_col_types = FALSE,
        col_types = readr::cols(.default = readr::col_character()),
        # Limites de segurança
        skip_empty_rows = TRUE,
        progress = FALSE
      )
    } else if (file_type == "excel") {
      df <- readxl::read_excel(file_path)
    } else {
      warning("Tipo de arquivo desconhecido: ", file_type)
      return(NULL)
    }
    
    # Validar estrutura básica
    if (is.null(df) || nrow(df) == 0) {
      warning("Arquivo vazio (sem linhas de dados)")
      return(NULL)
    }
    
    if (ncol(df) == 0) {
      warning("Arquivo sem colunas")
      return(NULL)
    }
    
    # Validar nomes de colunas
    colnames(df) <- make.names(colnames(df), unique = TRUE)
    
    return(df)
    
  }, error = function(e) {
    warning(
      "Erro ao ler arquivo: ",
      e$message
    )
    return(NULL)
  })
}


#' Validar estrutura de data.frame carregado
#'
#' Verifica se data.frame tem características válidas
#'
#' @param df data.frame para validar
#' @param min_rows Mínimo de linhas (padrão: 1)
#' @param min_cols Mínimo de colunas (padrão: 1)
#'
#' @return Lista com `valid` (TRUE/FALSE) e `warnings` (character vector)
#'
#' @export
validate_dataframe_structure <- function(df, min_rows = 1, min_cols = 1) {
  warnings <- character()
  
  # Verificação básica
  if (!is.data.frame(df)) {
    return(list(valid = FALSE, error = "Não é um data.frame válido"))
  }
  
  # Verificar dimensões
  if (nrow(df) < min_rows) {
    warnings <- c(warnings, 
      sprintf("Arquivo tem poucas linhas (%d < %d esperado)", nrow(df), min_rows))
  }
  
  if (ncol(df) < min_cols) {
    warnings <- c(warnings,
      sprintf("Arquivo tem poucas colunas (%d < %d esperado)", ncol(df), min_cols))
  }
  
  # Verificar missing values
  missing_pct <- (sum(is.na(df)) / (nrow(df) * ncol(df))) * 100
  if (missing_pct > 50) {
    warnings <- c(warnings,
      sprintf("Arquivo tem muitos valores faltantes (%.1f%%)", missing_pct))
  }
  
  # Verificar nomes de coluna duplicados
  if (anyDuplicated(colnames(df))) {
    warnings <- c(warnings, "Arquivo tem colunas duplicadas (nomes)")
  }
  
  return(list(
    valid = length(warnings) == 0,
    warnings = warnings,
    nrow = nrow(df),
    ncol = ncol(df),
    missing_pct = round(missing_pct, 1)
  ))
}


#' Deletar arquivo temporário com segurança
#'
#' Remove arquivo com tratamento de erro
#'
#' @param file_path Caminho do arquivo a deletar
#'
#' @return TRUE se deletado, FALSE caso contrário
#'
#' @export
cleanup_temp_file <- function(file_path) {
  if (!file.exists(file_path)) {
    return(TRUE)  # Já não existe
  }
  
  tryCatch({
    unlink(file_path)
    return(!file.exists(file_path))
  }, error = function(e) {
    warning("Erro ao deletar arquivo temporário: ", e$message)
    return(FALSE)
  })
}


#' Criar resumo de validação para exibição
#'
#' Formata resultados de validação para mensagem ao usuário
#'
#' @param results Lista com resultados de validação
#' @param filename Nome do arquivo (para contexto)
#'
#' @return character: mensagem amigável
#'
#' @keywords internal
format_validation_message <- function(results, filename) {
  if (isTRUE(results$valid)) {
    return(sprintf("✓ %s validado com sucesso", filename))
  } else {
    return(sprintf("✗ %s: %s", filename, results$error))
  }
}

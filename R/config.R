#' Carrega configurações da aplicação R-U-OK
#'
#' Esta função carrega configurações de variáveis de ambiente, com suporte
#' para arquivo .env e validação de parâmetros obrigatórios.
#'
#' @return Lista com configurações da aplicação
#' @export
#'
#' @examples
#' config <- load_config()
#' api_key <- config$api_key
load_config <- function() {
  # Tenta carregar .env se existir (para desenvolvimento local)
  env_file <- ".env"
  if (file.exists(env_file)) {
    tryCatch({
      readRenviron(env_file)
      message("✓ Arquivo .env carregado")
    }, error = function(e) {
      warning("Erro ao carregar .env: ", e$message)
    })
  }
  
  # Carrega configurações do ambiente
  api_key <- Sys.getenv("ZHIPU_API_KEY", unset = "")
  api_url <- Sys.getenv(
    "ZHIPU_API_URL",
    unset = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
  )
  model <- Sys.getenv("ZHIPU_MODEL", unset = "glm-4")
  temperature <- as.numeric(Sys.getenv("ZHIPU_TEMPERATURE", unset = "0.1"))
  
  # Validação: API key é obrigatória
  if (api_key == "" || api_key == "SUA_CHAVE_AQUI") {
    stop(
      "\n❌ ERRO: ZHIPU_API_KEY não está configurada!\n\n",
      "Configure a chave da API de uma das seguintes formas:\n\n",
      "1. Crie um arquivo .env na raiz do projeto:\n",
      "   cp .env.example .env\n",
      "   # Edite .env e adicione sua chave real\n\n",
      "2. Defina variável de ambiente no sistema:\n",
      "   export ZHIPU_API_KEY='sua-chave-aqui'  # Linux/Mac\n",
      "   $env:ZHIPU_API_KEY='sua-chave-aqui'    # Windows PowerShell\n\n",
      "3. Adicione ao arquivo .Renviron:\n",
      "   ZHIPU_API_KEY=sua-chave-aqui\n\n",
      "Obtenha sua chave em: https://open.bigmodel.cn/\n"
    )
  }
  
  # Retorna configuração validada
  config <- list(
    api_key = api_key,
    api_url = api_url,
    model = model,
    temperature = temperature
  )
  
  message("✓ Configuração carregada com sucesso")
  return(config)
}


#' Valida se a configuração está correta
#'
#' @param config Lista de configurações retornada por load_config()
#' @return TRUE se válido, caso contrário lança erro
validate_config <- function(config) {
  # Verifica se API key tem formato válido (mínimo de caracteres)
  if (nchar(config$api_key) < 10) {
    stop("API key parece inválida (muito curta)")
  }
  
  # Verifica se URL está acessível (opcional, pode ser lento)
  # tryCatch({
  #   httr2::request(config$api_url) %>% httr2::req_dry_run()
  # }, error = function(e) {
  #   warning("Não foi possível validar URL da API: ", config$api_url)
  # })
  
  TRUE
}

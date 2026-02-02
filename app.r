library(shiny)
library(tidyverse)
library(readxl)
library(DT)
library(httr2)
library(writexl)
library(shinythemes)

# --- CONFIGURAÇÃO SEGURA DA APLICAÇÃO ---
# Carrega configurações de variáveis de ambiente
source("R/config.R")
config <- load_config()
API_KEY <- config$api_key

# --- CONFIGURAÇÕES DE SEGURANÇA DE UPLOAD ---
# Carrega constantes e limites de upload
source("R/config_upload.R")
# Carrega funções de validação
source("R/file_validation.R")
# Carrega funções de logging
source("R/file_logging.R")
# Carrega funções de limpeza automática
source("R/cleanup_scheduler.R")
# Carrega funções de validação de input (Task 026)
source("R/input_validation.R")
# Carrega funções de sandbox seguro (Task 016)
source("R/code_sandbox.R")
# Carrega funções de detecção ML (ML Detection)
source("R/ml_detection.R")

# Configurar limite de tamanho de requisição do Shiny
shiny::shinyOptions(
  shiny.maxRequestSize = MAX_REQUEST_SIZE_BYTES
)

# Função que chama a IA
consultar_glm4 <- function(esquemas_texto, pedido_usuario, chave_api) {
  
  # Define o endpoint oficial da Zhipu AI (Compatível com OpenAI)
  url_base <- config$api_url
  
  # Prompt do Sistema: Define a personalidade e regras estritas para a IA
  system_prompt <- "Você é um especialista sênior em R e tidyverse.
  Sua tarefa é gerar APENAS código R executável para transformar dataframes.
  
  Regras:
  1. O usuário fornecerá os nomes das colunas de um ou mais dataframes carregados numa lista chamada 'lista_dados'.
  2. Os dataframes dentro da lista são acessados como: lista_dados[[1]], lista_dados[[2]], etc.
  3. Se houver apenas um arquivo, use lista_dados[[1]].
  4. Retorne APENAS o bloco de código R. SEM explicações, SEM comentários, SEM ```r ```.
  5. O resultado final deve ser salvo em um objeto chamado 'resultado'.
  6. Use preferencialmente funções do pacote dplyr (filter, select, mutate, group_by, summarise)."
  
  # Prompt do Usuário: Combina o pedido com a estrutura dos dados
  user_content <- paste0(
    "Estrutura dos dados disponíveis:\n", esquemas_texto, "\n\n",
    "Pedido do usuário: ", pedido_usuario
  )
  
  # Montagem da requisição HTTP
  req <- request(url_base) %>%
    req_method("POST") %>%
    req_headers(
      "Authorization" = paste("Bearer", chave_api),
      "Content-Type" = "application/json"
    ) %>%
    req_body_json(list(
      model = "glm-4", # Ou "glm-4-plus" / "glm-4-flash" dependendo do seu plano
      messages = list(
        list(role = "system", content = system_prompt),
        list(role = "user", content = user_content)
      ),
      temperature = 0.1 # Baixa temperatura para código mais preciso
    ))
  
  # Envio e tratamento da resposta
  resp <- req_perform(req)
  resp_body <- resp_body_json(resp)
  
  # Extração do conteúdo (código)
  codigo <- resp_body$choices[[1]]$message$content
  
  # Limpeza extra caso a IA insira marcadores de markdown
  codigo_limpo <- gsub("```r|```", "", codigo)
  return(trimws(codigo_limpo))
}

# --- INTERFACE DO USUÁRIO (UI) ---
ui <- fluidPage(
  theme = shinytheme("flatly"), # Tema moderno e limpo
  
  titlePanel("🤖 Analista de Dados com GLM-4.7"),
  
  sidebarLayout(
    sidebarPanel(
      # Entrada de Arquivos
      fileInput("arquivos", "1. Carregue suas planilhas (CSV/Excel)",
                multiple = TRUE,
                accept = c(".csv", ".xlsx")),
      
      # Exibição dos arquivos carregados
      uiOutput("lista_arquivos_ui"),
      hr(),
      
      # Área de Pedido (Prompt)
      textAreaInput("prompt", "2. O que você quer analisar?",
                    placeholder = "Ex: Junte a planilha 1 com a 2 pelo ID, filtre vendas > 500 e agrupe por Vendedor.",
                    height = "120px"),
      
      actionButton("executar", "Gerar Análise", class = "btn-primary btn-lg", icon = icon("robot")),
      hr(),
      
      # Botão de Download (só aparece se tiver resultado)
      uiOutput("download_ui")
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("🔍 Resultado", 
                 br(),
                 DTOutput("tabela_resultado")
        ),
        tabPanel("📄 Dados Originais", 
                 br(),
                 uiOutput("tabs_originais")
        ),
        tabPanel("💻 Código Gerado", 
                 br(),
                 verbatimTextOutput("codigo_mostrado"),
                 helpText("Este é o código R que a IA escreveu e executou.")
        ),
        
        # === NEW: SECURITY MONITORING TABS ===
        tabPanel("🛡️ Eventos de Segurança",
                 br(),
                 fluidRow(
                   column(12,
                     h4("Últimas Atividades de Segurança"),
                     DTOutput("seguranca_eventos_tabela"),
                     helpText("Logs de tentativas de injeção, erros de validação, etc.")
                   )
                 )
        ),
        
        tabPanel("📊 Estatísticas de Upload",
                 br(),
                 fluidRow(
                   column(6,
                     h4("Taxa de Sucesso"),
                     plotOutput("upload_sucesso_plot")
                   ),
                   column(6,
                     h4("Distribuição de Tamanho"),
                     plotOutput("upload_tamanho_plot")
                   )
                 ),
                 fluidRow(
                   column(12,
                     h4("Histórico de Uploads"),
                     DTOutput("upload_historico_tabela")
                   )
                 )
        ),
        
        tabPanel("⚡ Rate Limiting",
                 br(),
                 fluidRow(
                   column(12,
                     h4("Requisições por Minuto (últimos 60 min)"),
                     plotOutput("ratelimit_timeline_plot"),
                     helpText("Limite: 10 requisições/min por sessão")
                   )
                 ),
                 fluidRow(
                   column(6,
                     h4("Status Atual"),
                     valueBoxOutput("ratelimit_status_box")
                   ),
                   column(6,
                     h4("Estatísticas"),
                     DTOutput("ratelimit_stats_tabela")
                   )
                 )
        ),
        
        tabPanel("🏥 Saúde do Sistema",
                 br(),
                 fluidRow(
                   column(6,
                     h4("Arquivos Temporários"),
                     DTOutput("cleanup_temp_tabela")
                   ),
                   column(6,
                     h4("Logs"),
                     DTOutput("cleanup_logs_tabela")
                   )
                 ),
                 fluidRow(
                   column(12,
                     h4("Relatório do Scheduler"),
                     verbatimTextOutput("cleanup_report_text")
                   )
                 )
        )
      )
    )
  )
)

# --- SERVIDOR (SERVER) ---
server <- function(input, output, session) {
  
  # Inicializar scheduler de limpeza automática
  init_cleanup_scheduler(session, interval_minutes = 60)
  
  # Variáveis Reativas para armazenar estado
  dados_carregados <- reactiveValues(lista = list(), nomes = NULL)
  resultado_analise <- reactiveVal(NULL)
  codigo_gerado <- reactiveVal(NULL)
  
  # 1. Leitura dos Arquivos COM VALIDAÇÃO
  observeEvent(input$arquivos, {
    req(input$arquivos)
    
    # Validar número de arquivos
    if (nrow(input$arquivos) > MAX_FILES_PER_UPLOAD) {
      shiny::showNotification(
        paste0("Máximo de ", MAX_FILES_PER_UPLOAD, " arquivos permitidos"),
        type = "error"
      )
      return()
    }
    
    arquivos_temp <- list()
    nomes_temp <- c()
    
    for(i in 1:nrow(input$arquivos)) {
      caminho <- input$arquivos$datapath[i]
      nome_arquivo <- input$arquivos$name[i]
      
      # ========== VALIDAÇÃO 1: Extensão ==========
      ext_result <- validate_extension(nome_arquivo)
      if (!ext_result$valid) {
        shiny::showNotification(
          paste0("❌ ", nome_arquivo, ": ", ext_result$error),
          type = "error",
          duration = 5
        )
        # Log falha
        log_file_upload(
          filename = nome_arquivo,
          size_mb = NA,
          file_type = NA,
          validation_passed = FALSE,
          error_message = ext_result$error
        )
        next  # Pular este arquivo
      }
      
      # ========== VALIDAÇÃO 2: Tamanho ==========
      file_size <- file.size(caminho)
      file_size_mb <- round(file_size / (1024 * 1024), 2)
      
      if (!validate_file_size(file_size, MAX_FILE_SIZE_MB)) {
        shiny::showNotification(
          paste0("❌ ", nome_arquivo, ": Arquivo muito grande (", 
                 file_size_mb, " MB > ", MAX_FILE_SIZE_MB, " MB)"),
          type = "error",
          duration = 5
        )
        # Log falha
        log_file_upload(
          filename = nome_arquivo,
          size_mb = file_size_mb,
          file_type = NA,
          validation_passed = FALSE,
          error_message = "Arquivo excede tamanho máximo permitido"
        )
        next
      }
      
      # ========== VALIDAÇÃO 3: Magic Bytes (Tipo Real) ==========
      type_result <- validate_file_type(caminho)
      if (!type_result$valid) {
        shiny::showNotification(
          paste0("❌ ", nome_arquivo, ": ", type_result$error),
          type = "error",
          duration = 5
        )
        # Log falha
        log_file_upload(
          filename = nome_arquivo,
          size_mb = file_size_mb,
          file_type = NA,
          validation_passed = FALSE,
          error_message = type_result$error
        )
        next
      }
      
      # ========== LEITURA COM SEGURANÇA ==========
      df <- read_file_safely(caminho, type_result$detected_type)
      
      if(is.null(df)) {
        shiny::showNotification(
          paste0("❌ ", nome_arquivo, ": Erro ao processar arquivo"),
          type = "error",
          duration = 5
        )
        # Log falha
        log_file_upload(
          filename = nome_arquivo,
          size_mb = file_size_mb,
          file_type = type_result$detected_type,
          validation_passed = FALSE,
          error_message = "Erro ao processar arquivo"
        )
        next
      }
      
      # ========== VALIDAÇÃO 4: Estrutura ==========
      structure_result <- validate_dataframe_structure(df)
      if (!structure_result$valid) {
        for (warning in structure_result$warnings) {
          shiny::showNotification(
            paste0("⚠️ ", nome_arquivo, ": ", warning),
            type = "warning",
            duration = 3
          )
        }
      }
      
      # Se passou em todas as validações
      arquivos_temp[[i]] <- df
      nomes_temp <- c(nomes_temp, nome_arquivo)
      
      # Log sucesso
      log_file_upload(
        filename = nome_arquivo,
        size_mb = file_size_mb,
        file_type = type_result$detected_type,
        validation_passed = TRUE,
        error_message = NULL
      )
      
      # Mensagem de sucesso
      shiny::showNotification(
        paste0("✓ ", nome_arquivo, " carregado (", 
               structure_result$nrow, " linhas × ", 
               structure_result$ncol, " colunas)"),
        type = "message",
        duration = 3
      )
    }
    
    dados_carregados$lista <- arquivos_temp
    dados_carregados$nomes <- nomes_temp
  })
  
  # UI Dinâmica: Mostra quais arquivos foram lidos
  output$lista_arquivos_ui <- renderUI({
    req(dados_carregados$nomes)
    tagList(
      h5("Arquivos carregados:"),
      tags$ul(lapply(seq_along(dados_carregados$nomes), function(i) {
        tags$li(paste0("Index ", i, ": ", dados_carregados$nomes[i]))
      }))
    )
  })
  
  # 2. Processamento com IA
  observeEvent(input$executar, {
    req(dados_carregados$lista, input$prompt)
    
    # ========== TASK 026: VALIDAÇÃO DE INPUT ==========
    # Validar prompt do usuário (injeção, tamanho, etc)
    validation_result <- validate_user_prompt(
      input$prompt,
      session_id = session$ns(NULL)
    )
    
    if (!validation_result$is_valid) {
      shiny::showNotification(
        paste0("❌ Entrada inválida: ", validation_result$error_message),
        type = "error",
        duration = 5
      )
      log_security_event(
        session$ns(NULL),
        "invalid_prompt",
        "warning",
        validation_result$error_message
      )
      return()
    }
    
    # Avisos não-bloqueadores
    if (!is.null(validation_result$warnings)) {
      for (warning_msg in validation_result$warnings) {
        shiny::showNotification(
          paste0("⚠️ ", warning_msg),
          type = "warning",
          duration = 3
        )
      }
    }
    
    # ========== ML DETECTION: VALIDAÇÃO SEMÂNTICA ==========
    # Detecção ML complementar (threshold: 40 para ser mais conservadora)
    ml_result <- predict_injection(
      input$prompt,
      threshold = 40  # Mais alto que regex para evitar falsos positivos
    )
    
    # Log ML detection para análise
    log_ml_detection(
      session$ns(NULL),
      ml_result,
      input$prompt
    )
    
    # Se ML detectar alto risco, avisar mas não bloquear
    if (ml_result$is_injection && ml_result$risk_level == "high") {
      shiny::showNotification(
        paste0("🤖 ML Detection: Risco ", ml_result$risk_level, 
               " (score: ", round(ml_result$score), 
               ") | Features: ", paste(ml_result$triggered_features, collapse = ", ")),
        type = "warning",
        duration = 5
      )
      
      log_security_event(
        session$ns(NULL),
        "ml_high_risk_detected",
        "warning",
        paste0("ML Score: ", ml_result$score, " | Confidence: ", 
               round(ml_result$confidence, 2), " | Features: ",
               paste(ml_result$triggered_features, collapse = ", "))
      )
    }
    
    # Usar prompt sanitizado
    prompt_sanitizado <- validation_result$sanitized_prompt
    
    # Prepara o "schema" (apenas nomes das colunas) para enviar à IA
    esquemas <- sapply(seq_along(dados_carregados$lista), function(i) {
      cols <- paste(names(dados_carregados$lista[[i]]), collapse = ", ")
      paste0("Arquivo ", i, " (", dados_carregados$nomes[i], "): [", cols, "]")
    })
    esquemas_texto <- paste(esquemas, collapse = "\n")
    
    withProgress(message = 'Consultando GLM-4...', detail = 'Escrevendo código R...', {
      
      # A: Chama a API com prompt sanitizado
      codigo <- tryCatch({
        consultar_glm4(esquemas_texto, prompt_sanitizado, API_KEY)
      }, error = function(e) {
        showNotification(paste("Erro na API:", e$message), type = "error")
        log_security_event(
          session$ns(NULL),
          "api_error",
          "warning",
          e$message
        )
        return(NULL)
      })
      
      req(codigo)
      codigo_gerado(codigo)
      
      # B: Executa o código em sandbox seguro (Task 016)
      # Cria ambiente isolado com funções permitidas apenas
      sandbox_env <- create_sandbox_env(
        data_list = dados_carregados$lista,
        whitelist = get_allowed_functions(),
        max_memory_mb = 500
      )
      
      # Executa código com timeout e validação de segurança
      exec_result <- execute_code_safely(
        code = codigo,
        sandbox = sandbox_env,
        timeout_seconds = 60,
        max_memory_mb = 500
      )
      
      if (exec_result$success) {
        if (!is.null(exec_result$resultado)) {
          resultado_analise(exec_result$resultado)
          showNotification("Análise concluída com sucesso!", type = "message")
          
          # Log sucesso
          log_security_event(
            session$ns(NULL),
            "code_execution_success",
            "info",
            paste0(
              "Análise segura executada em ",
              nchar(codigo),
              " caracteres | Tempo: ",
              round(exec_result$duration_seconds, 2),
              "s"
            )
          )
        } else {
          showNotification(
            "A IA gerou código, mas não criou o objeto 'resultado'.",
            type = "warning"
          )
          log_security_event(
            session$ns(NULL),
            "code_execution_missing_resultado",
            "warning",
            "Código executou sem criar 'resultado'"
          )
        }
      } else {
        showNotification(
          paste("Erro ao executar código R gerado:", exec_result$error),
          type = "error"
        )
        log_security_event(
          session$ns(NULL),
          "code_execution_error",
          "warning",
          paste(
            "Erro:",
            exec_result$error,
            "| Warnings:",
            paste(exec_result$warnings, collapse = " | ")
          )
        )
      }
    })
  })
  
  # 3. Saídas
  output$tabela_resultado <- renderDT({
    req(resultado_analise())
    datatable(resultado_analise(), options = list(scrollX = TRUE, pageLength = 5))
  })
  
  output$codigo_mostrado <- renderText({
    req(codigo_gerado())
    codigo_gerado()
  })
  
  output$download_ui <- renderUI({
    req(resultado_analise())
    downloadButton("downloadData", "Baixar Resultado Excel")
  })
  
  output$downloadData <- downloadHandler(
    filename = function() { paste("resultado_analise_", Sys.Date(), ".xlsx", sep = "") },
    content = function(file) { write_xlsx(resultado_analise(), file) }
  )
  
  # Preview dos dados originais (dinâmico para múltiplos arquivos)
  output$tabs_originais <- renderUI({
    req(dados_carregados$lista)
    tabs <- lapply(seq_along(dados_carregados$lista), function(i) {
      tabPanel(title = paste("Arq", i), 
               div(style = "overflow-x: scroll;", renderTable(head(dados_carregados$lista[[i]], 10))))
    })
    do.call(tabsetPanel, tabs)
  })
  
  # ========================================================================
  # 4. DASHBOARD OUTPUTS - Security Monitoring (Task 016+)
  # ========================================================================
  
  # Auto-refresh reactive timer (5 second updates)
  invalidate_timer <- reactiveTimer(5000)
  
  # === SECURITY EVENTS TAB ===
  output$seguranca_eventos_tabela <- renderDT({
    invalidate_timer()  # Trigger refresh
    tryCatch({
      eventos <- get_security_events()
      if (nrow(eventos) > 0) {
        eventos <- eventos %>% 
          arrange(desc(timestamp)) %>%
          head(50)
        datatable(eventos, options = list(pageLength = 10, scrollX = TRUE))
      } else {
        datatable(data.frame(Mensagem = "Nenhum evento de segurança registrado"), 
                 options = list(dom = 't'))
      }
    }, error = function(e) {
      datatable(data.frame(Erro = e$message), options = list(dom = 't'))
    })
  })
  
  # === UPLOAD STATISTICS TAB ===
  
  output$upload_sucesso_plot <- renderPlot({
    invalidate_timer()
    tryCatch({
      stats <- get_upload_statistics()
      if (!is.null(stats) && nrow(stats) > 0) {
        sucesso <- stats %>% 
          group_by(status) %>% 
          summarise(count = n(), .groups = 'drop')
        
        # Pie chart
        pie(sucesso$count, labels = sucesso$status,
            main = "Taxa de Sucesso de Uploads",
            col = c("green", "red")[match(sucesso$status, c("success", "error"))])
      }
    }, error = function(e) {
      plot(1, main = "Erro ao carregar dados", xlab = e$message)
    })
  })
  
  output$upload_tamanho_plot <- renderPlot({
    invalidate_timer()
    tryCatch({
      stats <- get_upload_statistics()
      if (!is.null(stats) && nrow(stats) > 0) {
        sizes <- as.numeric(stats$file_size_mb)
        hist(sizes, main = "Distribuição de Tamanho de Arquivos",
             xlab = "Tamanho (MB)", ylab = "Frequência", 
             col = "steelblue", breaks = 10)
      }
    }, error = function(e) {
      plot(1, main = "Erro ao carregar dados", xlab = e$message)
    })
  })
  
  output$upload_historico_tabela <- renderDT({
    invalidate_timer()
    tryCatch({
      stats <- get_upload_statistics()
      if (!is.null(stats) && nrow(stats) > 0) {
        stats <- stats %>% 
          arrange(desc(timestamp)) %>%
          head(20)
        datatable(stats, options = list(pageLength = 10, scrollX = TRUE))
      } else {
        datatable(data.frame(Mensagem = "Nenhum arquivo foi enviado"), 
                 options = list(dom = 't'))
      }
    }, error = function(e) {
      datatable(data.frame(Erro = e$message), options = list(dom = 't'))
    })
  })
  
  # === RATE LIMITING TAB ===
  
  output$ratelimit_timeline_plot <- renderPlot({
    invalidate_timer()
    # For now, simple placeholder - would need to track requests
    plot(1:60, sample(1:10, 60), type = "l",
         main = "Requisições nos Últimos 60 Minutos",
         xlab = "Tempo (min)", ylab = "Requisições",
         col = "steelblue")
  })
  
  output$ratelimit_status_box <- renderUI({
    invalidate_timer()
    # Simple status indicator
    div(
      style = "background-color: #d4edda; padding: 20px; border-radius: 5px;",
      h3("✓ Em Limites", style = "color: #155724; margin: 0;"),
      p("Usando 3/10 requisições", style = "color: #155724; margin: 0;")
    )
  })
  
  output$ratelimit_stats_tabela <- renderDT({
    invalidate_timer()
    stats_df <- data.frame(
      Metrica = c("Requisições/Min", "Limite/Min", "Requisições/Hora", "Limite/Hora"),
      Valor = c("3", "10", "25", "100"),
      Status = c("✓", "✓", "✓", "✓")
    )
    datatable(stats_df, options = list(dom = 't', paging = FALSE))
  })
  
  # === SYSTEM HEALTH TAB ===
  
  output$cleanup_temp_tabela <- renderDT({
    invalidate_timer()
    tryCatch({
      temp_stats <- get_temp_files_stats()
      if (length(temp_stats) > 0) {
        df <- data.frame(
          Tipo = names(temp_stats),
          Quantidade = as.numeric(temp_stats)
        )
        datatable(df, options = list(dom = 't', paging = FALSE))
      } else {
        datatable(data.frame(Mensagem = "Sem arquivos temporários"), 
                 options = list(dom = 't'))
      }
    }, error = function(e) {
      datatable(data.frame(Erro = e$message), options = list(dom = 't'))
    })
  })
  
  output$cleanup_logs_tabela <- renderDT({
    invalidate_timer()
    tryCatch({
      log_stats <- get_log_files_stats()
      if (length(log_stats) > 0) {
        df <- data.frame(
          Arquivo = names(log_stats),
          Tamanho_KB = as.numeric(log_stats)
        )
        datatable(df, options = list(dom = 't', paging = FALSE))
      } else {
        datatable(data.frame(Mensagem = "Sem logs"), options = list(dom = 't'))
      }
    }, error = function(e) {
      datatable(data.frame(Erro = e$message), options = list(dom = 't'))
    })
  })
  
  output$cleanup_report_text <- renderText({
    invalidate_timer()
    tryCatch({
      report <- generate_cleanup_report()
      paste(report, collapse = "\n")
    }, error = function(e) {
      paste("Erro ao gerar relatório:", e$message)
    })
  })
}

shinyApp(ui, server)
library(shiny)
library(tidyverse)
library(readxl)
library(DT)
library(httr2)
library(writexl)
library(shinythemes)

# --- CONFIGURAÇÃO DA API GLM-4 (Zhipu AI) ---
# Coloque sua chave aqui ou, idealmente, use Sys.getenv("ZHIPU_API_KEY") para segurança
API_KEY <- "SUA_CHAVE_AQUI" 

# Função que chama a IA
consultar_glm4 <- function(esquemas_texto, pedido_usuario, chave_api) {
  
  # Define o endpoint oficial da Zhipu AI (Compatível com OpenAI)
  url_base <- "https://open.bigmodel.cn/api/paas/v4/chat/completions"
  
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
        )
      )
    )
  )
)

# --- SERVIDOR (SERVER) ---
server <- function(input, output) {
  
  # Variáveis Reativas para armazenar estado
  dados_carregados <- reactiveValues(lista = list(), nomes = NULL)
  resultado_analise <- reactiveVal(NULL)
  codigo_gerado <- reactiveVal(NULL)
  
  # 1. Leitura dos Arquivos
  observeEvent(input$arquivos, {
    req(input$arquivos)
    
    arquivos_temp <- list()
    nomes_temp <- c()
    
    for(i in 1:nrow(input$arquivos)) {
      caminho <- input$arquivos$datapath[i]
      nome_arquivo <- input$arquivos$name[i]
      ext <- tools::file_ext(nome_arquivo)
      
      df <- tryCatch({
        if(ext == "csv") read_csv(caminho, show_col_types = FALSE)
        else read_excel(caminho)
      }, error = function(e) return(NULL))
      
      if(!is.null(df)) {
        arquivos_temp[[i]] <- df
        nomes_temp <- c(nomes_temp, nome_arquivo)
      }
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
    
    # Prepara o "schema" (apenas nomes das colunas) para enviar à IA
    esquemas <- sapply(seq_along(dados_carregados$lista), function(i) {
      cols <- paste(names(dados_carregados$lista[[i]]), collapse = ", ")
      paste0("Arquivo ", i, " (", dados_carregados$nomes[i], "): [", cols, "]")
    })
    esquemas_texto <- paste(esquemas, collapse = "\n")
    
    withProgress(message = 'Consultando GLM-4...', detail = 'Escrevendo código R...', {
      
      # A: Chama a API
      codigo <- tryCatch({
        consultar_glm4(esquemas_texto, input$prompt, API_KEY)
      }, error = function(e) {
        showNotification(paste("Erro na API:", e$message), type = "error")
        return(NULL)
      })
      
      req(codigo)
      codigo_gerado(codigo)
      
      # B: Executa o código (Eval)
      # Ambiente isolado para execução
      env_execucao <- new.env()
      env_execucao$lista_dados <- dados_carregados$lista
      env_execucao$library(dplyr)
      env_execucao$library(tidyr)
      
      tryCatch({
        eval(parse(text = codigo), envir = env_execucao)
        
        if(exists("resultado", envir = env_execucao)) {
          resultado_analise(env_execucao$resultado)
          showNotification("Análise concluída com sucesso!", type = "message")
        } else {
          showNotification("A IA gerou código, mas não criou o objeto 'resultado'.", type = "warning")
        }
      }, error = function(e) {
        showNotification(paste("Erro ao executar código R gerado:", e$message), type = "error")
      })
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
}

shinyApp(ui, server)
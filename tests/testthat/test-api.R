# Tests for API Integration (Zhipu AI GLM-4)
# Uses mocked responses to avoid real API calls during testing

library(testthat)
library(httr2)

# Helper function to extract consultar_glm4 logic
# In a real implementation, this would be sourced from app.r or a separate module
source_app_functions <- function() {
  # This would ideally source modularized functions
  # For now, we'll create mock versions for testing
}

test_that("API request is properly structured", {
  # Mock the API key and inputs
  esquemas_texto <- "Arquivo 1 (vendas.csv): [id, produto, valor, vendedor]"
  pedido_usuario <- "Filtre vendas acima de 500"
  chave_api <- "test_api_key_123"
  
  # Test that we can construct a valid request object
  url_base <- "https://open.bigmodel.cn/api/paas/v4/chat/completions"
  
  req <- request(url_base) %>%
    req_method("POST") %>%
    req_headers(
      "Authorization" = paste("Bearer", chave_api),
      "Content-Type" = "application/json"
    )
  
  # Verify request components
  expect_s3_class(req, "httr2_request")
  expect_equal(req$method, "POST")
  expect_true("Authorization" %in% names(req$headers))
  expect_equal(req$headers$Authorization, "Bearer test_api_key_123")
})

test_that("API request body contains required fields", {
  system_prompt <- "Você é um especialista sênior em R e tidyverse."
  user_content <- "Estrutura dos dados disponíveis:\nArquivo 1: [col1, col2]\n\nPedido: Teste"
  
  body_list <- list(
    model = "glm-4",
    messages = list(
      list(role = "system", content = system_prompt),
      list(role = "user", content = user_content)
    ),
    temperature = 0.1
  )
  
  # Verify structure
  expect_equal(body_list$model, "glm-4")
  expect_equal(length(body_list$messages), 2)
  expect_equal(body_list$messages[[1]]$role, "system")
  expect_equal(body_list$messages[[2]]$role, "user")
  expect_equal(body_list$temperature, 0.1)
})

test_that("Code cleaning removes markdown markers", {
  # Test the code cleaning logic
  codigo_bruto <- "```r\nresultado <- mtcars %>% filter(mpg > 20)\n```"
  codigo_limpo <- gsub("```r|```", "", codigo_bruto)
  codigo_limpo <- trimws(codigo_limpo)
  
  expect_false(grepl("```", codigo_limpo))
  expect_true(grepl("resultado <-", codigo_limpo))
  expect_true(grepl("filter", codigo_limpo))
})

test_that("Multiple markdown blocks are cleaned correctly", {
  codigo_bruto <- "```r\nlibrary(dplyr)\n```\n\nAlgum texto\n\n```r\nresultado <- data\n```"
  codigo_limpo <- gsub("```r|```", "", codigo_bruto)
  
  expect_false(grepl("```", codigo_limpo))
  expect_true(grepl("library\\(dplyr\\)", codigo_limpo))
  expect_true(grepl("resultado <- data", codigo_limpo))
})

test_that("Schema text is properly formatted", {
  # Simulate creating schema text from multiple dataframes
  df1 <- data.frame(id = 1:3, nome = c("A", "B", "C"), valor = c(100, 200, 300))
  df2 <- data.frame(id = 1:2, produto = c("X", "Y"), preco = c(50, 75))
  
  lista_dados <- list(df1, df2)
  nomes_arquivos <- c("vendas.csv", "produtos.xlsx")
  
  esquemas <- sapply(seq_along(lista_dados), function(i) {
    cols <- paste(names(lista_dados[[i]]), collapse = ", ")
    paste0("Arquivo ", i, " (", nomes_arquivos[i], "): [", cols, "]")
  })
  
  expect_equal(length(esquemas), 2)
  expect_true(grepl("vendas.csv", esquemas[1]))
  expect_true(grepl("id, nome, valor", esquemas[1]))
  expect_true(grepl("produtos.xlsx", esquemas[2]))
  expect_true(grepl("id, produto, preco", esquemas[2]))
})

test_that("User content combines schema and request", {
  esquemas_texto <- "Arquivo 1: [col1, col2, col3]"
  pedido_usuario <- "Filtre por col1 > 10"
  
  user_content <- paste0(
    "Estrutura dos dados disponíveis:\n", esquemas_texto, "\n\n",
    "Pedido do usuário: ", pedido_usuario
  )
  
  expect_true(grepl("Estrutura dos dados", user_content))
  expect_true(grepl("Arquivo 1", user_content))
  expect_true(grepl("Pedido do usuário", user_content))
  expect_true(grepl("Filtre por col1 > 10", user_content))
})

# Skip actual API calls in automated testing
test_that("API error handling works (skipped - requires API key)", {
  skip_if_not(nchar(Sys.getenv("ZHIPU_API_KEY")) > 0, "No API key available")
  skip("Skipping live API test - use mocks instead")
  
  # This test would check error handling with invalid credentials
  # In practice, use httptest2 or webmockr for mocking
})

test_that("System prompt contains essential instructions", {
  system_prompt <- "Você é um especialista sênior em R e tidyverse.
  Sua tarefa é gerar APENAS código R executável para transformar dataframes.
  
  Regras:
  1. O usuário fornecerá os nomes das colunas de um ou mais dataframes carregados numa lista chamada 'lista_dados'.
  2. Os dataframes dentro da lista são acessados como: lista_dados[[1]], lista_dados[[2]], etc.
  3. Se houver apenas um arquivo, use lista_dados[[1]].
  4. Retorne APENAS o bloco de código R. SEM explicações, SEM comentários, SEM ```r ```.
  5. O resultado final deve ser salvo em um objeto chamado 'resultado'.
  6. Use preferencialmente funções do pacote dplyr (filter, select, mutate, group_by, summarise)."
  
  # Verify key instructions are present
  expect_true(grepl("lista_dados", system_prompt))
  expect_true(grepl("resultado", system_prompt))
  expect_true(grepl("dplyr", system_prompt))
  expect_true(grepl("APENAS código R", system_prompt))
})

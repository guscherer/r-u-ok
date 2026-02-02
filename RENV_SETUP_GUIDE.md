# Guia de Configuração do renv para R-U-OK

## Visão Geral

Este guia documenta o processo de inicialização do renv para gerenciamento reproduzível de dependências no projeto R-U-OK.

## Pré-requisitos

- R instalado (versão 4.0 ou superior recomendada)
- RStudio (opcional, mas recomendado)
- Acesso à internet para download de pacotes

## Dependências do Projeto

O projeto R-U-OK requer os seguintes pacotes:

- `shiny` - Framework para aplicações web interativas
- `tidyverse` - Coleção de pacotes para ciência de dados
- `DT` - Tabelas interativas
- `httr2` - Cliente HTTP moderno
- `readxl` - Leitura de arquivos Excel
- `writexl` - Escrita de arquivos Excel
- `shinythemes` - Temas para Shiny

## Instruções de Configuração

### Método 1: Executar via RStudio (Recomendado)

1. Abra o RStudio
2. Abra o projeto R-U-OK (arquivo `r-u-ok.Rproj` ou a pasta do projeto)
3. No Console do R, execute:
   ```r
   source("setup_renv.R")
   ```

### Método 2: Executar via R Console

1. Abra o R Console
2. Navegue até o diretório do projeto:
   ```r
   setwd("c:/Users/Gustavo/Documents/Dev/r-u-ok/r-u-ok")
   ```
3. Execute o script de configuração:
   ```r
   source("setup_renv.R")
   ```

### Método 3: Comandos Manuais

Se preferir executar os comandos manualmente:

```r
# 1. Instalar renv
install.packages("renv")

# 2. Inicializar renv
renv::init()

# 3. Capturar snapshot das dependências
renv::snapshot()
```

## Arquivos Criados pelo renv

Após a inicialização bem-sucedida, você verá os seguintes arquivos/diretórios:

### `.Rprofile`

- Auto-ativa o renv quando o projeto é aberto
- Garante que todos usem a mesma biblioteca de pacotes

### `renv.lock`

- Lockfile JSON com versões exatas de todos os pacotes
- Inclui informações de repositório e hash
- Permite reprodução exata do ambiente

### `renv/` (diretório)

Estrutura típica:

```
renv/
├── activate.R       # Script de ativação do renv
├── library/         # Biblioteca privada de pacotes
├── settings.dcf     # Configurações do renv
└── .gitignore       # Ignora biblioteca mas mantém lockfile
```

## Verificação da Configuração

Execute no R Console:

```r
# Verificar status do renv
renv::status()

# Listar pacotes instalados
renv::dependencies()

# Ver informações do projeto
renv::diagnostics()
```

## Fluxo de Trabalho com renv

### Instalando Novos Pacotes

```r
# Instalar pacote
renv::install("nome_do_pacote")

# Atualizar lockfile
renv::snapshot()
```

### Atualizando Pacotes

```r
# Atualizar um pacote específico
renv::update("shiny")

# Atualizar todos os pacotes
renv::update()

# Salvar mudanças
renv::snapshot()
```

### Restaurando Ambiente

```r
# Restaurar pacotes do lockfile (útil para novos colaboradores)
renv::restore()
```

### Removendo Pacotes Não Utilizados

```r
# Limpar pacotes órfãos
renv::clean()
```

## Colaboração com Git

### O que Commitar

✅ **SIM** - Commitar estes arquivos:

- `.Rprofile`
- `renv.lock`
- `renv/activate.R`
- `renv/.gitignore`
- `renv/settings.dcf`

❌ **NÃO** - Não commitar:

- `renv/library/` (biblioteca de pacotes - muito grande)
- `renv/staging/` (arquivos temporários)

O `.gitignore` do renv já cuida disso automaticamente.

### Para Novos Colaboradores

Quando um colaborador clona o repositório:

1. Abrir o projeto no RStudio
2. O `.Rprofile` ativa o renv automaticamente
3. Executar `renv::restore()` para instalar todas as dependências

## Solução de Problemas

### "renv não está ativado"

```r
source("renv/activate.R")
```

### "Pacotes desatualizados"

```r
renv::status()
renv::snapshot()  # Se quiser salvar o estado atual
# OU
renv::restore()   # Se quiser voltar ao lockfile
```

### "Conflitos de versão"

```r
# Ver diferenças
renv::status()

# Resetar para o lockfile
renv::restore()
```

### Problemas de Download

Se houver problemas com repositórios CRAN:

```r
# Configurar mirror CRAN alternativo
options(repos = c(CRAN = "https://cloud.r-project.org"))
renv::restore()
```

## Benefícios do renv

1. **Reprodutibilidade**: Mesmas versões de pacotes em todos os ambientes
2. **Isolamento**: Cada projeto tem sua própria biblioteca
3. **Portabilidade**: Fácil compartilhar com colaboradores
4. **Histórico**: Lockfile rastreável no Git
5. **Estabilidade**: Atualizações controladas de dependências

## Referências

- [Documentação oficial do renv](https://rstudio.github.io/renv/)
- [Artigo: Introduction to renv](https://rstudio.github.io/renv/articles/renv.html)
- [FAQ do renv](https://rstudio.github.io/renv/articles/faq.html)

## Próximas Etapas

Após configurar o renv:

1. Verificar que todos os pacotes estão instalados: `renv::status()`
2. Testar a aplicação Shiny: `shiny::runApp("app.r")`
3. Commitar arquivos do renv no Git
4. Documentar dependências no README (se existir)

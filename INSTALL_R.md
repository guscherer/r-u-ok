# Guia de Instalação do R para Configuração do renv

## Status Atual

O R não foi detectado no sistema. Para completar a inicialização do renv, você precisa primeiro instalar o R.

## Instalação do R no Windows

### Opção 1: Download Direto (Recomendado)

1. Acesse: https://cran.r-project.org/bin/windows/base/
2. Baixe a versão mais recente (R-4.x.x for Windows)
3. Execute o instalador
4. **IMPORTANTE**: Durante a instalação, marque a opção "Add R to PATH"
5. Siga as instruções padrão de instalação

### Opção 2: Via Chocolatey

Se você tem o Chocolatey instalado:

```powershell
choco install r.project -y
```

### Opção 3: Via winget

```powershell
winget install -e --id RProject.R
```

## Instalação do RStudio (Opcional mas Recomendado)

1. Acesse: https://posit.co/download/rstudio-desktop/
2. Baixe o RStudio Desktop (versão gratuita)
3. Execute o instalador
4. O RStudio detectará automaticamente a instalação do R

## Após Instalar o R

### Verificar Instalação

Abra um novo PowerShell e execute:

```powershell
Rscript --version
```

Você deve ver algo como:

```
R scripting front-end version 4.x.x (2024-xx-xx)
```

### Executar Setup do renv

Depois que o R estiver instalado, você pode inicializar o renv de três formas:

#### Método 1: Via RStudio (Mais Fácil)

1. Abra o RStudio
2. Abra este projeto (File > Open Project)
3. No Console do R, execute:

```r
source("setup_renv.R")
```

#### Método 2: Via R Console

1. Abra o R (ícone no menu Iniciar)
2. Execute:

```r
setwd("c:/Users/Gustavo/Documents/Dev/r-u-ok/r-u-ok")
source("setup_renv.R")
```

#### Método 3: Via PowerShell (Após adicionar R ao PATH)

```powershell
cd "c:\Users\Gustavo\Documents\Dev\r-u-ok\r-u-ok"
Rscript setup_renv.R
```

## Próximos Passos

Após instalar o R e executar o setup:

1. ✅ Verificar que os arquivos foram criados:

   - `.Rprofile`
   - `renv.lock`
   - `renv/` directory

2. ✅ Verificar dependências capturadas:

   - shiny
   - tidyverse
   - DT
   - httr2
   - readxl
   - writexl
   - shinythemes

3. ✅ Testar a aplicação:
   ```r
   shiny::runApp("app.r")
   ```

## Troubleshooting

### "Rscript não é reconhecido"

- O R não foi adicionado ao PATH
- Solução: Adicione manualmente ou reinstale marcando a opção PATH

### "Não consigo abrir o projeto no RStudio"

- Crie um arquivo `.Rproj`:
  - File > New Project > Existing Directory
  - Selecione a pasta r-u-ok

### "Pacotes não instalam"

- Verifique conexão com internet
- Configure proxy se necessário:
  ```r
  Sys.setenv(http_proxy = "http://proxy:port")
  ```

## Suporte

- Documentação do R: https://www.r-project.org/
- Documentação do renv: https://rstudio.github.io/renv/
- RStudio Community: https://community.rstudio.com/

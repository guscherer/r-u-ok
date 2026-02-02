# Status da Inicialização do renv - R-U-OK

## Data: 2 de fevereiro de 2026

## Situação Atual

❌ **R não foi encontrado no sistema**

A tentativa de inicializar o renv para gerenciamento reproduzível de dependências não pôde ser completada porque o R não está instalado ou não está disponível no PATH do sistema Windows.

## Arquivos Preparados

Os seguintes arquivos foram criados e estão prontos para quando o R for instalado:

### ✅ Arquivos de Configuração do renv

1. **`.Rprofile`**

   - Localização: `c:\Users\Gustavo\Documents\Dev\r-u-ok\r-u-ok\.Rprofile`
   - Função: Auto-ativa o renv quando o projeto é aberto
   - Status: Criado com script de ativação

2. **`renv/`** (diretório)

   - Localização: `c:\Users\Gustavo\Documents\Dev\r-u-ok\r-u-ok\renv\`
   - Estrutura criada:
     - `renv/.gitignore` - Configuração de Git para ignorar biblioteca mas manter lockfile
     - `renv/settings.dcf` - Configurações do renv
   - Pendente: `renv/activate.R` (será criado pelo renv::init())

3. **`renv.lock.template`**
   - Modelo de lockfile com as dependências esperadas do projeto
   - Será substituído pelo arquivo real `renv.lock` após `renv::init()`

### ✅ Scripts de Inicialização

4. **`setup_renv.R`**
   - Script R completo para inicializar renv
   - Executa automaticamente:
     - Instalação do renv (se necessário)
     - Inicialização do projeto com `renv::init()`
     - Snapshot das dependências com `renv::snapshot()`
     - Verificação da configuração
   - **EXECUTE ESTE SCRIPT quando o R estiver instalado**

### ✅ Documentação

5. **`INSTALL_R.md`**

   - Guia completo de instalação do R no Windows
   - Opções: Download direto, Chocolatey, winget
   - Instruções pós-instalação
   - Troubleshooting

6. **`RENV_SETUP_GUIDE.md`**
   - Documentação completa do renv
   - Estrutura de arquivos criados
   - Fluxo de trabalho com renv
   - Comandos essenciais
   - Solução de problemas

## Dependências do Projeto Identificadas

As seguintes dependências do projeto R-U-OK foram identificadas em `app.r`:

| Pacote        | Função                                   |
| ------------- | ---------------------------------------- |
| `shiny`       | Framework web interativo                 |
| `tidyverse`   | Coleção de pacotes para ciência de dados |
| `DT`          | Tabelas interativas                      |
| `httr2`       | Cliente HTTP moderno                     |
| `readxl`      | Leitura de arquivos Excel                |
| `writexl`     | Escrita de arquivos Excel                |
| `shinythemes` | Temas para Shiny                         |

## Próximos Passos

Para completar a inicialização do renv:

### PASSO 1: Instalar o R

```powershell
# Opção 1: Via Chocolatey (se disponível)
choco install r.project -y

# Opção 2: Via winget
winget install -e --id RProject.R

# Opção 3: Download manual
# Visite: https://cran.r-project.org/bin/windows/base/
```

**IMPORTANTE**: Certifique-se de marcar "Add R to PATH" durante a instalação!

### PASSO 2: Verificar Instalação

```powershell
# Abrir novo PowerShell e testar:
Rscript --version
```

### PASSO 3: Executar Script de Setup

**Método Recomendado - via RStudio:**

```r
# 1. Abrir RStudio
# 2. Abrir projeto R-U-OK
# 3. No Console R:
source("setup_renv.R")
```

**Método Alternativo - via PowerShell:**

```powershell
cd "c:\Users\Gustavo\Documents\Dev\r-u-ok\r-u-ok"
Rscript setup_renv.R
```

### PASSO 4: Verificar Resultados

Após executar o setup, você deverá ver:

```
✓ .Rprofile criado
✓ renv.lock criado
✓ renv/ directory criado
  - renv/activate.R
  - renv/library/
  - renv/settings.dcf
  - renv/.gitignore

Dependências capturadas (X pacotes):
  - shiny (versão)
  - tidyverse (versão)
  - DT (versão)
  - httr2 (versão)
  - readxl (versão)
  - writexl (versão)
  - shinythemes (versão)
```

## Arquivos para Commitar no Git

Depois que o renv for inicializado:

### ✅ COMMITAR (versionar):

- `.Rprofile`
- `renv.lock`
- `renv/activate.R`
- `renv/.gitignore`
- `renv/settings.dcf`
- `setup_renv.R` (opcional, mas recomendado)
- `RENV_SETUP_GUIDE.md` (opcional, mas recomendado)

### ❌ NÃO COMMITAR (ignorar):

- `renv/library/` (biblioteca de pacotes - muito grande)
- `renv/staging/` (temporário)
- `.Rhistory`
- `.RData`

O `.gitignore` do renv já está configurado corretamente!

## Benefícios do renv (quando configurado)

1. **Reprodutibilidade**: Todos os desenvolvedores usam as mesmas versões
2. **Isolamento**: Cada projeto tem sua própria biblioteca
3. **Portabilidade**: Fácil compartilhar entre máquinas
4. **Histórico**: Versões rastreadas no Git
5. **Estabilidade**: Atualizações controladas

## Comandos Essenciais do renv

Após a inicialização:

```r
# Ver status do projeto
renv::status()

# Instalar novo pacote
renv::install("nome_pacote")

# Atualizar lockfile
renv::snapshot()

# Restaurar de lockfile
renv::restore()

# Ver diagnósticos
renv::diagnostics()
```

## Suporte

- **Documentação do renv**: https://rstudio.github.io/renv/
- **Tutorial de iniciação**: https://rstudio.github.io/renv/articles/renv.html
- **FAQ**: https://rstudio.github.io/renv/articles/faq.html

## Notas Técnicas

- **Versão esperada do renv**: 1.0.7+ (será instalada automaticamente)
- **Versão mínima do R**: 4.0.0+ (recomendado: 4.3.0+)
- **Sistema operacional**: Windows 11
- **Repositório CRAN**: https://cloud.r-project.org
- **Tipo de snapshot**: implicit (detecta automaticamente dependências)
- **Cache**: Habilitado (compartilha pacotes entre projetos)

## Histórico de Tentativa

**Data**: 2 de fevereiro de 2026  
**Ação**: Tentativa de inicializar renv via PowerShell  
**Resultado**: R não encontrado no sistema  
**Solução**: Documentação completa criada e scripts preparados

---

**Status Final**: PREPARADO - Aguardando instalação do R para completar inicialização

Para qualquer dúvida, consulte os arquivos de documentação:

- [INSTALL_R.md](INSTALL_R.md) - Como instalar o R
- [RENV_SETUP_GUIDE.md](RENV_SETUP_GUIDE.md) - Guia completo do renv

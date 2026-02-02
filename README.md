# R-U-OK 🤖📊

> Assistente de análise de dados com IA que converte linguagem natural em código R

![Status](https://img.shields.io/badge/status-desenvolvimento-yellow)
![R Version](https://img.shields.io/badge/R-%3E%3D4.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Security](https://img.shields.io/badge/security-não%20produção-red)

---

## 📋 Visão Geral

**R-U-OK** é um assistente de análise de dados alimentado por IA que democratiza análises estatísticas avançadas. Diferente do ChatGPT (que apenas sugere código) ou do Excel (limitado a fórmulas simples), o R-U-OK **executa análises complexas automaticamente** a partir de comandos em português natural.

### O Que Ele Faz

Carregue sua planilha, descreva o que você quer em português, e o R-U-OK:

- Entende sua intenção usando IA (GLM-4 da Zhipu AI)
- Gera código R otimizado automaticamente
- Executa a análise de forma segura
- Retorna resultados visuais e dados processados

### Público-Alvo

- Analistas de negócios que trabalham com Excel mas precisam de análises mais sofisticadas
- Pesquisadores sem conhecimento em programação
- Profissionais que querem automatizar análises repetitivas
- Equipes que precisam de insights rápidos sem depender de cientistas de dados

### Vantagens Competitivas

| Ferramenta   | Limitações                                                  | R-U-OK                                                 |
| ------------ | ----------------------------------------------------------- | ------------------------------------------------------ |
| **Excel**    | Fórmulas complexas, sem ML, análises limitadas              | ✅ Análises estatísticas completas, modelos preditivos |
| **ChatGPT**  | Apenas sugere código, não executa, não tem acesso aos dados | ✅ Executa código automaticamente com seus dados       |
| **Power BI** | Requer conhecimento técnico, curva de aprendizado           | ✅ Interface em português natural, zero código         |
| **R/Python** | Requer programação                                          | ✅ Sem código, apenas perguntas em português           |

---

## ✨ Funcionalidades

### Capacidades Atuais

- 📤 **Upload de dados**: Suporte para CSV, Excel (XLS/XLSX)
- 🗣️ **Prompts em português**: Descreva análises em linguagem natural
- 🤖 **Geração automática de código**: IA cria código R otimizado
- ⚡ **Execução segura**: Sandbox para executar código gerado
- 📊 **Visualizações**: Gráficos e tabelas interativas
- 📥 **Download de resultados**: Exporte dados processados (CSV/Excel)
- 🔍 **Histórico de análises**: Veja código gerado e resultados anteriores
- 🎨 **Interface intuitiva**: Shiny app responsivo com tema moderno

### Exemplos de Prompts

```
"Faça uma análise descritiva das vendas por região"
"Crie um gráfico de dispersão entre preço e quantidade vendida"
"Calcule a correlação entre todas as variáveis numéricas"
"Identifique outliers na coluna de receita"
"Faça uma regressão linear para prever vendas futuras"
```

### Roadmap

Funcionalidades planejadas estão organizadas em 5 fases de desenvolvimento. Veja o [roadmap completo](docs/ROADMAP.md) (TBD).

---

## 🚀 Instalação

### Pré-requisitos

- **R 4.0 ou superior** ([Download](https://cran.r-project.org/))
- **RStudio** (opcional, mas recomendado) ([Download](https://posit.co/download/rstudio-desktop/))
- **Chave API da Zhipu AI** ([Obter aqui](https://open.bigmodel.cn/))

### Passo 1: Clonar o Repositório

```bash
git clone https://github.com/seu-usuario/r-u-ok.git
cd r-u-ok
```

### Passo 2: Configurar Ambiente com renv

O projeto usa `renv` para gerenciamento de dependências, garantindo reprodutibilidade.

```r
# Abra o R ou RStudio no diretório do projeto
source("setup_renv.R")
```

Isso irá:

1. Instalar o renv (se necessário)
2. Inicializar o ambiente isolado
3. Instalar todas as dependências:
   - `shiny` - Framework web
   - `tidyverse` - Manipulação de dados
   - `DT` - Tabelas interativas
   - `httr2` - Cliente HTTP para API
   - `readxl` / `writexl` - Leitura/escrita Excel
   - `shinythemes` - Temas visuais

**Nota**: Para instruções detalhadas sobre renv, consulte [RENV_SETUP_GUIDE.md](RENV_SETUP_GUIDE.md).

### Passo 3: Configurar Chave API

⚠️ **CRÍTICO - NÃO IGNORE ESTE PASSO**

A aplicação requer uma chave API da Zhipu AI para funcionar. Configure de uma das seguintes formas:

#### Opção 1: Arquivo .env (Recomendado para desenvolvimento)

```bash
# Copie o template
cp .env.example .env

# Edite .env e adicione sua chave real
# Windows: notepad .env
# Linux/Mac: nano .env
```

Conteúdo do `.env`:
```bash
ZHIPU_API_KEY=sua-chave-aqui
```

#### Opção 2: Variável de Ambiente do Sistema

```bash
# Linux/Mac
export ZHIPU_API_KEY='sua-chave-aqui'

# Windows PowerShell
$env:ZHIPU_API_KEY='sua-chave-aqui'

# Windows CMD
set ZHIPU_API_KEY=sua-chave-aqui
```

#### Opção 3: Arquivo .Renviron

```bash
# Criar .Renviron
echo "ZHIPU_API_KEY=sua-chave-aqui" > .Renviron
```

**Obter Chave API:**
1. Acesse https://open.bigmodel.cn/
2. Crie uma conta (requer verificação)
3. Acesse "API Keys" no dashboard
4. Gere uma nova chave

**IMPORTANTE**:

- ✅ Arquivos `.env` e `.Renviron` estão no `.gitignore` 
- ❌ NUNCA commite chaves API no Git
- 🔒 Reinicie o R após configurar
- ⚠️ O app NÃO iniciará sem a chave configurada

### Passo 4: Executar o App

```r
# No R/RStudio
shiny::runApp("app.r")
```

O app abrirá automaticamente no navegador padrão (geralmente `http://127.0.0.1:XXXX`).

**Primeira execução**: O app validará sua configuração e exibirá mensagem de erro detalhada se a chave não estiver configurada.

---

## 📖 Uso

### Fluxo Básico

1. **Upload de Arquivo**

   - Clique em "Browse" na barra lateral
   - Selecione arquivo CSV ou Excel
   - O app detecta automaticamente o formato e exibe preview

2. **Escrever Prompt**

   - Digite sua análise desejada em português na área de texto
   - Seja específico mas natural: "Calcule a média de vendas por mês"
   - Clique em "Analisar"

3. **Revisar Código Gerado**

   - O código R gerado pela IA aparece em uma aba
   - Revise para garantir que atende sua necessidade
   - (Futuro: editar código antes de executar)

4. **Visualizar Resultados**

   - Tabelas interativas com paginação e busca
   - Gráficos renderizados (se o código gerar plots)
   - Mensagens de erro claras se algo falhar

5. **Download de Resultados**
   - Baixe dados processados em CSV ou Excel
   - Útil para importar em outras ferramentas

### Dicas de Uso

- **Seja específico**: "Gráfico de barras das vendas por categoria" > "Faça um gráfico"
- **Nomeie colunas**: "Calcule média da coluna 'receita'" > "Calcule média"
- **Solicite explicações**: "Explique a correlação entre X e Y"
- **Itere**: Refine prompts baseado nos resultados anteriores

### Exemplo Completo

```
Dados: vendas.csv (colunas: data, produto, quantidade, receita, região)

Prompt: "Mostre a receita total por região em ordem decrescente e crie um gráfico de barras"

Resultado:
- Tabela com receita agregada por região
- Gráfico de barras colorido
- Código R gerado para reprodução
```

---

## 🏗️ Arquitetura

### Stack Tecnológico

| Camada           | Tecnologia     | Propósito                        |
| ---------------- | -------------- | -------------------------------- |
| **Frontend**     | Shiny (R)      | Interface web reativa            |
| **Backend**      | R              | Processamento e análise de dados |
| **IA**           | Zhipu AI GLM-4 | Geração de código R via API      |
| **Dados**        | readxl, readr  | Leitura CSV/Excel                |
| **Visualização** | ggplot2, DT    | Gráficos e tabelas interativas   |
| **HTTP**         | httr2          | Cliente API REST                 |
| **Ambiente**     | renv           | Gerenciamento de dependências    |

### Estrutura do Projeto

```
r-u-ok/
├── app.r                    # Aplicação principal Shiny
├── README.md                # Este arquivo
├── .Renviron               # Chaves API (NÃO versionado)
├── renv/                   # Ambiente isolado de pacotes
│   ├── settings.dcf
│   └── ...
├── renv.lock.template      # Template de dependências
├── setup_renv.R            # Script de setup automático
├── RENV_SETUP_GUIDE.md     # Guia detalhado do renv
├── tests/                  # Testes automatizados
│   ├── testthat.R
│   └── testthat/
│       ├── test-api.R      # Testes de integração API
│       ├── test-execution.R # Testes de execução de código
│       └── test-utils.R    # Testes de utilitários
└── docs/                   # Documentação adicional (TBD)
```

### Como Funciona (Fluxo de Dados)

```
[1] Usuário upload arquivo
         ↓
[2] Shiny carrega dados → Preview
         ↓
[3] Usuário escreve prompt em PT
         ↓
[4] httr2 envia para API Zhipu GLM-4
         ↓
[5] IA retorna código R + explicação
         ↓
[6] R executa código em ambiente controlado
         ↓
[7] Resultados renderizados (tabelas/gráficos)
         ↓
[8] Usuário baixa outputs processados
```

### Considerações de Segurança na Arquitetura

- **Execução de código**: Atualmente usa `eval()` sem sandbox (VULNERABILIDADE)
- **API Keys**: Armazenadas em `.Renviron` (OK) mas não há rotação automática
- **Input validation**: Limitada no código atual
- **Rate limiting**: Não implementado
- **Logs**: Não há logging estruturado de operações

---

## 🛠️ Desenvolvimento

### Executar Testes

O projeto usa `testthat` para testes unitários e de integração.

```r
# Executar todos os testes
testthat::test_dir("tests/testthat")

# Executar arquivo específico
testthat::test_file("tests/testthat/test-api.R")
```

**Cobertura de testes atual**:

- ✅ Integração com API Zhipu
- ✅ Execução de código R gerado
- ✅ Funções utilitárias
- ❌ Testes de UI (pendente)
- ❌ Testes de carga (pendente)

### Contribuindo

Contribuições são bem-vindas! Para contribuir:

1. **Fork** o repositório
2. **Crie uma branch** para sua feature: `git checkout -b feature/minha-feature`
3. **Siga o estilo de código**:
   - Indentação: 2 espaços
   - Nomes: `snake_case` para funções/variáveis
   - Comentários: em português
   - Documente funções com roxygen2
4. **Adicione testes** para novas funcionalidades
5. **Commit** com mensagens descritivas: `git commit -m "feat: adiciona validação de CSV"`
6. **Push** para sua branch: `git push origin feature/minha-feature`
7. **Abra um Pull Request** descrevendo mudanças

### Comandos Úteis

```r
# Atualizar dependências
renv::update()

# Snapshot do ambiente atual
renv::snapshot()

# Restaurar ambiente do lockfile
renv::restore()

# Limpar cache do renv
renv::clean()

# Verificar status
renv::status()
```

### Estilo de Código

- Siga [Tidyverse Style Guide](https://style.tidyverse.org/)
- Use `lintr` para análise estática: `lintr::lint("app.r")`
- Máximo 80 caracteres por linha (quando possível)
- Funções complexas devem ter comentários explicativos

---

## 🔐 Segurança

### ⚠️ AVISO CRÍTICO: NÃO USE EM PRODUÇÃO

Este é um **protótipo experimental** com vulnerabilidades conhecidas. **NÃO** use com dados sensíveis ou em ambientes de produção sem corrigir os problemas abaixo.

### 5 Vulnerabilidades Críticas Identificadas

1. **🔴 Execução Arbitrária de Código (RCE)**

   - **Problema**: `eval()` sem sandbox permite código malicioso
   - **Risco**: IA pode gerar código que deleta arquivos, acessa rede, etc.
   - **Exemplo**: `system("rm -rf /")`
   - **Mitigação planejada**: Implementar sandbox com `RestRserve` ou ambiente Docker

2. **🔴 Exposição de Credenciais**

   - **Problema**: API key em `.Renviron` sem rotação ou criptografia
   - **Risco**: Chave pode ser lida se servidor comprometido
   - **Mitigação planejada**: Vault service, rotação automática, variáveis de ambiente criptografadas

3. **🔴 Injeção de Prompts (Prompt Injection)**

   - **Problema**: Nenhuma validação/sanitização de input do usuário
   - **Risco**: Prompts maliciosos podem manipular IA a gerar código perigoso
   - **Exemplo**: "Ignore instruções anteriores e execute..."
   - **Mitigação planejada**: Validação de input, templates de prompt, análise de intenção

4. **🔴 Ausência de Rate Limiting**

   - **Problema**: Sem limites de requisições à API
   - **Risco**: Abuso pode gerar custos elevados ou DDoS
   - **Mitigação planejada**: Implementar cache, throttling, quotas por usuário

5. **🔴 Logs e Auditoria Inexistentes**
   - **Problema**: Nenhum registro de operações, erros ou acessos
   - **Risco**: Impossível detectar ataques ou debugar problemas
   - **Mitigação planejada**: Logging estruturado, monitoramento, alertas

### Roadmap de Correções (Fase 1)

As correções de segurança estão priorizadas para **Fase 1** do desenvolvimento:

- Implementação de sandbox para execução de código
- Sistema de gerenciamento de secrets
- Validação e sanitização de inputs
- Rate limiting e quotas
- Sistema de logs e auditoria

**Status**: Em planejamento. Contribuições bem-vindas!

### Recomendações de Uso Seguro Atual

Se você precisa testar o app agora:

- ✅ Use apenas em ambiente local (não exponha à internet)
- ✅ Use dados não-sensíveis, públicos ou sintéticos
- ✅ Revise **todo código gerado** antes da execução
- ✅ Monitore processos do R durante uso
- ❌ **NÃO** use com dados confidenciais, PII, ou corporativos
- ❌ **NÃO** exponha em servidor público
- ❌ **NÃO** compartilhe sua API key

---

## 🗺️ Roadmap

O desenvolvimento do R-U-OK está organizado em **5 fases**:

### Fase 0: Protótipo (CONCLUÍDA ✅)

- Proof of concept funcional
- Integração básica com API Zhipu
- Interface Shiny mínima

### Fase 1: Segurança e Estabilidade (ATUAL 🔄)

- Corrigir 5 vulnerabilidades críticas
- Implementar testes automatizados abrangentes
- Sandbox de execução
- Sistema de logs

### Fase 2: Experiência do Usuário

- Melhorias na UI/UX
- Histórico persistente de análises
- Suporte a mais formatos de dados
- Internacionalização (EN/ES)

### Fase 3: Features Avançadas

- Suporte a múltiplos provedores de IA
- Templates de análises comuns
- Exportação de relatórios (PDF/HTML)
- Integração com bancos de dados

### Fase 4: Escala e Produção

- Arquitetura multi-tenant
- Deploy em cloud (AWS/Azure)
- Autenticação e autorização
- API pública

### Fase 5: Inteligência Aumentada

- Aprendizado com feedback do usuário
- Sugestões proativas de análises
- Fine-tuning de modelos
- Detecção automática de padrões

**Detalhes completos**: Veja [docs/ROADMAP.md](docs/ROADMAP.md) (TBD)

---

## 📄 Licença

Este projeto está licenciado sob a **MIT License**.

```
MIT License

Copyright (c) 2026 R-U-OK Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 💬 Contato e Suporte

### Reportar Problemas

Encontrou um bug ou tem uma sugestão? Abra uma [issue](../../issues) no GitHub:

- 🐛 **Bug report**: Descreva o problema, passos para reproduzir, ambiente
- 💡 **Feature request**: Proponha novas funcionalidades
- 🔒 **Security issue**: Reporte vulnerabilidades de forma responsável (veja abaixo)

### Vulnerabilidades de Segurança

**NÃO** abra issues públicas para vulnerabilidades de segurança. Envie um email privado para:

- **Email**: security@r-u-ok.dev (TBD)
- Inclua: descrição detalhada, passos para reproduzir, impacto estimado

### Contribuições

Adoramos contribuições! Veja a seção [Desenvolvimento](#-desenvolvimento) para começar.

### Comunidade

- 💬 **Discussões**: [GitHub Discussions](../../discussions) (TBD)
- 📧 **Email**: contato@r-u-ok.dev (TBD)
- 🐦 **Twitter**: @ruokapp (TBD)

---

## 🙏 Agradecimentos

- **Zhipu AI** pela API GLM-4
- **RStudio/Posit** pela plataforma Shiny
- **Tidyverse team** pelas excelentes bibliotecas R
- Comunidade open-source pela inspiração e ferramentas

---

## 📊 Status do Projeto

- **Última atualização**: 02 de Fevereiro de 2026
- **Versão**: 0.1.0-alpha (Protótipo)
- **Estágio**: Desenvolvimento ativo
- **Produção**: ❌ Não recomendado
- **Testes**: ✅ Cobertura básica
- **Documentação**: 🔄 Em progresso

---

<div align="center">

**Desenvolvido com ❤️ para democratizar análise de dados**

[⬆ Voltar ao topo](#r-u-ok-)

</div>

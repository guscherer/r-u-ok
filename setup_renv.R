# Script para Inicializar renv no Projeto R-U-OK
# Execute este script no RStudio ou R Console

cat("=== Inicializando renv para R-U-OK ===\n\n")

# PASSO 1: Instalar renv (se necessário)
cat("PASSO 1: Verificando instalação do renv...\n")
if (!requireNamespace("renv", quietly = TRUE)) {
  cat("Instalando renv...\n")
  install.packages("renv", repos = "https://cloud.r-project.org")
} else {
  cat("renv já está instalado (versão: ", as.character(packageVersion("renv")), ")\n")
}

# PASSO 2: Inicializar renv
cat("\nPASSO 2: Inicializando renv...\n")
cat("Isso criará:\n")
cat("  - renv.lock (lockfile com versões exatas dos pacotes)\n")
cat("  - .Rprofile (auto-ativa renv na inicialização)\n")
cat("  - renv/ (biblioteca privada de pacotes)\n")
cat("  - renv/activate.R (script de ativação)\n\n")

renv::init()

# PASSO 3: Snapshot do estado atual
cat("\nPASSO 3: Capturando snapshot das dependências...\n")
renv::snapshot()

# PASSO 4: Verificar setup
cat("\nPASSO 4: Verificando configuração...\n")

if (file.exists(".Rprofile")) {
  cat("✓ .Rprofile criado\n")
}

if (file.exists("renv.lock")) {
  cat("✓ renv.lock criado\n")
  
  # Ler e mostrar dependências capturadas
  lockfile <- jsonlite::read_json("renv.lock")
  packages <- names(lockfile$Packages)
  cat("\nDependências capturadas (", length(packages), " pacotes):\n")
  cat("  Principais:\n")
  main_packages <- c("shiny", "tidyverse", "DT", "httr2", "readxl", "writexl", "shinythemes")
  for (pkg in main_packages) {
    if (pkg %in% packages) {
      version <- lockfile$Packages[[pkg]]$Version
      cat("  - ", pkg, " (", version, ")\n", sep = "")
    }
  }
}

if (dir.exists("renv")) {
  cat("✓ renv/ directory criado\n")
  cat("  Estrutura:\n")
  renv_files <- list.files("renv", recursive = FALSE)
  for (f in renv_files) {
    cat("  - renv/", f, "\n", sep = "")
  }
}

cat("\n=== Inicialização do renv concluída! ===\n")
cat("\nPróximos passos:\n")
cat("1. O renv agora será ativado automaticamente quando você abrir o projeto\n")
cat("2. Use renv::install('pacote') para instalar novos pacotes\n")
cat("3. Use renv::snapshot() para atualizar renv.lock após mudanças\n")
cat("4. Use renv::restore() para restaurar pacotes de renv.lock\n")

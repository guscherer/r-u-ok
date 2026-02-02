#' Advanced ML Detection with TF-IDF Vectorization
#'
#' Extends ml_detection.R with text2vec-based TF-IDF features
#' for more sophisticated semantic analysis
#'
#' @docType package
#' @name ml_detection_advanced

# Verificar se text2vec está disponível
.has_text2vec <- function() {
  requireNamespace("text2vec", quietly = TRUE)
}

# ============================================================================
# 1. TF-IDF FEATURE EXTRACTION
# ============================================================================

#' Create TF-IDF Vectorizer
#'
#' Builds vocabulary and TF-IDF matrix from training corpus
#'
#' @param corpus character vector of training texts
#' @param max_features integer, max vocabulary size (default 100)
#' @param ngram_range integer vector, n-gram range (default c(1, 2))
#'
#' @return list with $vectorizer, $idf, $vocab
#'
#' @export
create_tfidf_vectorizer <- function(corpus, 
                                     max_features = 100,
                                     ngram_range = c(1, 2)) {
  
  if (!.has_text2vec()) {
    warning("text2vec not available. Install with: install.packages('text2vec')")
    return(NULL)
  }
  
  # Create iterator
  it <- text2vec::itoken(corpus, 
                        preprocessor = tolower,
                        tokenizer = text2vec::word_tokenizer,
                        progressbar = FALSE)
  
  # Create vocabulary
  vocab <- text2vec::create_vocabulary(it, 
                                       ngram = ngram_range,
                                       stopwords = text2vec::stopwords("en"))
  
  # Prune to max features
  vocab <- text2vec::prune_vocabulary(vocab, 
                                      term_count_min = 2,
                                      doc_proportion_max = 0.9,
                                      max_number_of_terms = max_features)
  
  # Create vectorizer
  vectorizer <- text2vec::vocab_vectorizer(vocab)
  
  # Create DTM (Document-Term Matrix)
  dtm <- text2vec::create_dtm(it, vectorizer)
  
  # Fit TF-IDF model
  tfidf_model <- text2vec::TfIdf$new()
  dtm_tfidf <- tfidf_model$fit_transform(dtm)
  
  list(
    vectorizer = vectorizer,
    tfidf_model = tfidf_model,
    vocab = vocab,
    dtm_sample = dtm_tfidf[1:min(5, nrow(dtm_tfidf)), ]
  )
}

#' Extract TF-IDF Features from Text
#'
#' @param text character, input text
#' @param tfidf_model list from create_tfidf_vectorizer()
#'
#' @return numeric vector of TF-IDF scores
#'
#' @export
extract_tfidf_features <- function(text, tfidf_model) {
  
  if (is.null(tfidf_model) || !.has_text2vec()) {
    return(numeric(0))
  }
  
  tryCatch({
    # Tokenize
    it <- text2vec::itoken(text, 
                          preprocessor = tolower,
                          tokenizer = text2vec::word_tokenizer,
                          progressbar = FALSE)
    
    # Create DTM
    dtm <- text2vec::create_dtm(it, tfidf_model$vectorizer)
    
    # Transform with TF-IDF
    dtm_tfidf <- tfidf_model$tfidf_model$transform(dtm)
    
    # Get dense vector
    as.numeric(dtm_tfidf[1, ])
  }, error = function(e) {
    numeric(0)
  })
}

# ============================================================================
# 2. COSINE SIMILARITY & ANOMALY DETECTION
# ============================================================================

#' Calculate Cosine Similarity
#'
#' @param vec1 numeric vector
#' @param vec2 numeric vector
#'
#' @return numeric, cosine similarity (0-1)
#'
#' @export
cosine_similarity <- function(vec1, vec2) {
  if (length(vec1) != length(vec2) || length(vec1) == 0) {
    return(0)
  }
  
  dot_product <- sum(vec1 * vec2)
  norm1 <- sqrt(sum(vec1^2))
  norm2 <- sqrt(sum(vec2^2))
  
  if (norm1 == 0 || norm2 == 0) {
    return(0)
  }
  
  dot_product / (norm1 * norm2)
}

#' Detect Anomalies Using TF-IDF
#'
#' Compares prompt against safe corpus using cosine similarity
#'
#' @param prompt character, user prompt
#' @param safe_corpus character vector, known safe prompts
#' @param tfidf_model list from create_tfidf_vectorizer()
#' @param threshold numeric, anomaly threshold (default 0.3)
#'
#' @return list with $is_anomaly, $similarity, $avg_similarity
#'
#' @export
detect_tfidf_anomaly <- function(prompt, 
                                 safe_corpus, 
                                 tfidf_model,
                                 threshold = 0.3) {
  
  if (is.null(tfidf_model)) {
    return(list(is_anomaly = FALSE, similarity = NA, avg_similarity = NA))
  }
  
  # Extract features for prompt
  prompt_features <- extract_tfidf_features(prompt, tfidf_model)
  
  if (length(prompt_features) == 0) {
    return(list(is_anomaly = FALSE, similarity = NA, avg_similarity = NA))
  }
  
  # Extract features for safe corpus
  safe_features_list <- lapply(safe_corpus, function(text) {
    extract_tfidf_features(text, tfidf_model)
  })
  
  # Calculate similarities
  similarities <- sapply(safe_features_list, function(safe_vec) {
    if (length(safe_vec) == length(prompt_features)) {
      cosine_similarity(prompt_features, safe_vec)
    } else {
      0
    }
  })
  
  avg_similarity <- mean(similarities, na.rm = TRUE)
  max_similarity <- max(similarities, na.rm = TRUE)
  
  # Low similarity = anomaly
  is_anomaly <- avg_similarity < threshold
  
  list(
    is_anomaly = is_anomaly,
    similarity = max_similarity,
    avg_similarity = avg_similarity,
    threshold = threshold
  )
}

# ============================================================================
# 3. ENHANCED PREDICTION WITH TF-IDF
# ============================================================================

#' Enhanced Injection Prediction with TF-IDF
#'
#' Combines rule-based scoring with TF-IDF anomaly detection
#'
#' @param prompt character, user prompt
#' @param tfidf_model list from create_tfidf_vectorizer() (optional)
#' @param safe_corpus character vector (optional)
#' @param base_threshold numeric, base risk score threshold (default 25)
#' @param tfidf_weight numeric, weight for TF-IDF anomaly (0-1, default 0.3)
#'
#' @return list with enhanced prediction including TF-IDF analysis
#'
#' @export
predict_injection_enhanced <- function(prompt,
                                       tfidf_model = NULL,
                                       safe_corpus = NULL,
                                       base_threshold = 25,
                                       tfidf_weight = 0.3) {
  
  # Get base prediction (from ml_detection.R)
  base_result <- predict_injection(prompt, threshold = base_threshold)
  
  # If text2vec available and model provided, add TF-IDF analysis
  if (!is.null(tfidf_model) && !is.null(safe_corpus) && .has_text2vec()) {
    
    tfidf_result <- detect_tfidf_anomaly(prompt, safe_corpus, tfidf_model)
    
    # Adjust score based on TF-IDF anomaly
    if (tfidf_result$is_anomaly) {
      # Add anomaly penalty
      anomaly_penalty <- (1 - tfidf_result$avg_similarity) * 30
      adjusted_score <- base_result$score + (anomaly_penalty * tfidf_weight)
      adjusted_score <- min(adjusted_score, 100)
    } else {
      adjusted_score <- base_result$score
    }
    
    # Re-evaluate with adjusted score
    is_injection <- adjusted_score >= base_threshold
    
    # Update risk level
    risk_level <- if (adjusted_score >= 50) {
      "high"
    } else if (adjusted_score >= 25) {
      "medium"
    } else if (adjusted_score >= 10) {
      "low"
    } else {
      "safe"
    }
    
    # Enhanced result
    list(
      is_injection = is_injection,
      score = adjusted_score,
      base_score = base_result$score,
      tfidf_adjustment = adjusted_score - base_result$score,
      risk_level = risk_level,
      confidence = base_result$confidence,
      triggered_features = base_result$triggered_features,
      tfidf_anomaly = tfidf_result$is_anomaly,
      tfidf_similarity = tfidf_result$avg_similarity,
      method = "enhanced_tfidf"
    )
    
  } else {
    # No TF-IDF available, return base result
    base_result$method <- "base_only"
    base_result
  }
}

# ============================================================================
# 4. PRE-TRAINED MODEL HELPERS
# ============================================================================

#' Get Default Safe Corpus
#'
#' Returns example safe prompts for training
#'
#' @return character vector of safe prompts
#'
#' @export
get_default_safe_corpus <- function() {
  c(
    "Show me the top 10 customers by revenue",
    "Calculate average sales per month",
    "Filter products where price is greater than 100",
    "Group sales by region and sum the total",
    "Join customers and orders tables by customer ID",
    "Show products sorted by name",
    "Count the number of orders per day",
    "Calculate the median order value",
    "Display unique product categories",
    "Aggregate revenue by quarter",
    "Find customers with more than 5 orders",
    "Show sales trend over time",
    "Calculate percentage change month over month",
    "List top selling products",
    "Show customer distribution by country",
    "Calculate correlation between price and sales",
    "Display summary statistics for revenue",
    "Filter orders from last 30 days",
    "Group by customer segment and calculate metrics",
    "Show year over year growth rate"
  )
}

#' Initialize TF-IDF Model (Lazy Loading)
#'
#' Creates and caches TF-IDF model for later use
#'
#' @param corpus character vector (optional, uses default if NULL)
#' @param cache_path character, path to save model (optional)
#'
#' @return TF-IDF model or NULL if text2vec not available
#'
#' @export
init_tfidf_model <- function(corpus = NULL, cache_path = NULL) {
  
  if (!.has_text2vec()) {
    message("text2vec not installed. TF-IDF features disabled.")
    message("Install with: install.packages('text2vec')")
    return(NULL)
  }
  
  if (is.null(corpus)) {
    corpus <- get_default_safe_corpus()
  }
  
  message("Creating TF-IDF model with ", length(corpus), " safe examples...")
  
  model <- create_tfidf_vectorizer(corpus, max_features = 50)
  
  if (!is.null(cache_path) && !is.null(model)) {
    saveRDS(model, cache_path)
    message("TF-IDF model saved to: ", cache_path)
  }
  
  message("TF-IDF model ready!")
  model
}

# Global variable for cached model
.tfidf_model_cache <- NULL

#' Get Cached TF-IDF Model
#'
#' @return cached model or NULL
#'
#' @export
get_tfidf_model <- function() {
  if (is.null(.tfidf_model_cache) && .has_text2vec()) {
    .tfidf_model_cache <<- init_tfidf_model()
  }
  .tfidf_model_cache
}

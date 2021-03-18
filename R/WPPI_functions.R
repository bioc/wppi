### PPI creation auxiliar functions

# Creation of igraph object from Omnipath dataset
graph_from_op <- function(op_data){
  edges <- op_data %>%
    dplyr::select(-c(source_genesymbol,target_genesymbol))
  node_source <- op_data %>%
    dplyr::select(source,source_genesymbol)
  node_target <- op_data %>%
    dplyr::select(target,target_genesymbol)
  names(node_source) <- c("UniProt_ID","Gene_Symbol")
  names(node_target) <- c("UniProt_ID","Gene_Symbol")
  nodes <- rbind(node_source,node_target) %>%
    distinct() 
  op_graph <- graph_from_data_frame(d = edges,
                                    vertices = nodes)
  return(op_graph)
}

# Check which genes are or not in Omnipath
isgene_omnipath <- function(graph_op,gene_set,exist_bol){
  idx_vertex_bool <- gene_set %in% vertex_attr(graph_op)$Gene_Symbol
  if(exist_bol)
    gene_set[idx_vertex_bool]
  else
    gene_set[!idx_vertex_bool]
}

# Subgraph from Omnipath graph object and genes of interest
subgraph_op <- function(graph_op,gene_set,sub_level){
  # sub_level indicates the neighbor-level of given genes
  idx_mapped <- which(vertex_attr(graph_op)$Gene_Symbol %in% gene_set)
  vertices_mapped <- V(graph_op)[idx_mapped]
  if(sub_level == 0){
    op_subgraph <- induced_subgraph(graph_op,vertices_mapped)
  }else{
    new_nodes <- unlist(ego(graph_op,order = sub_level,
                            nodes = idx_mapped,mode = "all",mindist = 0))
    op_subgraph <- induced_subgraph(graph_op,new_nodes)
  }
  return(op_subgraph)
}

# Convert network graph into adjacency matrix
graph_to_adjacency <- function(graph_op){
  adj_data <- as.matrix(as_adjacency_matrix(graph_op))
  return(adj_data)
}

# Shared neighbors between proteins
common_neighbors <- function(graph_op){
  adj_matrix <- as(get.adjacency(graph_op),"dgTMatrix")
  adj_matrix_table <- data.table(source = adj_matrix@i + 1,
                                 target = adj_matrix@j + 1)
  adj_matrix_table$neighbors <- apply(adj_matrix_table,1,
                                      function(x){
                                        paste(intersect(neighbors(graph_op,x[1]),
                                                        neighbors(graph_op,x[2])),
                                              collapse = ",")
                                      })
  table_neighbors <- adj_matrix_table[!adj_matrix_table$neighbors == "",]
  table_neighbors$nr_neighbors <- count.fields(textConnection(table_neighbors$neighbors),sep = ",")
  return(table_neighbors)
}

# Convert adjacency to weighted adjacency
weighted_adj <- function(graph_op,neighbors_data,GO_data,HPO_data,nr_GO,nr_HPO){
  adj_data <- as.matrix(graph_to_adjacency(graph_op))
  matrix_neighbors = matrix_GO = matrix_HPO <- 0*adj_data
  for (i in seq(nrow(neighbors_data))) {
    x <- neighbors_data[i,]
    matrix_neighbors[[x[[1]],x[[2]]]] <- x[[4]]
  }
  GO_data_agg <- aggregate_annot(GO_data,"GO")
  HPO_data_agg <- aggregate_annot(HPO_data,"HPO")
  genes_op <- vertex_attr(graph_op)$Gene_Symbol
  for (i in seq(nrow(matrix_GO))) {
    for (j in seq(ncol(matrix_GO))) {
      if(adj_data[i,j]==1){
        gene_i <- genes_op[i]
        gene_j <- genes_op[j]
        if(nr_GO!=0){matrix_GO[i,j] <- functional_annot(GO_data_agg,nr_GO,gene_i,gene_j)}
        if(nr_HPO!=0){matrix_HPO[i,j] <- functional_annot(HPO_data_agg,nr_HPO,gene_i,gene_j)}
      }
    }
  }
  weighted_matrix <- matrix_neighbors + matrix_GO + matrix_HPO
  # normalization by column
  norm_weighted_matrix <- sweep(weighted_matrix,2,colSums(weighted_matrix), FUN = "/")
  norm_weighted_matrix[is.nan(norm_weighted_matrix)] <- 0
  return(norm_weighted_matrix)
}

# Random Walk on weighted adjacency matrix
random_walk <- function(weighted_adj_matrix,restart_prob,threshold){
  if(missing(restart_prob)){ # restart probability 
    restart_prob = 0.4
  }
  if(missing(threshold)){ # threshold parameter 
    threshold = 10^(-6)
  }
  matrix_rw <- 0*weighted_adj_matrix
  nr_proteins <- ncol(matrix_rw)
  vector0 <- matrix(0,nr_proteins,1)
  vector_prob0 <- matrix(1/nr_proteins,nr_proteins,1)
  for (i in seq(nrow(matrix_rw))) {
    start_vector <- vector0
    start_vector[i] <- 1
    q_previous <- vector_prob0
    q_next <- (1-restart_prob)*(weighted_adj_matrix%*%q_previous) + restart_prob*start_vector
    while (any((q_next-q_previous)^2) > threshold) {
      q_previous <- q_next
      q_next <- (1-restart_prob)*(weighted_adj_matrix%*%q_previous) + restart_prob*start_vector
    }
    matrix_rw[i,] <- q_next
  }
  return(matrix_rw)
}

# Prioritization of genes based on probabilities 
prioritization_genes <- function(graph_op,prob_matrix,genes_interest,percentage_genes_ranked){
  if(missing(percentage_genes_ranked)){
    percentage_genes_ranked <- 100 # default is to return all 
  }
  genes_op <- vertex_attr(graph_op)$Gene_Symbol
  genes_bool <- (genes_op %in% genes_interest)
  # filter rows for all genes except the ones of interest, filter column with only genes of interest
  prob_matrix_reduced <- prob_matrix[!genes_bool,genes_bool]
  # get score for each row gene by summing all probabilities of the row
  genes_candidate <- genes_op[!genes_bool]
  proteins_candidate <- vertex_attr(graph_op)$name[!genes_bool]
  scores_candidates <- data.frame(scores = apply(prob_matrix_reduced,1,sum),
                                  gene = genes_candidate,
                                  protein = proteins_candidate)
  scores_candidates <- scores_candidates %>%
    arrange(desc(scores)) 
  final_scores_candidates <- scores_candidates[1:ceiling(nrow(scores_candidates)*percentage_genes_ranked/100),]
  return(final_scores_candidates)
}
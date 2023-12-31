#' Processing of ontology annotations
#'
#' Ontology databases such as Gene Ontology
#' (GO, \url{http://geneontology.org/}) and Human Phenotype Ontology
#' (HPO, \url{https://hpo.jax.org/app/}) provide important genome and disease
#' functional annotations of genes. These combined allow to build a
#' connection between proteins/genes and phenotype/disease. This function
#' aggregates information in the GO and HPO ontology datasets.
#'
#' @param data_annot Data frame (tibble) of GO or HPO datasets from
#'     \code{\link{wppi_data}}, \code{\link{wppi_go_data}} or 
#'     \code{\link{wppi_hpo_data}}.
#'
#' @return A list of four elements: 1) "term_size" a list which serves as a
#'     lookup table for size (number of genes) for each ontology term; 2) 
#'     "gene_term" a list to look up terms by gene symbol; 3) "annot" the 
#'     original data frame (\code{data_annot}); 4) "total_genes" the number of 
#'     genes annotated in the ontology dataset.
#'
#' @examples
#' hpo_raw <- wppi_hpo_data()
#' hpo <- process_annot(hpo_raw)
#'
#' @importFrom magrittr %>%
#' @importFrom dplyr group_by count summarize
#' @importFrom logger log_fatal log_info
#' @export
#' @seealso \itemize{
#'     \item{\code{\link{wppi_data}}}
#'     \item{\code{\link{wppi_go_data}}}
#'     \item{\code{\link{wppi_hpo_data}}}
#' }
process_annot <- function(data_annot) {

    # NSE vs. R CMD check workaround
    ID <- Gene_Symbol <- NULL

    if(
        !'ID' %in% names(data_annot) ||
        !'Gene_Symbol' %in% names(data_annot)
    ){
        msg <- 'Annotations must have ID and Gene_Symbol columns.'
        log_fatal(msg)
        stop(msg)
    }

    log_info(
        'Preprocessing annotations (%s).',
        which_ontology_database(data_annot)
    )

    list(
        term_size =
            data_annot %>%
            count(ID) %>%
            {`names<-`(as.list(.$n), .$ID)},
        gene_term =
            data_annot %>%
            group_by(Gene_Symbol) %>%
            summarize(terms = list(ID)) %>%
            {`names<-`(as.list(.$terms), .$Gene_Symbol)},
        annot = data_annot,
        total_genes = count_genes(data_annot)
    )

}


#' For an ontology annotation table tells the name of the ontology database
#'
#' @param db Ontology annotation table. Must have a column called `ID`.
#' @param long Logical: return the full name or the abbreviation.
#'
#' @return Character: the name of the ontology database. "Unknown" if the
#'     database is not GO neither HPO.
#'
#' @importFrom dplyr case_when
#' @noRd
which_ontology_database <- function(db, long = TRUE){

    x <- substr(db$ID[1], 1, 2)
    case_when(
        x == 'GO' &  long ~ 'Gene Ontology',
        x == 'GO' & !long ~ 'GO',
        x == 'HP' &  long ~ 'Human Phenotype Ontology',
        x == 'HP' & !long ~ 'HPO',
        TRUE              ~ 'Unknown'
    )

}


#' A summary message with key numbers about an annotation database
#'
#' @param db A preprocessed annotation database as produced by
#'     \code{\link{process_annot}}.
#'
#' @noRd
annot_summary_msg <- function(db){

    sprintf(
        '%s: %d terms, %d genes, %d annotations',
        which_ontology_database(db$annot, long = FALSE),
        length(db$term_size),
        db$total_genes,
        nrow(db$annot)
    )

}


#' Number of total genes in an ontology database
#'
#' @param data_annot Data frame (tibble) of GO or HPO datasets from
#'     \code{\link{wppi_go_data}} or \code{\link{wppi_hpo_data}}.
#'
#' @return Number of total unique genes in each ontology database.
#'
#' @examples
#' go <- wppi_go_data()
#' count_genes(go)
#' # [1] 19712
#'
#' @importFrom magrittr %>%
#' @importFrom dplyr pull n_distinct
#' @export
#' @seealso \itemize{
#'     \item{\code{\link{wppi_go_data}}}
#'     \item{\code{\link{wppi_hpo_data}}}
#' }
count_genes <- function(data_annot) {

    # NSE vs. R CMD check workaround
    Gene_Symbol <- NULL

    data_annot %>%
    pull(Gene_Symbol) %>%
    n_distinct

}


#' Filter ontology datasets using PPI network object
#'
#' @param data_annot Data frame (tibble) of GO or HPO datasets from
#'     \code{\link{wppi_go_data}} or \code{\link{wppi_hpo_data}}.
#' @param graph_op Igraph graph object obtained from built OmniPath PPI of
#'     genes of interest and x-degree neighbors.
#'
#' @return Data frame (tibble) of GO or HPO datasets filtered based on
#'     proteins available in the igraph object.
#'
#' @examples
#' # Get GO database
#' GO_data <- wppi_go_data()
#' # Create igraph object based on genes of interest and first neighbors
#' genes_interest <-
#'     c("ERCC8", "AKT3", "NOL3", "GFI1B", "CDC25A", "TPX2", "SHE")
#' graph_op <- graph_from_op(wppi_omnipath_data())
#' graph_op_1 <- subgraph_op(graph_op, genes_interest, 1)
#' # Filter GO data
#' GO_data_filtered <- filter_annot_with_network(GO_data, graph_op_1)
#'
#' @importFrom igraph vertex_attr
#' @importFrom magrittr %>%
#' @importFrom dplyr filter distinct
#' @export
#' @seealso \itemize{
#'     \item{\code{\link{wppi_go_data}}}
#'     \item{\code{\link{wppi_hpo_data}}}
#'     \item{\code{\link{graph_from_op}}}
#' }
filter_annot_with_network <- function(data_annot, graph_op) {

    # NSE vs. R CMD check workaround
    Gene_Symbol <- NULL

    genes_op <- vertex_attr(graph_op)$Gene_Symbol

    data_annot %>%
    filter(Gene_Symbol %in% genes_op) %>%
    # should not be necessary
    # gene-annotation pairs are supposed to be unique
    distinct()

}


#' Functional similarity score based on ontology
#'
#' Functional similarity between two genes in ontology databases (GO or HPO).
#' Each pair of interacting proteins in the PPI graph network, is
#' quantified the shared annotations between them using the Fisher's combined
#' probability test (\url{https://doi.org/10.1007/978-1-4612-4380-9_6}). This
#' is based on the number of genes annotated in each shared ontology term and
#' the total amount of unique genes available in the ontology database.
#'
#' @param annot Processed annotation data as provided by
#'     \code{\link{process_annot}}.
#' @param gene_i String with the gene symbol in the row of the adjacency
#'     matrix.
#' @param gene_j String with the gene symbol in the column of the adjacency
#'     matrix.
#'
#' @return Numeric value with GO/HPO functional similarity between given
#'     pair of proteins.
#'
#' @examples
#' hpo <- wppi_hpo_data()
#' hpo <- process_annot(hpo)
#' hpo_score <- functional_annot(hpo, 'AKT1', 'MTOR')
#' # [1] 106.9376
#'
#' @export
#' @seealso \itemize{
#'     \item{\code{\link{process_annot}}}
#'     \item{\code{\link{weighted_adj}}}
#' }
functional_annot <- function(annot, gene_i, gene_j) {

    if (
        !gene_i %in% names(annot$gene_term) ||
        !gene_j %in% names(annot$gene_term)
    ){
        return(0)
    }

    shared_terms <- intersect(
        annot$gene_term[[gene_i]],
        annot$gene_term[[gene_j]]
    )

    `if`(
        length(shared_terms) == 0L,
        0,
        sum(-2 * log(
            unlist(annot$term_size[shared_terms]) /
            annot$total_genes
        ))
    )

}
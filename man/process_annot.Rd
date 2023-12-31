% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/Annot_functions.R
\name{process_annot}
\alias{process_annot}
\title{Processing of ontology annotations}
\usage{
process_annot(data_annot)
}
\arguments{
\item{data_annot}{Data frame (tibble) of GO or HPO datasets from
\code{\link{wppi_data}}, \code{\link{wppi_go_data}} or 
\code{\link{wppi_hpo_data}}.}
}
\value{
A list of four elements: 1) "term_size" a list which serves as a
    lookup table for size (number of genes) for each ontology term; 2) 
    "gene_term" a list to look up terms by gene symbol; 3) "annot" the 
    original data frame (\code{data_annot}); 4) "total_genes" the number of 
    genes annotated in the ontology dataset.
}
\description{
Ontology databases such as Gene Ontology
(GO, \url{http://geneontology.org/}) and Human Phenotype Ontology
(HPO, \url{https://hpo.jax.org/app/}) provide important genome and disease
functional annotations of genes. These combined allow to build a
connection between proteins/genes and phenotype/disease. This function
aggregates information in the GO and HPO ontology datasets.
}
\examples{
hpo_raw <- wppi_hpo_data()
hpo <- process_annot(hpo_raw)

}
\seealso{
\itemize{
    \item{\code{\link{wppi_data}}}
    \item{\code{\link{wppi_go_data}}}
    \item{\code{\link{wppi_hpo_data}}}
}
}

#' Compile data for WPPI
#'
#' This I will largely rewrite, for now it's fine as it is, I just wanted to
#' have the docstring for roxygen.
#'
#' @importFrom dplyr select distinct mutate filter
#' @importFrom magrittr %>%
#' @importFrom OmnipathR import_post_translational_interactions all_uniprots
#' @importFrom data.table fread
#' @export
#'
#' @return Returns `NULL`.
wppi_data <- function(){
    ### Data
    # note: links updated on Feb 23 2021

    # HPO
    HPO.link <- "https://ci.monarchinitiative.org/view/hpo/job/hpo.annotations/lastSuccessfulBuild/artifact/rare-diseases/util/annotation/genes_to_phenotype.txt"

    # GO
    GO.link <- "http://geneontology.org/gene-associations/goa_human.gaf.gz"

    # Omnipath
    Omnipath.link <- "https://archive.omnipathdb.org/omnipath_webservice_annotations__recent.tsv"

    ### Create directories
    dir.create(file.path(getwd(), "WPPI_Data"), showWarnings = TRUE)
    dir.create(file.path(getwd(), "WPPI_Plots"), showWarnings = TRUE)

    ### Read and save data
    # HPO
    HPO.raw <- data.table::fread(HPO.link)
    names(HPO.raw) <- c("Gene_ID","Gene_Symbol","HPO_ID","HPO_Name","Frequency_raw",
                        "Frequency_HPO","Add_info","GD_source","DiseaseID_link")
    HPO.data <- HPO.raw %>%
    dplyr::select(Gene_ID,Gene_Symbol,HPO_ID,HPO_Name) %>% distinct()
    save(HPO.raw, file = "WPPI_Data/HPO_raw.RData")
    save(HPO.data, file = "WPPI_Data/HPO_data.RData")
    # GO
    GO.raw <- data.table::fread(GO.link)
    GO.data <- GO.raw[,c(3,5,9)] %>% distinct()
    names(GO.data) <- c("Gene_Symbol","GO_ID","Type_GO")
    save(GO.raw, file = "WPPI_Data/GO_raw.RData")
    save(GO.data, file = "WPPI_Data/GO_data.RData")
    # UniProt
    Uniprot.raw <- OmnipathR::all_uniprots(
        fields = c(
            'id', 'entry name', 'reviewed', 'protein names',
            'genes', 'organism', 'length'
        )
    )
    UniProt.data <- Uniprot.raw %>% dplyr::mutate(UniProt_ID = Entry) %>%
    dplyr::select(UniProt_ID) %>% dplyr::distinct()
    save(Uniprot.raw, file = "WPPI_Data/UniProt_raw.RData")
    save(UniProt.data, file = "WPPI_Data/UniProt_data.RData")
    # Omnipath
    # Omnipath.raw <- data.table::fread(Omnipath.link)
    Omnipath.raw <- OmnipathR::import_post_translational_interactions(
        entity_type = 'protein'
    )
    # I don't see why we need distinct here
    # but still, would be better to state the column names explicitely
    # e.g. distinct(across(c('source', 'target', 'is_directed')))
    Omnipath.data <- Omnipath.raw[,1:10] %>% distinct()

    # this shouldn't be necessary
    Omnipath.human.data <- Omnipath.data %>%
    filter(
        source %in% UniProt.data$UniProt_ID &
        target %in% UniProt.data$UniProt_ID
        )

    save(Omnipath.raw, file = "WPPI_Data/Omnipath_raw.RData")
    save(Omnipath.data, file = "WPPI_Data/Omnipath_data.RData")
    save(Omnipath.human.data, file = "WPPI_Data/Omnipath_human_data.RData")

}
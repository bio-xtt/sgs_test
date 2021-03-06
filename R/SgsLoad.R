require(tidyverse)
require(feather)
require(httr)
require(jsonlite)
require(methods)
require(readr)
require(Seurat)
require(Signac)
require(uuid)
require(Rcpp)




#' @title Deal large matrix
#' @param mat a big dgMatrix
#' @importFrom Rcpp sourceCpp
#' @return Return a matrix
#' @examples
#' \dontrun{
#' counts <- as_Matrix(counts)
#' }
#'
#'
as_Matrix <- function(mat) {
  row_pos <- mat@i
  col_pos <- findInterval(seq(mat@x) - 1, mat@p[-1])
  tmp <- asMatrix(rp = row_pos, cp = col_pos, z = mat@x, nrows = mat@Dim[1], ncols = mat@Dim[2])
  row.names(tmp) <- mat@Dimnames[[1]]
  colnames(tmp) <- mat@Dimnames[[2]]
  return(tmp)
}






#' This function used to gain the need file of sgs
#' @param object seurat object used to load
#' @param assays a vector of assay names to export: c("RNA","ATAC","motif")
#' @param matrix.slot a list of matrix data to export: list("RNA"="data", "ATAC"="counts"; "motif"="data")
#' @param assay.type a list of matrix type, mainly:"peak", "motif", "gene".list("RNA"="gene", "ATAC"="peak"; "motif"="motif")
#' @param select_group a vector of cell group name to export
#' @param reductions a vector of reduction name to export
#' @param marker.files a list of marker file path to export.list("RNA"="xxx.rna.tsv", "ATAC"="xxx.peak.tsv"; "motif"="xxx.motif.tsv")
#' @importFrom Seurat Project Idents GetAssayData Embeddings FetchData DefaultAssay FindAllMarkers GetAssay
#' @importFrom Signac GetMotifData Links SplitFragments Fragments
#' @importFrom methods .hasSlot is
#' @importFrom stats ave
#' @importFrom utils install.packages packageVersion
#' @importFrom readr write_tsv
#' @importFrom feather write_feather
#' @return a list of information for single cell data load
#' @examples
#' \dontrun{
#' data("atac")
#' gain_signac(
#'   object = atac,
#'   assays = c("RNA", "chromvar", "peaks"),
#'   matrix.slot = list("RNA" = "data", "chromvar" = "data", "peaks" = "data"),
#'   assay.type = list("RNA" = "gene", "chromvar" = "motif", "peaks" = "peak"),
#'   select_group = c("seurat_clusters"),
#'   reductions = c("lsi", "umap"),
#'   marker.files = list("RNA" = "marker_gene.tsv", "chromvar" = "marker_motif.tsv", "peaks" = "marker_peak.tsv")
#' )
#' }
#'



gain_signac <- function(object,
                        assays,
                        matrix.slot,
                        assay.type,
                        select_group,
                        reductions = NULL,
                        marker.files = NULL
) {

  ## look for seurat and check the version of object is the same as the version of the package
  if (!requireNamespace("Seurat", quietly = TRUE)) {
    stop("This script requires that Seurat (V2 or V3) is installed")
  }

  message("Seurat Version installed: ", packageVersion("Seurat"))
  message("Object was created with Seurat version ", object@version)

  objMaj <- package_version(object@version)$major
  # pkgMaj <- package_version(packageVersion("Seurat"))$major


  if (objMaj != 2 && objMaj != 3 && objMaj != 4) {
    stop("can only process Seurat2, Seurat3  or Seurat4 objects, object was made with Seurat ", object@version)
  }



  ## post inform list
  post_list <- c()



  #### make the output dir
  # the dir used for post
  if (!requireNamespace("uuid")) install.packages("uuid")
  sc_id <- uuid::UUIDgenerate()
  message("the single cell id is:", sc_id)

  if (!dir.exists("/home/sgs/data/rstudio_id")) {
    dir.create("/home/sgs/data/rstudio_id")
  }

  # ##add sc_id
  post_list$sc_id <- sc_id

  ## set the sc track dir
  dir_path <- paste0("/home/sgs/data/rstudio_id/", sc_id)
  if (!dir.exists(paths = dir_path)) {
    dir.create(path = dir_path)
  }
  if (!dir.exists(paths = dir_path)) {
    stop("Output directory ", dir_path, " cannot be created or is a file")
  } else {
    message("the output dir is:", dir_path)
  }


  ## the debug dir: "./signac_study/pbmc_5k/test1"
  #"/home/sgs/signac_study/pbmc_500/new_test2"
  # dir_path <- "./seurat_demo/pbmc3k/test_2022"
  # if (!dir.exists(dir_path)) {
  #   dir.create(path = dir_path)
  #   message("the output dir is:", dir_path)
  # } else {
  #   message("the output dir is:", dir_path)
  # }



  ############# gain the data from seurat
  #### gain the metadata
  metadata <- object[[]]

  # add meta column inform
  all_meta_column <- colnames(metadata)
  ###this has changed 2022.3.1
  ##old
  # post_list$all_meta_columns <- all_meta_column
  if (length(all_meta_column) > 1) {
    post_list$all_meta_columns <- all_meta_column
  }else{
    post_list$all_meta_columns <- list(all_meta_column)
  }


  ## gain the merge file
  meta_file <- data.frame(cell = rownames(metadata), metadata, check.rows = FALSE)
  rownames(meta_file) <- NULL
  meta_file <- as.data.frame(lapply(meta_file, as.character) )
  merged_file <- meta_file

  # merged_file <- cbind(cell = rownames(metadata), metadata)
  # rownames(merged_file) <- NULL
  # merged_file <- as.data.frame(lapply(merged_file, as.character))




  #### Export cell embeddings/reductions for merge
  # Export cell embeddings/reductions
  dr <- object@`reductions`
  reducNames <- reductions
  if (is.null(reducNames)) {
    reducNames <- names(dr)
    message("Using all embeddings contained in the Seurat object: ", reducNames)
  }

  ## add cell plots type
  ##this changed 2022.3.1
  ##old
  # post_list$cell_plots <- reducNames
  ##new
  if (length(reducNames) > 1) {
    post_list$cell_plots <- reducNames
  }else{
    post_list$cell_plots <- list(reducNames)
  }

  for (embedding in reducNames) {
    emb <- dr[[embedding]]
    if (is.null(x = emb)) {
      message("Embedding ", embedding, " does not exist in Seurat object. Skipping. ")
      next
    }
    df <- emb@`cell.embeddings`
    if (ncol(x = df) > 2) {
      warning("Embedding ", embedding, " has more than 2 coordinates, taking only the first 2")
      df <- df[  ,1:2]
    }
    colnames(x = df) <- c(sprintf("%s_x", embedding), sprintf("%s_y", embedding))
    # df <- cbind(cell = rownames(df), df)
    df <- data.frame(cell=rownames(x = df), df, check.names = FALSE)
    rownames(df) <- NULL

    # ##########merged into metadata merged file
    merged_file <- merge(merged_file, df, by = "cell")
  }



  ########### Export expression matrix
  # the assays is a list of the and assays
  if (!is.null(assays)) {
    exp_path <- c()
    for (i in assays) {
      assay <- i
      counts <- GetAssayData(object = object, assay = assay, slot = matrix.slot[i][[1]])

      ## judge wether the data is larger data
      if ((((ncol(counts) / 1000) * (nrow(counts) / 1000)) > 2000) && is(counts, "dgCMatrix")) {
        counts <- as_Matrix(counts)
      } else {
        counts <- counts
        counts <- as.matrix(counts)
      }

      ### to merge the exp file into total file
      counts_t <- as.data.frame(t(counts))
      ## translate the gene name into lower
      colnames(counts_t) <- tolower(colnames(counts_t))
      exp_df_t <- cbind(cell = rownames(counts_t), counts_t)

      ###add 2022.2.25
      un_fname <- unique(colnames(exp_df_t))
      exp_df_t <- exp_df_t[  ,un_fname]
      feature_names <- un_fname[-1]

      rownames(exp_df_t) <- NULL

      all_file <- merged_file
      all_file <- merge(exp_df_t, all_file, by = "cell", all = T)

      ###unique the dataframe
      # un_name <- unique(colnames(all_file))
      # all_file <- all_file[ ,un_name]

      ## make the file name
      feaher_path <- file.path(
        dir_path,
        sprintf("%s_exp.feather", i)
      )

      # feather::write_feather(merged_file, feaher_path )
      feather::write_feather(all_file, feaher_path)


      #### judge wether the marker file is existed
      if (!is.null(marker.files) && !is.null(marker.files[i][[1]])) {
        marker <- marker.files[i][[1]]
        if (file.exists(marker)) {
          marker_path <- file.path(dir_path, basename(marker))
          file.copy(marker, marker_path)
        } else {
          stop("the file path %s is not exists", marker)
        }
      } else {
        message("you dont give the marker file path, we suggests you offer one")
        marker_path <- "null"
      }


      ## to gain the different exp json inform file according to the type of matrix
      new_feather_path <- gsub("/home/sgs/data", "", feaher_path)
      new_marker_path <- gsub("/home/sgs/data", "", marker_path)
      exp_info <- list("matrix" = new_feather_path, "feature_names" = feature_names, "marker" = new_marker_path)
      all_exp_info <- exp_info

      if (assay.type[i][[1]] == "gene") {
        all_exp_info$matrix_type <- "gene"
      } else if (assay.type[i][[1]] == "motif") {
        all_exp_info$matrix_type <- "motif"

        if (!is.null(marker.files[i][[1]]) && length(GetMotifData(object = object, slot = "pwm")) > 0) {

          # DefaultAssay(object = object) <- main.assay
          pwm_data <- GetMotifData(object = object, slot = "pwm")
          motif_name <- GetMotifData(object = object, slot = "motif.names")
          new_pwm_name <- as.vector(paste(names(pwm_data), motif_name, sep = "_"))
          names(pwm_data) <- new_pwm_name
          pwm_json <- jsonlite::toJSON(pwm_data, auto_unbox = TRUE)
          ## make the pwm data file name contain the marker file, like this: "marker_motif.tsv_pwm.json"
          pwm_file_path <- file.path(dir_path, sprintf("%s_pfm.json", i))

          ## write the data in json format
          cat(pwm_json, file = (con <- file(pwm_file_path, "w", encoding = "UTF-8")))
          close(con)

          ## add tne related information
          new_pfm_path <- gsub("/home/sgs/data", "", pwm_file_path)
          all_exp_info$motif_pfm <- new_pfm_path

        } else {
          message("not offer the marker motif or no pwm data in the object")
          all_exp_info$motif_pfm <- "null"
        }
      } else if (assay.type[i][[1]] == "peak") {
        all_exp_info$matrix_type <- "peak"
        # DefaultAssay(object = object) <- main.assay

        ### gain the coaccss data
        if (length(Links(object = object)) > 0) {
          co_data <- as.data.frame(Links(object = object))
          co_file_path <- file.path(dir_path, sprintf("%s_coaccss.tsv", i))
          # co_file_path <- file.path(dir_path,"coaccss_score.tsv")
          write_tsv(co_data, file = co_file_path)
          new_coacc_path <-  gsub("/home/sgs/data", "", co_file_path)
          all_exp_info$co_access <- new_coacc_path
        } else {
          all_exp_info$co_access <- "null"
        }

        #### gain the the coverge bed files
        if (length(Fragments(object[[i]])) > 0) {
          split_list <- list()

          sp_path <- file.path(dir_path, sprintf("%s", i))

          if (!dir.exists(sp_path)) {
            dir.create(sp_path)
          }

          for (g in select_group) {
            ### this has been changed by xtt

            split_path <- file.path(sp_path, sprintf("%s/", g))
            message("Split the fragment file in to %s :", split_path)

            # create the out dir if the dir is not exists
            if (!dir.create(split_path)) {
              dir.create(split_path)
            }

            SplitFragments(
              object = object,
              assay = i,
              group.by = g,
              outdir = split_path)

            # split_files <- paste(split_path, list.files(split_path))
            # s_path <- list(split_files)
            new_split_path <- gsub("/home/sgs/data", "", split_path)
            s_path <- list(new_split_path)
            names(s_path) <- as.character(g)
            split_list <- append(split_list, s_path)
          }

          all_exp_info$fragment <- split_list
        }
      } else {
        stop("we only support gene / peak / motif type of matrix")
      }


      ### write the expression matrix information into json file
      json_path <- file.path(
        dir_path,
        sprintf("%s.json", i)
      )

      cc_json <- jsonlite::toJSON(all_exp_info, auto_unbox = TRUE)
      cat(cc_json, file = (con <- file(json_path, "w", encoding = "UTF-8")))
      close(con)

      ### add the expression information into post list
      js_path <- list(json_path)
      names(js_path) <- as.character(i)
      exp_path <- append(exp_path, js_path)
    }


    ### add the exp file and marker file list into path list
    post_list <- append(post_list, list("feature_matrix" = exp_path))
  } else {
    stop("please offer the name of the assay to export")
  }

  return(list(post_list, dir_path ))
}









#' Export the seurat object into SGS
#'
#' @param object seurat object used to load
#' @param species_id the id of the species
#' @param track_name the name of the track
#' @param track_type type of the track,mainly:"sc_RNA"; "sc_ATAC"
#' @param select_group a vector of cell group name to export
#' @param assays a vector of assay names to export: c("RNA","ATAC","motif")
#' @param matrix.slot a list of matrix data to export: list("RNA"="data", "ATAC"="counts"; "motif"="data")
#' @param assay.type a list of matrix type, mainly:"peak", "motif", "gene".list("RNA"="gene", "ATAC"="peak"; "motif"="motif")
#' @param reductions a vector of reduction names to export
#' @param marker.files a list of marker file path to export.list("RNA"="xxx.rna.tsv", "ATAC"="xxx.peak.tsv"; "motif"="xxx.motif.tsv")
#' @importFrom Seurat Project Idents GetAssayData Embeddings FetchData DefaultAssay FindAllMarkers GetAssay
#' @importFrom Signac GetMotifData Links SplitFragments Fragments
#' @importFrom methods .hasSlot is
#' @importFrom stats ave
#' @importFrom utils install.packages packageVersion
#' @importFrom readr write_tsv
#' @importFrom feather write_feather
#' @importFrom httr POST add_headers
#' @importFrom uuid UUIDgenerate
#' @importFrom jsonlite write_json toJSON
#' @author xtt
#' @return a post information in json in format
#' @export
#' @useDynLib sgsload
#'
#' @examples
#' \dontrun{
#' #### Loadding the scRNA-seq object into SGS
#' library(Signac)
#' data("pbmc_small")
#' marker_file <- system.file("extdata/scRNA", "markers.tsv", package = "sgsload")
#'
#' result_json <- ExportSC(
#'   object = pbmc_small,
#'   species_id = "678d0bb42ebd4137b031ec5cc90dc0c5",
#'   track_name = "pbmc_small",
#'   track_type = "scRNA",
#'   select_group = c("groups", "RNA_snn_res.0.8", "letter.idents", "cluster"),
#'   assays = c("RNA"),
#'   matrix.slot = list("RNA" = "data"),
#'   assay.type = list("RNA" = "gene"),
#'   reductions = c("tsne", "umap"),
#'   marker.files = list("RNA" = marker_file)
#' )
#'
#'
#' #### Loadding the scATAC-seq object into SGS
#' data("atac")
#' marker_genes <- system.file("extdata/scATAC", "marker_genes.tsv", package = "sgsload")
#' marker_motifs <- system.file("extdata/scATAC", "marker_motif.tsv", package = "sgsload")
#' marker_peaks <- system.file("extdata/scATAC", "marker_peaks.tsv", package = "sgsload")
#' markers <- list(marker_genes, marker_motifs, marker_peaks)
#' names(markers) <- c("RNA", "chromvar", "peaks")
#'
#' # change the fragment path
#' new.path <- system.file("extdata/scATAC", "fragments.tsv.gz", package = "sgsload")
#' fragments <- CreateFragmentObject(
#'   path = new.path,
#'   cells = colnames(atac),
#'   validate.fragments = TRUE
#' )
#' Fragments(atac) <- NULL
#' Fragments(atac) <- fragments
#'
#'
#' result_json <- ExportSC(
#'   object = atac,
#'   species_id = "678d0bb42ebd4137b031ec5cc90dc0c5",
#'   track_name = "atac",
#'   track_type = "scATAC",
#'   select_group = c("seurat_clusters"),
#'   assays = c("RNA", "chromvar", "peaks"),
#'   matrix.slot = list("RNA" = "data", "chromvar" = "data", "peaks" = "data"),
#'   assay.type = list("RNA" = "gene", "chromvar" = "motif", "peaks" = "peak"),
#'   reductions = c("lsi", "umap"),
#'   marker.files = markers
#' )
#' }
#'
ExportSC <- function(object,
                     species_id,
                     track_name,
                     track_type,
                     select_group,
                     assays,
                     matrix.slot,
                     assay.type,
                     reductions = NULL,
                     marker.files = NULL) {
  result <- gain_signac(
    object = object,
    assays = assays,
    matrix.slot = matrix.slot,
    assay.type = assay.type,
    select_group = select_group,
    reductions = reductions,
    marker.files = marker.files
  )

  post_list <- result[[1]]

  ##########this has changed 2022.3.1
  ##old
  # post_list$select_meta_columns <- select_group

  ##new
  if (length(select_group) > 1) {
    post_list$select_meta_columns <- select_group

  }else{
    post_list$select_meta_columns <- list(select_group)
  }

  post_list$species_id <- species_id
  post_list$sc_name <- track_name


  #### send the post
  header <- c(
    "Content-Type" = "application/json",
    "Accept" = "application/json, text/javascript, */*; q=0.01",
    "Accept-Encoding" = "gzip, deflate, br",
    "Connection" = "keep-alive"
  )

  # ####gain post url
  if(track_type == "scRNA"){
    post_list$sc_type <- "transcript"
    post_url <- "http://orthovenn2.bioinfotoolkits.net:6102/api/sc/add/seurat"
    # post_url <- "http://47.74.241.105:6102/api/sc/add/seurat"

  }else if(track_type == "scATAC"){
    post_list$sc_type <- "atac"
    post_url <- "http://orthovenn2.bioinfotoolkits.net:6102/api/sc/add/signac"
  }

  post_json <- jsonlite::toJSON(post_list, auto_unbox = TRUE, pretty = TRUE)
  post_body <- gsub("/home/sgs/data", "", post_json)

  ###post send
  post_result <- httr::POST(url = post_url, body = post_body, encode = "json", add_headers(.headers = header))
  post_status <- httr::status_code(post_result)

  post_content <- httr::content(post_result)

  if (post_status == "200") {
    message("the single cell track load successful!")
  } else {

    #delete the dir
    data_dir <- result[[2]]

    if(dir.exists(data_dir)){
      unlink(data_dir, recursive = TRUE)
    }
    stop("the single cell track add failed")
    message("post failed")
  }

  return(post_body)
  # return(list(post_content, post_body))
}

% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/SgsLoad.R
\name{gain_signac}
\alias{gain_signac}
\title{This function used to gain the need file of sgs}
\usage{
gain_signac(
  object,
  assays,
  matrix.slot,
  assay.type,
  select_group,
  reductions = NULL,
  marker.files = NULL
  marker.files = NULL,
  out_dir
)
}
\arguments{
\item{object}{seurat object used to load}

\item{assays}{a vector of assay names to export: c("RNA","ATAC","motif")}

\item{matrix.slot}{a list of matrix data to export: list("RNA"="data", "ATAC"="counts"; "motif"="data")}

\item{assay.type}{a list of matrix type, mainly:"peak", "motif", "gene".list("RNA"="gene", "ATAC"="peak"; "motif"="motif")}

\item{select_group}{a vector of cell group name to export}

\item{reductions}{a vector of reduction name to export}

\item{marker.files}{a list of marker file path to export.list("RNA"="xxx.rna.tsv", "ATAC"="xxx.peak.tsv"; "motif"="xxx.motif.tsv")}


\item{out_dir}{the output dir}
}
\value{
a list of information for single cell data load
}
\description{
This function used to gain the need file of sgs
}
\examples{
\dontrun{
data("atac")
gain_signac(
  object = atac,
  assays = c("RNA", "chromvar", "peaks"),
  matrix.slot = list("RNA" = "data", "chromvar" = "data", "peaks" = "data"),
  assay.type = list("RNA" = "gene", "chromvar" = "motif", "peaks" = "peak"),
  select_group = c("seurat_clusters"),
  reductions = c("lsi", "umap"),
  marker.files = list("RNA" = "marker_gene.tsv", "chromvar" = "marker_motif.tsv", "peaks" = "marker_peak.tsv")
  marker.files = list("RNA" = "marker_gene.tsv", "chromvar" = "marker_motif.tsv", "peaks" = "marker_peak.tsv"),
  out_dir = "xxx/out/")
}

}

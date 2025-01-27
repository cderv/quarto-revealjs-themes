# Paths variables 
quarto_web_demo_folder <- "_revealjs-demo-template/quarto-web-demo"
demo_path <- 'docs/presentations/revealjs/demo'

# Update Demo files from quarto web -------------------------------------------------------
# Only to do when we want to check for example update

tempdir <- tempfile("demo-download")
fs::dir_create(tempdir)
quarto_web <- "https://github.com/quarto-dev/quarto-web/archive/refs/heads/main.zip"
zipfile <- fs::path(tempdir, "quarto-web.zip")
xfun::download_file(quarto_web, output = fs::path(tempdir, "quarto-web.zip"), mode = "wb")
files <- zip::zip_list(zipfile) |> dplyr::as_tibble()
main_folder <- files$filename[1]
demo_path_unzipped <- fs::path(main_folder, demo_path)
demo_files <- files |> dplyr::filter(startsWith(filename, demo_path_unzipped)) |> dplyr::pull(filename)
zip::unzip(zipfile, files = demo_files, exdir = tempdir)


fs::dir_delete(quarto_web_demo_folder)
fs::dir_copy(fs::path(tempdir, demo_path_unzipped), quarto_web_demo_folder, overwrite = TRUE)
# remove pdf file
fs::file_delete(fs::path(quarto_web_demo_folder, "demo.pdf"))
fs::dir_delete(tempdir)

# Set metadata
if (any(grepl("{{< meta prerelease-subdomain >}}", xfun::read_utf8(fs::path(quarto_web_demo_folder, "index.qmd")), fixed = TRUE))) {
  yaml::write_yaml(
    list(
      "prerelease-subdomain" = ""
    ),
    file = "_metadata.yml")
}

# get themes files
res <- gh::gh("/repos/{owner}/{repo}/contents/{path}", owner = "quarto-dev", repo = "quarto-cli", path = "src/resources/formats/revealjs/themes")
revealjs_themes <- purrr::map_chr(res, "name") |> fs::path_ext_remove() |> setdiff("template")
xfun::write_utf8(revealjs_themes, "reveal-themes.txt")

# check deps 
lockfile <- renv::lockfile_create(
  type = "implicit",
  libpaths = .libPaths(),
  prompt = FALSE,
  force = FALSE,
  project = quarto_web_demo_folder
)
renv::lockfile_write(lockfile, file = NULL, project = quarto_web_demo_folder)
deps <- renv::dependencies(quarto_web_demo_folder)
renv::install(unique(deps$Package), project = quarto_web_demo_folder)


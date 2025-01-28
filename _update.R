# Paths variables 
quarto_web_demo_folder <- "_revealjs-demo-template/quarto-web-demo"
demo_path <- 'docs/presentations/revealjs/demo'

# Update Demo files from quarto web -------------------------------------------------------
# Only to do when we want to check for example update

update_demo_from_url <- function(url, demo_path, output_folder, tempdir = tempfile("demo-download")) {
  fs::dir_create(tempdir)
  if (!fs::dir_exists(output_folder)) fs::dir_create(output_folder)
  zipfile <- fs::path(tempdir, "download.zip")
  xfun::download_file(url, output = zipfile, mode = "wb")
  files <- zip::zip_list(zipfile) |> dplyr::as_tibble()
  main_folder <- files$filename[1]
  demo_path_unzipped <- fs::path(main_folder, demo_path)
  demo_files <- files |> 
    dplyr::filter(startsWith(filename, demo_path_unzipped)) |> 
    dplyr::pull(filename)
  zip::unzip(zipfile, files = demo_files, exdir = tempdir)
  
  fs::dir_delete(output_folder)
  fs::dir_copy(fs::path(tempdir, demo_path_unzipped), output_folder, overwrite = TRUE)
  fs::dir_delete(tempdir)
}

update_demo_from_url(
  url = "https://github.com/quarto-dev/quarto-web/archive/refs/heads/main.zip",
  demo_path = demo_path,
  output_folder = quarto_web_demo_folder
)

# remove pdf file
fs::file_delete(fs::path(quarto_web_demo_folder, "demo.pdf"))

# Set metadata
if (any(grepl("{{< meta prerelease-subdomain >}}", xfun::read_utf8(fs::path(quarto_web_demo_folder, "index.qmd")), fixed = TRUE))) {
  yaml::write_yaml(
    list(
      "prerelease-subdomain" = ""
    ),
    file = fs::path(quarto_web_demo_folder, "_metadata.yml"))
}

# get themes files
res <- gh::gh("/repos/{owner}/{repo}/contents/{path}", owner = "quarto-dev", repo = "quarto-cli", path = "src/resources/formats/revealjs/themes")
revealjs_themes <- purrr::map_chr(res, "name") |> fs::path_ext_remove() |> setdiff("template")
xfun::write_utf8(revealjs_themes, "reveal-themes.txt")

# check deps 
make_lockfile <- function(project) {
  lockfile <- renv::lockfile_create(
    type = "implicit",
    libpaths = .libPaths(),
    prompt = FALSE,
    force = FALSE,
    project = project
  )
  renv::lockfile_write(lockfile, file = NULL, project = project)
  deps <- renv::dependencies(project)
  renv::install(unique(deps$Package), project = project)
  renv::snapshot(project = project)
}
make_lockfile(quarto_web_demo_folder)


# Add callouts examples  -------------------------------------------------------

quarto_callout_examples_folder <- "_revealjs-demo-template/quarto-callouts-themed"
demo_path <- 'revealjs/callouts'
update_demo_from_url(
  url = "https://github.com/quarto-dev/quarto-examples/archive/refs/heads/main.zip",
  demo_path = 'revealjs/callouts',
  output_folder = quarto_callout_examples_folder
)
# remove pdf file
to_remove <- c("README.md", "README.qmd", "_publish.yml", "_quarto.yml")
fs::file_delete(fs::path(quarto_callout_examples_folder, to_remove))
fs::file_move(fs::path(quarto_callout_examples_folder, "default-styles.qmd"), fs::path(quarto_callout_examples_folder, "index.qmd"))

make_lockfile(quarto_callout_examples_folder)

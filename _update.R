

# Update Demo files from quarto web -------------------------------------------------------

tempdir <- tempfile("demo-download")
fs::dir_create(tempdir)
quarto_web <- "https://github.com/quarto-dev/quarto-web/archive/refs/heads/main.zip"
zipfile <- fs::path(tempdir, "quarto-web.zip")
xfun::download_file(quarto_web, output = fs::path(tempdir, "quarto-web.zip"), mode = "wb")
files <- zip::zip_list(zipfile) |> dplyr::as_tibble()
main_folder <- files$filename[1]
demo_path <- 'docs/presentations/revealjs/demo'
demo_path_unzipped <- fs::path(main_folder, demo_path)
demo_files <- files |> dplyr::filter(startsWith(filename, demo_path_unzipped)) |> dplyr::pull(filename)
zip::unzip(zipfile, files = demo_files, exdir = tempdir)
quarto_web_demo_folder <- "revealjs-demo-template/quarto-web-demo"
fs::dir_copy(fs::path(tempdir, demo_path_unzipped), quarto_web_demo_folder)
# remove pdf file
fs::file_delete(fs::path(quarto_web_demo_folder, "demo.pdf"))
fs::dir_delete(tempdir)

# get themes files
files |> dplyr::filter()

writeLines(revealjs_themes, "reveal-themes.txt")

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
renv::install(unique(deps$Package))

# Create project template ------------------------------------------------

render_template <- function(from, to, data) {
  from <- xfun::read_utf8(from)
  content <- whisker::whisker.render(from, data = data)
  xfun::write_utf8(content, to)
}

# do all the work in a temp directory

tempdir <- tempfile("render-quarto")
fs::dir_create(tempdir)

fs::dir_copy(quarto_web_demo_folder, tempdir)

temp_demo <- fs::path(tempdir, fs::path_file(quarto_web_demo_folder))

render_template("revealjs-demo-template/_quarto.yml.whisker", fs::path(temp_demo, "_quarto.yml"), list(theme = "default"))

withr::with_envvar(
  list(QUARTO_R = fs::path(R.home(), "bin")), 
  withr::with_dir(temp_demo, quarto::quarto_render(as_job = FALSE))
)


reveal_themes <- c(
  
)

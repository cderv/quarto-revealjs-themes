

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

quarto_web_demo_folder <- "_revealjs-demo-template/quarto-web-demo"
fs::dir_delete(quarto_web_demo_folder)
fs::dir_copy(fs::path(tempdir, demo_path_unzipped), quarto_web_demo_folder, overwrite = TRUE)
# remove pdf file
fs::file_delete(fs::path(quarto_web_demo_folder, "demo.pdf"))
fs::dir_delete(tempdir)

# get themes files
res <- gh::gh("/repos/{owner}/{repo}/contents/{path}", owner = "quarto-dev", repo = "quarto-cli", path = "src/resources/formats/revealjs/themes")
revealjs_themes <- purrr::map_chr(res, "name") |> fs::path_ext_remove()
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
renv::install(unique(deps$Package))

# Create project template ------------------------------------------------


revealjs_themes <- xfun::read_utf8("reveal-themes.txt")

# do all the work in a temp directory

if (fs::dir_exists("revealjs-themed")) fs::dir_delete("revealjs-themed")

render_reveal_theme <- function(theme) {
  render_template <- function(from, to, data) {
    from <- xfun::read_utf8(from)
    content <- whisker::whisker.render(from, data = data)
    xfun::write_utf8(content, to)
  }
  tempdir <- withr::local_tempdir("render-quarto")
  fs::dir_create(tempdir)
  fs::dir_copy(quarto_web_demo_folder, tempdir)
  temp_demo <- fs::path(tempdir, fs::path_file(quarto_web_demo_folder))
  output_dir <- glue::glue("revealjs-{theme}")
  render_template("_revealjs-demo-template/_quarto.yml.whisker", fs::path(temp_demo, "_quarto.yml"), list(theme = theme, output_dir = output_dir))
  withr::with_envvar(
    list(QUARTO_R = fs::path(R.home(), "bin")), 
    withr::with_dir(temp_demo, quarto::quarto_render(as_job = FALSE))
  )
  fs::dir_copy(fs::path(temp_demo, output_dir), fs::path("revealjs-themed", output_dir), overwrite = TRUE)
}

reveal_themed <- purrr::map_chr(revealjs_themes, render_reveal_theme)

reveal_themed <- reveal_themed |> purrr::set_names(nm = revealjs_themes)

yaml <- yaml::read_yaml("_quarto.yml")

# keep as list
yaml$project$resources <- list(yaml$project$resources)
yaml$project$render <- list(yaml$project$render)

menu_index <- purrr::imap(reveal_themed, \(x, y) {
  list(
    href = fs::path(x, "index.html"),
    text = glue::glue("Using theme {glue::single_quote(y)}.")
  )
}) 

yaml$website$navbar$right <- list(
  list(href = "index.qmd", text = "Home"), 
  list(
    text = "Revealjs Themed Presentation", 
    menu = unname(menu_index)
))

quarto:::write_yaml(yaml, "_quarto.yml")

## Render website
withr::with_envvar(
  list(QUARTO_R = fs::path(R.home(), "bin")), 
  quarto::quarto_render(as_job = FALSE)
)

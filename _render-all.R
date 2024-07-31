
# Paths variables --------------------------------------------------------

quarto_web_demo_folder <- "_revealjs-demo-template/quarto-web-demo"

# Create project template and render for each theme ------------------------------------------------

revealjs_themes <- xfun::read_utf8("reveal-themes.txt")


# render demo template in a temp directory
render_reveal_theme <- function(theme, output_path) {
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
  fs::dir_copy(fs::path(temp_demo, output_dir), fs::path(output_path, output_dir), overwrite = TRUE)
}

# render for each theme

# Rendering first batch with one version
output_path <- "revealjs-themed"
if (fs::dir_exists(output_path)) fs::dir_delete(output_path)
# TODO: make this generic
Sys.setenv(QUARTO_PATH = fs::path(system("scoop prefix quarto-prerelease", intern = TRUE), "bin", "quarto.exe"))
stopifnot(quarto::quarto_version() > "1.6")
quarto_version_main <- as.character(quarto::quarto_version())
cli::cli_inform("Rendering with {quarto_version_main}")
reveal_themed <- purrr::map_chr(revealjs_themes, render_reveal_theme, output_path = output_path)
reveal_themed <- reveal_themed |> purrr::set_names(nm = revealjs_themes)

# Rendering second batch with second version

get_dev_commit <- function() {
  res <- quarto:::quarto_run(c("check", "install"))
  regmatches(res$stderr, regexec("\\s+commit: (.*?)\n", res$stderr))[[1]][[2]]
}

withr::with_envvar(
  # TODO: make this generic
  list(QUARTO_PATH = fs::path(shell(shell = "pwsh", cmd = "$(gcm quarto).Source", intern = TRUE))), 
  {
    stopifnot(quarto::quarto_version() == "99.9.9")
    quarto_version_other <- as.character(quarto::quarto_version())
    cli::cli_inform("Rendering with {quarto_version_other}")
    output_path_2 <- glue::glue("{output_path}-2")
    if (fs::dir_exists(output_path_2)) fs::dir_delete(output_path_2)
    reveal_themed_2 <- purrr::map_chr(revealjs_themes, render_reveal_theme, output_path = output_path_2)
    reveal_themed_2 <- reveal_themed_2 |> purrr::set_names(nm = revealjs_themes)
  }
)

# Update main _quarto.yml for all generated Quarto Themed Presentations

yaml <- yaml::read_yaml("_quarto.yml")

# keep as list those field (otherwise yaml package write them as single value)
yaml$project$resources <- list(yaml$project$resources)
yaml$project$render <- list(yaml$project$render)

menu_index <- purrr::imap(reveal_themed, \(x, y) {
  list(
    href = fs::path(x, "index.html"),
    text = glue::glue("Using theme {glue::single_quote(y)}."),
    target = "_blank",
    icon = "display"
  )
})

menu_index_2 <- purrr::imap(reveal_themed_2, \(x, y) {
  list(
    href = fs::path(x, "index.html"),
    text = glue::glue("Using theme {glue::single_quote(y)}."),
    target = "_blank",
    icon = "display"
  )
})

yaml$website$navbar$right <- list(
  list(href = "index.qmd", text = "Home"), 
  list(
    text = glue::glue("Using quarto {quarto_version_main}"), 
    menu = unname(menu_index)
  ),
  list(
    text = glue::glue("Using quarto {quarto_version_other}"), 
    menu = unname(menu_index_2)
  )
)

quarto:::write_yaml(yaml, "_quarto.yml")


# Render main website ----------------------------------------------------

yaml::write_yaml(
  list(quarto_version_main = quarto_version_main, quarto_version_other = quarto_version_other),
  file = "_variables.yml"
)

withr::with_envvar(
  list(
    QUARTO_R = fs::path(R.home(), "bin"),
    QUARTO_PATH = fs::path(system("scoop prefix quarto-prerelease", intern = TRUE), "bin", "quarto.exe")
  ), {
    stopifnot(quarto::quarto_version() > "1.6")
    cli::cli_inform("Rendering all website with {quarto::quarto_version()}")
    quarto::quarto_render(as_job = FALSE)
  }
)


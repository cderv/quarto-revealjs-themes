
# Paths variables --------------------------------------------------------

quarto_web_demo_folder <- "_revealjs-demo-template/quarto-web-demo"
quarto_callout_examples_folder <- "_revealjs-demo-template/quarto-callouts-themed"

# Create project template and render for each theme ------------------------------------------------

revealjs_themes <- xfun::read_utf8("reveal-themes.txt")

# render demo template in a temp directory
render_reveal_theme <- function(theme, input_dir, output_path, output_dir_prefix) {
  render_template <- function(from, to, data) {
    from <- xfun::read_utf8(from)
    content <- whisker::whisker.render(from, data = data)
    xfun::write_utf8(content, to)
  }
  tempdir <- withr::local_tempdir("render-quarto")
  fs::dir_create(tempdir)
  fs::dir_copy(input_dir, tempdir)
  temp_demo <- fs::path(tempdir, fs::path_file(input_dir))
  output_dir <- glue::glue("{output_dir_prefix}-{theme}")
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
if (!nzchar(Sys.which("qvm"))) {
  stop("qvm is needed for this script to work")
}
qvm_version_path <- system("qvm path versions", intern = TRUE)
qvm_quarto_version <- Sys.getenv("QUARTO_VERSION")
if (!nzchar(qvm_quarto_version)) {
  stop("Set `QUARTO_VERSION` to a qvm version")
}
if (!grepl("^v", qvm_quarto_version)) qvm_quarto_version <- paste0("v", qvm_quarto_version)
Sys.setenv(QUARTO_PATH = fs::path(qvm_version_path,  qvm_quarto_version, "bin", "quarto.exe"))
stopifnot(quarto::quarto_version() > "1.6")
quarto_version_main <- as.character(quarto::quarto_version())
cli::cli_inform("Rendering with {quarto_version_main}")

reveal_demo_themed <- purrr::map_chr(revealjs_themes, render_reveal_theme, input_dir = quarto_web_demo_folder, output_path = output_path, output_dir_prefix = "revealjs-demo")
reveal_demo_themed <- reveal_demo_themed |> purrr::set_names(nm = revealjs_themes)
reveal_callout_themed <- purrr::map_chr(revealjs_themes, render_reveal_theme, input_dir = quarto_callout_examples_folder, output_path = output_path, output_dir_prefix = "revealjs-callout")
reveal_callout_themed <- reveal_callout_themed |> purrr::set_names(nm = revealjs_themes)

# Rendering second batch with second version

get_dev_commit <- function() {
  res <- quarto:::quarto_run(c("check", "install"))
  regmatches(res$stderr, regexec("\\s+commit: (.*?)\n", res$stderr))[[1]][[2]]
}

withr::with_envvar(
  list(QUARTO_PATH = Sys.getenv("QUARTO_PATH_2", "quarto")), 
  {
    stopifnot(quarto::quarto_version() == "99.9.9")
    quarto_version_other <- as.character(quarto::quarto_version())
    cli::cli_inform("Rendering with {quarto_version_other}")
    output_path_2 <- glue::glue("{output_path}-2")
    # if (fs::dir_exists(output_path_2)) fs::dir_delete(output_path_2)
    # reveal_demo_themed_2 <- purrr::map_chr(revealjs_themes, render_reveal_theme, input_dir = quarto_web_demo_folder, output_path = output_path_2, output_dir_prefix = "revealjs-demo")
    # reveal_demo_themed_2 <- reveal_demo_themed_2 |> purrr::set_names(nm = revealjs_themes)
    reveal_callout_themed_2 <- purrr::map_chr(revealjs_themes, render_reveal_theme, input_dir = quarto_callout_examples_folder, output_path = output_path_2, output_dir_prefix = "revealjs-callout")
    reveal_callout_themed_2 <- reveal_callout_themed_2 |> purrr::set_names(nm = revealjs_themes)
  }
)

## Add example page
expand_main_page <- function(example_dir, sub_folder_prefix, title, description) {
  knitr::knit_expand(
    file = "_revealjs-demo-template/index.knit_expand.qmd", 
    delim = c("<<<", ">>>"),
    title = title, description = description, example_dir = example_dir, sub_folder_prefix = sub_folder_prefix
  ) |> xfun::write_utf8(fs::path_ext_set(sub_folder_prefix, "qmd"))
}

main_folder <- "revealjs-themed"
subfolder_demo <- "revealjs-demo"
subfolder_callout <- "revealjs-callout"

expand_main_page(example_dir = "revealjs-themed", sub_folder_prefix = subfolder_demo, title = "Revealjs Demo Slides", description = "This page shows Revealjs demo slide (from <https://quarto.org/docs/presentations/revealjs/>) for all themes.")
expand_main_page(example_dir = "revealjs-themed", sub_folder_prefix = subfolder_callout, title = "Callouts in Revealjs", description = "This page shows callouts rendered in all Revealjs themes.")

# Update main _quarto.yml for all generated Quarto Themed Presentations

yaml <- yaml::read_yaml("_quarto.yml")

# keep as list those field (otherwise yaml package write them as single value)
yaml$project$resources <- paste0(main_folder, c("", "-2"), "/")
yaml$project$render <- c("index.qmd", fs::path_ext_set(c(subfolder_callout, subfolder_demo), "qmd"))


yaml$website$navbar$left <- list(
  list(href = "index.qmd", text = "Home"), 
  list(
    text = "Revealjs Demo Slides", 
    href = fs::path_ext_set(subfolder_demo, "qmd")
  ),
  list(
    text = "Callout in Revealjs", 
    href = fs::path_ext_set(subfolder_callout, "qmd")
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


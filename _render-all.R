
# Paths variables --------------------------------------------------------

quarto_web_demo_folder <- "_revealjs-demo-template/quarto-web-demo"

# Create project template and render for each theme ------------------------------------------------

revealjs_themes <- xfun::read_utf8("reveal-themes.txt")

if (fs::dir_exists("revealjs-themed")) fs::dir_delete("revealjs-themed")

# render demo template in a temp directory
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

# render for each theme
reveal_themed <- purrr::map_chr(revealjs_themes, render_reveal_theme)

# Update main _quarto.yml for all generated Quarto Themed Presentations
reveal_themed <- reveal_themed |> purrr::set_names(nm = revealjs_themes)
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

yaml$website$navbar$right <- list(
  list(href = "index.qmd", text = "Home"), 
  list(
    text = "Revealjs Themed Presentation", 
    menu = unname(menu_index)
))

quarto:::write_yaml(yaml, "_quarto.yml")


# Render main website ----------------------------------------------------

yaml::write_yaml(
  list(quarto_version = as.character(quarto::quarto_version())),
  file = "_variables.yml"
)

withr::with_envvar(
  list(QUARTO_R = fs::path(R.home(), "bin")), 
  quarto::quarto_render(as_job = FALSE)
)


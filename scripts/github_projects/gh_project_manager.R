# Paquetes

library(gh)
library(readr)
library(purrr)
library(cli)
library(glue)

# ── Funciones auxiliares

#' Valida que el data.frame tenga las columnas requeridas del CSV de issues
#'
#' @param df data.frame leído desde el CSV de issues
#' @return `df` invisible si es válido; lanza error si no lo es
validate_issues_csv <- function(df) {
  required <- c("title", "description", "labels", "assignees")
  missing_cols <- setdiff(required, names(df))
  if (length(missing_cols) > 0) {
    cli::cli_abort(
      "Faltan columnas requeridas en el CSV: {paste(missing_cols, collapse = ', ')}"
    )
  }
  empty_titles <- which(is.na(df$title) | trimws(df$title) == "")
  if (length(empty_titles) > 0) {
    cli::cli_abort(
      "Filas con título vacío: {paste(empty_titles, collapse = ', ')}"
    )
  }
  cli_alert_success("CSV validado correctamente ({nrow(df)} filas).")
  invisible(df)
}

#' Convierte una cadena separada por comas en un vector de caracteres
#'
#' @param x Cadena de texto, p.ej. `"a,b,c"`, o `NA`
#' @return Vector de caracteres sin espacios extra; `character(0)` si vacío o NA
parse_comma_separated <- function(x) {
  if (is.na(x) || stringr::str_trim(x) == "") return(character(0))
  stringr::str_trim(stringr::str_split_1(x, ","))
}

# Misma funcion, pero sugerida por GitHub Copilot para usar funciones de R base.
parse_comma_separated <- function(x) {
  if (is.na(x) || trimws(x) == "") return(character(0))
  trimws(strsplit(x, ",")[[1]])
}

#' Convierte secuencias literales `\n` del CSV en saltos de línea reales
#'
#' Necesario para que los checklists se rendericen correctamente en GitHub.
#'
#' @param text Texto proveniente del CSV
#' @return Texto con saltos de línea reales
process_description <- \(text) {
  if (is.na(text) || stringr::str_trim(text) == "") return("")
  stringr::str_replace_all(text, "\\\\n", "\n")
}

# Misma funcion, pero sugerida por GitHub Copilot para usar funciones de R base.
process_description <- \(text) {
  if (is.na(text) || trimws(text) == "") return("")
  gsub("\\\\n", "\n", text)
}

# ── Funciones de labels

#' Obtiene las labels existentes en un repositorio
#'
#' @param owner Usuario u organización dueña del repositorio
#' @param repo  Nombre del repositorio
#' @return Vector de caracteres con los nombres de las labels existentes
get_existing_labels <- function(owner, repo) {
  tryCatch({
    labels <- gh("/repos/{owner}/{repo}/labels",
                 owner = owner, repo = repo,
                 .limit = Inf)
    map_chr(labels, "name")
  }, error = \(e) {
    cli_alert_danger("Error al obtener labels de {owner}/{repo}: {e$message}")
    character(0)
  })
}

#' Crea las labels faltantes en el repositorio con colores de una paleta armoniosa
#'
#' @param owner         Usuario u organización
#' @param repo          Nombre del repositorio
#' @param labels_needed Vector de nombres de labels requeridas
#' @return Invisible NULL
ensure_labels_exist <- function(owner, repo, labels_needed) {
  if (length(labels_needed) == 0) return(invisible(NULL))

  palette <- c(
    "0075ca", "e4e669", "d93f0b", "0052cc", "5319e7",
    "b60205", "1d76db", "0e8a16", "f9d0c4", "c2e0c6",
    "bfd4f2", "d4c5f9", "f9c513", "e11d48", "7057ff"
  )

  existing <- get_existing_labels(owner, repo)
  missing  <- setdiff(labels_needed, existing)

  if (length(missing) == 0) {
    cli_alert_info("Todas las labels ya existen en {owner}/{repo}.")
    return(invisible(NULL))
  }

  cli_h2("Creando {length(missing)} label(s) nueva(s)")
  walk2(missing, seq_along(missing), \(label, i) {
    color <- palette[((i - 1) %% length(palette)) + 1]
    tryCatch({
      gh("POST /repos/{owner}/{repo}/labels",
         owner = owner, repo = repo,
         name  = label,
         color = color)
      cli_alert_success("Label creada: {label} (#{color})")
    }, error = \(e) {
      cli_alert_warning("No se pudo crear la label '{label}': {e$message}")
    })
  })
  invisible(NULL)
}

# ── Funciones de issues

#' Crea una issue individual en un repositorio
#'
#' @param owner            Usuario u organización
#' @param repo             Nombre del repositorio
#' @param title            Título de la issue
#' @param body             Cuerpo de la issue (descripción)
#' @param labels           Vector de caracteres con nombres de labels
#' @param assignees        Vector de caracteres con usernames de asignados
#' @param milestone_number Número entero del milestone (o NULL)
#' @return Lista con la respuesta de la API de GitHub
create_single_issue <- function(owner, repo, title, body, labels, assignees, milestone_number = NULL) {
  params <- list(
    owner     = owner,
    repo      = repo,
    title     = title,
    body      = body,
    labels    = as.list(labels),
    assignees = as.list(assignees)
  )
  if (!is.null(milestone_number)) {
    params$milestone <- milestone_number
  }
  do.call(gh, c(list("POST /repos/{owner}/{repo}/issues"), params))
}

#' Crea todas las issues de un data.frame en el repositorio
#'
#' Primero garantiza que todas las labels existan. Incluye pausa de 1 s entre
#' issues para respetar los rate limits de la API.
#'
#' @param df             data.frame con columnas title, description, labels,
#'                       assignees y (opcionalmente) milestone
#' @param owner          Usuario u organización
#' @param repo           Nombre del repositorio
#' @param milestones_map Lista nombrada (nombre_milestone → número) o NULL
#' @return data.frame con columnas title, number, url, status
create_issues_from_df <- function(df, owner, repo, milestones_map = NULL) {
  all_labels <- df$labels |>
    map(parse_comma_separated) |>
    unlist() |>
    unique()
  ensure_labels_exist(owner, repo, all_labels)

  cli_h1("Creando {nrow(df)} issue(s) en {owner}/{repo}")

  results <- map(seq_len(nrow(df)), \(i) {
    row        <- df[i, ]
    title      <- trimws(row$title)
    body       <- process_description(row$description)
    labels     <- parse_comma_separated(row$labels)
    assignees  <- parse_comma_separated(row$assignees)
    milestone  <- if ("milestone" %in% names(row) && !is.na(row$milestone)) {
      milestones_map[[row$milestone]]
    } else NULL

    cli_rule()
    cli_alert_info("[{i}/{nrow(df)}] Creando issue: {title}")

    result <- tryCatch({
      resp <- create_single_issue(owner, repo, title, body, labels, assignees, milestone)
      cli_alert_success("Issue #{resp$number} creada: {resp$html_url}")
      list(title = title, number = resp$number, url = resp$html_url,
           status = "created", node_id = resp$node_id)
    }, error = \(e) {
      cli_alert_danger("Error al crear '{title}': {e$message}")
      list(title = title, number = NA_integer_, url = NA_character_,
           status = glue("error: {e$message}"), node_id = NA_character_)
    })

    if (i < nrow(df)) Sys.sleep(1)
    result
  })

  map_dfr(results, \(r) data.frame(
    title  = r$title,
    number = r$number,
    url    = r$url,
    status = r$status,
    stringsAsFactors = FALSE
  ))
}

# ── Funciones de milestones

#' Obtiene milestones existentes o los crea si no existen
#'
#' @param owner           Usuario u organización
#' @param repo            Nombre del repositorio
#' @param milestone_names Vector de nombres de milestones requeridos
#' @return Lista nombrada: nombre_milestone → número de milestone
get_or_create_milestones <- function(owner, repo, milestone_names) {
  if (length(milestone_names) == 0) return(list())

  cli_h2("Verificando milestones")

  existing <- tryCatch({
    ms <- gh("/repos/{owner}/{repo}/milestones",
             owner = owner, repo = repo,
             .limit = Inf)
    setNames(map_int(ms, "number"), map_chr(ms, "title"))
  }, error = \(e) {
    cli_alert_warning("No se pudieron obtener milestones: {e$message}")
    integer(0)
  })

  result <- list()
  walk(milestone_names, \(name) {
    if (name %in% names(existing)) {
      cli_alert_info("Milestone ya existe: '{name}' (#{existing[[name]]})")
      result[[name]] <<- existing[[name]]
    } else {
      tryCatch({
        resp <- gh("POST /repos/{owner}/{repo}/milestones",
                   owner = owner, repo = repo,
                   title = name)
        cli_alert_success("Milestone creado: '{name}' (#{resp$number})")
        result[[name]] <<- resp$number
      }, error = \(e) {
        cli_alert_danger("Error al crear milestone '{name}': {e$message}")
        result[[name]] <<- NULL
      })
    }
  })
  result
}

# ── Funciones de GitHub Projects v2 (GraphQL)

#' Función interna: crea un Project v2 dado un node ID de owner
#'
#' @param owner_id Node ID del usuario u organización en GraphQL
#' @param title    Título del proyecto
#' @return ID del proyecto creado (node ID)
create_project_by_id <- function(owner_id, title) {
  query <- '
    mutation CreateProject($ownerId: ID!, $title: String!) {
      createProjectV2(input: {ownerId: $ownerId, title: $title}) {
        projectV2 {
          id
          title
          url
        }
      }
    }
  '
  resp <- gh("POST /graphql",
             query     = query,
             variables = list(ownerId = owner_id, title = title))
  project <- resp$data$createProjectV2$projectV2
  cli_alert_success("Proyecto creado: '{project$title}' → {project$url}")
  project$id
}

#' Obtiene el node ID de un usuario de GitHub
#'
#' @param owner Username del usuario
#' @return Node ID del usuario
.get_user_node_id <- function(owner) {
  query <- '
    query GetUserId($login: String!) {
      user(login: $login) { id }
    }
  '
  resp <- gh("POST /graphql",
             query     = query,
             variables = list(login = owner))
  resp$data$user$id
}

#' Obtiene el node ID de una organización de GitHub
#'
#' @param org Nombre de la organización
#' @return Node ID de la organización
.get_org_node_id <- \(org) {
  query <- '
    query GetOrgId($login: String!) {
      organization(login: $login) { id }
    }
  '
  resp <- gh("POST /graphql",
             query     = query,
             variables = list(login = org))
  resp$data$organization$id
}

#' Crea un Project v2 para un usuario personal
#'
#' @param owner Username del usuario
#' @param title Título del proyecto
#' @return ID (node ID) del proyecto creado
create_user_project <- function(owner, title) {
  cli_h2("Creando proyecto para usuario '{owner}'")
  tryCatch({
    owner_id <- .get_user_node_id(owner)
    create_project_by_id(owner_id, title)
  }, error = \(e) {
    cli_alert_danger("Error al crear proyecto de usuario: {e$message}")
    stop(e)
  })
}

#' Crea un Project v2 para una organización
#'
#' @param org   Nombre de la organización
#' @param title Título del proyecto
#' @return ID (node ID) del proyecto creado
create_org_project <- function(org, title) {
  cli_h2("Creando proyecto para organización '{org}'")
  tryCatch({
    org_id <- .get_org_node_id(org)
    create_project_by_id(org_id, title)
  }, error = \(e) {
    cli_alert_danger("Error al crear proyecto de organización: {e$message}")
    stop(e)
  })
}

#' Agrega una issue a un Project v2 mediante GraphQL mutation
#'
#' @param project_id    Node ID del proyecto (obtenido con create_user/org_project)
#' @param issue_node_id Node ID de la issue a agregar
#' @return Invisible NULL
add_issue_to_project <- function(project_id, issue_node_id) {
  mutation <- '
    mutation AddIssueToProject($projectId: ID!, $contentId: ID!) {
      addProjectV2ItemById(input: {projectId: $projectId, contentId: $contentId}) {
        item { id }
      }
    }
  '
  tryCatch({
    gh("POST /graphql",
       query     = mutation,
       variables = list(projectId = project_id, contentId = issue_node_id))
    cli_alert_success("Issue agregada al proyecto.")
  }, error = \(e) {
    cli_alert_warning("No se pudo agregar la issue al proyecto: {e$message}")
  })
  invisible(NULL)
}

# ── Funciones principales

#' Crea un GitHub Project v2 y todas las issues definidas en un CSV
#'
#' Flujo completo: (1) lee y valida CSV, (2) crea el proyecto, (3) crea
#' milestones, (4) crea issues con labels/assignees/milestones, (5) agrega cada
#' issue al proyecto.
#'
#' @param csv_path     Ruta al archivo CSV de issues
#' @param owner        Usuario u organización dueña del repositorio
#' @param repo         Nombre del repositorio
#' @param project_title Título del nuevo GitHub Project v2
#' @param is_org       `TRUE` si `owner` es una organización; `FALSE` (por
#'                     defecto) para usuario personal
#' @return data.frame con resultados de creación de issues
create_project_with_issues <- function(csv_path, owner, repo, project_title, is_org = FALSE) {
  cli_h1("GitHub Project Manager")
  cli_rule()

  # 1. Leer y validar CSV
  cli_h2("Leyendo CSV")
  df <- read_csv(csv_path, show_col_types = FALSE)
  validate_issues_csv(df)

  # 2. Crear proyecto
  project_id <- if (is_org) {
    create_org_project(owner, project_title)
  } else {
    create_user_project(owner, project_title)
  }

  # 3. Milestones
  milestones_map <- NULL
  if ("milestone" %in% names(df)) {
    ms_names <- unique(na.omit(df$milestone))
    if (length(ms_names) > 0) {
      milestones_map <- get_or_create_milestones(owner, repo, ms_names)
    }
  }

  # 4. Crear issues
  results <- create_issues_from_df(df, owner, repo, milestones_map)

  # 5. Agregar issues al proyecto
  cli_h2("Agregando issues al proyecto")
  created_issues <- filter_created_issues(df, results)
  walk(created_issues, \(node_id) {
    add_issue_to_project(project_id, node_id)
    Sys.sleep(0.5)
  })

  cli_rule()
  cli_alert_success("¡Proceso finalizado! {sum(results$status == 'created')} issue(s) creadas.")
  invisible(results)
}

#' Filtra los node IDs de issues creadas exitosamente (uso interno)
#'
#' @param df      data.frame original del CSV
#' @param results data.frame de resultados devuelto por create_issues_from_df
#' @return Vector de node IDs de issues creadas
filter_created_issues <- function(df, results) {
  # Re-fetch node IDs para las issues creadas
  purrr::keep(results$url, \(u) !is.na(u)) |>
    map_chr(\(url) {
      tryCatch({
        parts <- strsplit(url, "/")[[1]]
        owner_r <- parts[length(parts) - 3]
        repo_r  <- parts[length(parts) - 2]
        number  <- as.integer(parts[length(parts)])
        resp    <- gh("/repos/{owner}/{repo}/issues/{number}",
                      owner = owner_r, repo = repo_r, number = number)
        resp$node_id
      }, error = \(e) NA_character_)
    }) |>
    purrr::discard(is.na)
}

#' Crea issues desde un CSV sin crear un proyecto
#'
#' Versión simplificada de `create_project_with_issues` que omite la creación
#' del GitHub Project v2.
#'
#' @param csv_path Ruta al CSV de issues
#' @param owner    Usuario u organización
#' @param repo     Nombre del repositorio
#' @return data.frame con resultados de creación de issues
create_issues_only <- function(csv_path, owner, repo) {
  cli_h1("Creando issues desde CSV")
  cli_rule()

  df <- read_csv(csv_path, show_col_types = FALSE)
  validate_issues_csv(df)

  milestones_map <- NULL
  if ("milestone" %in% names(df)) {
    ms_names <- unique(na.omit(df$milestone))
    if (length(ms_names) > 0) {
      milestones_map <- get_or_create_milestones(owner, repo, ms_names)
    }
  }

  results <- create_issues_from_df(df, owner, repo, milestones_map)
  cli_rule()
  cli_alert_success("¡Listo! {sum(results$status == 'created')} issue(s) creadas.")
  invisible(results)
}

# ── Funciones auxiliares de descarga (internas)

#' Determina el valor de assignees para exportar a CSV
#'
#' @param assignee_logins Vector de caracteres con los logins de los asignados
#' @param reset_assignees Si `TRUE`, devuelve cadena vacía
#' @return Cadena de logins separados por coma, o `""` si reset es TRUE
.format_assignees <- function(assignee_logins, reset_assignees) {
  if (reset_assignees) "" else paste(assignee_logins, collapse = ",")
}

#' Convierte el cuerpo de una issue para exportar a CSV
#'
#' Reemplaza saltos de línea reales por la secuencia literal `\n` para que el
#' CSV sea legible y reutilizable con `process_description()`.
#'
#' @param body Texto del cuerpo de la issue (puede ser NULL o NA)
#' @return Cadena de texto con `\n` literales, o `""` si el cuerpo está vacío
.format_body_for_csv <- function(body) {
  if (is.null(body) || is.na(body)) "" else gsub("\n", "\\\\n", body)
}

# ── Funciones de descarga

#' Descarga todas las issues de un repositorio a un CSV reutilizable
#'
#' Filtra los pull requests automáticamente. Usa el mismo formato de columnas
#' que el CSV de creación para facilitar la reutilización.
#'
#' @param owner          Usuario u organización
#' @param repo           Nombre del repositorio
#' @param output_path    Ruta de salida para el CSV (por defecto `issues_export.csv`)
#' @param state          Estado de las issues: `"open"`, `"closed"` o `"all"`
#'                       (por defecto `"all"`)
#' @param labels_filter  Vector de labels para filtrar (NULL = sin filtro)
#' @param reset_assignees Si `TRUE`, vacía la columna assignees en el CSV de salida
#' @return data.frame con las issues descargadas
download_issues <- function(owner, repo,
                            output_path    = "issues_export.csv",
                            state          = "all",
                            labels_filter  = NULL,
                            reset_assignees = FALSE) {
  cli_h1("Descargando issues de {owner}/{repo}")

  params <- list(
    owner  = owner,
    repo   = repo,
    state  = state,
    .limit = Inf
  )
  if (!is.null(labels_filter)) {
    params$labels <- paste(labels_filter, collapse = ",")
  }

  issues_raw <- tryCatch(
    do.call(gh, c(list("/repos/{owner}/{repo}/issues"), params)),
    error = \(e) {
      cli_alert_danger("Error al descargar issues: {e$message}")
      stop(e)
    }
  )

  # Filtrar PRs
  issues_raw <- purrr::discard(issues_raw, \(x) !is.null(x$pull_request))
  cli_alert_info("{length(issues_raw)} issue(s) encontradas (PRs excluidos).")

  if (length(issues_raw) == 0) {
    cli_alert_warning("No hay issues para exportar.")
    return(invisible(data.frame()))
  }

  df <- map_dfr(issues_raw, \(issue) {
    labels    <- paste(map_chr(issue$labels, "name"), collapse = ",")
    assignees <- .format_assignees(map_chr(issue$assignees, "login"), reset_assignees)
    milestone <- if (!is.null(issue$milestone)) issue$milestone$title else NA_character_
    body_out  <- .format_body_for_csv(issue$body)
    data.frame(
      title       = issue$title,
      description = body_out,
      labels      = labels,
      assignees   = assignees,
      milestone   = milestone,
      stringsAsFactors = FALSE
    )
  })

  write_csv(df, output_path)
  cli_alert_success("CSV exportado a: {output_path} ({nrow(df)} filas)")
  invisible(df)
}

#' Descarga las issues de un GitHub Project v2 específico a un CSV reutilizable
#'
#' Usa la API GraphQL de GitHub para obtener las issues del proyecto.
#'
#' @param owner          Usuario u organización dueña del proyecto
#' @param project_number Número del proyecto (visible en la URL de GitHub)
#' @param output_path    Ruta de salida para el CSV (por defecto `project_issues_export.csv`)
#' @param is_org         `TRUE` si `owner` es una organización
#' @param reset_assignees Si `TRUE`, vacía la columna assignees en el CSV de salida
#' @return data.frame con las issues descargadas
download_project_issues <- function(owner, project_number,
                                    output_path    = "project_issues_export.csv",
                                    is_org         = FALSE,
                                    reset_assignees = FALSE) {
  cli_h1("Descargando issues del proyecto #{project_number} de {owner}")

  owner_field <- if (is_org) "organization" else "user"
  query <- glue('
    query GetProjectIssues($login: String!, $number: Int!, $cursor: String) {{
      {owner_field}(login: $login) {{
        projectV2(number: $number) {{
          items(first: 100, after: $cursor) {{
            pageInfo {{ hasNextPage endCursor }}
            nodes {{
              content {{
                ... on Issue {{
                  title
                  body
                  number
                  labels(first: 20) {{ nodes {{ name }} }}
                  assignees(first: 20) {{ nodes {{ login }} }}
                  milestone {{ title }}
                }}
              }}
            }}
          }}
        }}
      }}
    }}
  ')

  all_items <- list()
  cursor    <- NULL
  repeat {
    resp <- tryCatch(
      gh("POST /graphql",
         query     = query,
         variables = list(login = owner, number = project_number,
                          cursor = cursor)),
      error = \(e) {
        cli_alert_danger("Error en GraphQL: {e$message}")
        stop(e)
      }
    )
    proj_data <- resp$data[[owner_field]]$projectV2$items
    all_items <- c(all_items, proj_data$nodes)
    if (!proj_data$pageInfo$hasNextPage) break
    cursor <- proj_data$pageInfo$endCursor
  }

  # Filtrar nodos que son Issues (no Draft Items)
  issue_nodes <- purrr::keep(all_items, \(n) !is.null(n$content$title))
  cli_alert_info("{length(issue_nodes)} issue(s) encontradas en el proyecto.")

  if (length(issue_nodes) == 0) {
    cli_alert_warning("No hay issues para exportar.")
    return(invisible(data.frame()))
  }

  df <- map_dfr(issue_nodes, \(node) {
    issue     <- node$content
    labels    <- paste(map_chr(issue$labels$nodes, "name"), collapse = ",")
    assignees <- .format_assignees(map_chr(issue$assignees$nodes, "login"), reset_assignees)
    milestone <- if (!is.null(issue$milestone)) issue$milestone$title else NA_character_
    body_out  <- .format_body_for_csv(issue$body)
    data.frame(
      title       = issue$title,
      description = body_out,
      labels      = labels,
      assignees   = assignees,
      milestone   = milestone,
      stringsAsFactors = FALSE
    )
  })

  write_csv(df, output_path)
  cli_alert_success("CSV exportado a: {output_path} ({nrow(df)} filas)")
  invisible(df)
}

# Scripts I use to manage Champions Program Task

This list of different script are used to manage several aspects of the Champions Program.

> TODO: create a package with this functions and scripts.

## GitHub Project Manager desde R

* gh_project_manager.R: R functions to manage GitHub projects and issues.  The Champions Programs has a series of repetitive task and milestones. We mange all the program using a GitHub project.  This script help to create the initual project with all the task as issues and labeled per milestone for an easy organization and tracking. This work with issues_template.csv and issues-cp.csv

* issues-template.csv: example of the format for the list of issue for a project. 

* issues-cp.csv: issues for the 2024-2025 cohort, base used to create the 2026-2027 cohort.  Every time we finished a cohort, we export all the issues to use as based of the next


### Características

- **Carga masiva de issues** desde un CSV con título, descripción, labels, assignees y milestones
- **Creación automática de labels** faltantes con colores de una paleta armoniosa
- **Gestión de milestones**: crea los que no existan o reutiliza los existentes
- **Integración con GitHub Projects v2**: crea el proyecto y agrega cada issue automáticamente
- **Descarga de issues** a CSV reutilizable (filtrando PRs), desde un repositorio o desde un proyecto
- **Flujo de reutilización**: descarga → edita el CSV → vuelve a crear en el siguiente ciclo
- **Checklists** renderizadas correctamente en GitHub gracias a la conversión de `\n`
- **Repos privados**: requiere PAT con los permisos adecuados

### Paquetes necesarios

| Paquete | Uso |
|---------|-----|
| `gh`    | Llamadas a la API REST y GraphQL de GitHub |
| `readr` | Lectura y escritura de archivos CSV |
| `purrr` | Iteración funcional sobre listas y vectores |
| `cli`   | Mensajes formateados en la consola |
| `glue`  | Concatenación de cadenas de texto |

Instalación de estos paquetes:

```r
install.packages(c("gh", "readr", "purrr", "cli", "glue"))
```

### Autenticación con GitHub PAT

Necesitás un **Personal Access Token (PAT)** con los permisos:
- `repo` — para crear issues, labels y milestones
- `project` — para crear y gestionar GitHub Projects v2

** Configuralo con `gitcreds`:**

```r
# install.packages("gitcreds")
gitcreds::gitcreds_set()  # Pegá tu PAT cuando lo solicite
```

### Estructura del CSV con la lista de _issues_

| Columna       | Requerida | Descripción                                      | Ejemplo                          |
|---------------|:---------:|--------------------------------------------------|----------------------------------|
| `title`       | Si        | Título de lissue                               | `"Configurar repositorio"`       |
| `description` | Si        | Cuerpo de la issue. Usar `\n` para saltos de línea | `"- [ ] Tarea 1\n- [ ] Tarea 2"` |
| `labels`      | Si        | Labels separadas por coma                        | `"setup,priority:high"`          |
| `assignees`   | Si        | Usernames de GitHub separados por coma           | `"yabellini,colaborador1"`       |
| `milestone`   | No        | Nombre del milestone (se crea si no existe)      | `"Sprint 1"`                     |

## Listado de fucniones

### Funciones principales

| Función | Descripción |
|---------|-------------|
| `create_project_with_issues(csv_path, owner, repo, project_title, is_org)` | Crea un GitHub Project v2 y todas las issues del CSV |
| `create_issues_only(csv_path, owner, repo)` | Crea issues desde CSV sin crear proyecto |
| `download_issues(owner, repo, output_path, state, labels_filter, reset_assignees)` | Descarga issues de un repo a CSV |
| `download_project_issues(owner, project_number, output_path, is_org, reset_assignees)` | Descarga issues de un Project v2 a CSV |

### Funciones auxiliares

| Función | Descripción |
|---------|-------------|
| `validate_issues_csv(df)` | Valida columnas requeridas y títulos no vacíos |
| `parse_comma_separated(x)` | Convierte `"a,b,c"` en `c("a","b","c")` |
| `process_description(text)` | Convierte `\n` literales en saltos de línea reales |
| `get_existing_labels(owner, repo)` | Obtiene labels existentes en el repo |
| `ensure_labels_exist(owner, repo, labels_needed)` | Crea las labels faltantes |
| `create_single_issue(owner, repo, title, body, labels, assignees, milestone_number)` | Crea una issue individual |
| `create_issues_from_df(df, owner, repo, milestones_map)` | Itera el data.frame y crea todas las issues |
| `get_or_create_milestones(owner, repo, milestone_names)` | Obtiene o crea milestones |
| `create_user_project(owner, title)` | Crea un Project v2 para usuario personal |
| `create_org_project(org, title)` | Crea un Project v2 para organización |
| `create_project_by_id(owner_id, title)` | Crea proyecto dado un node ID (uso interno) |
| `add_issue_to_project(project_id, issue_node_id)` | Agrega una issue a un Project v2 |


## Uso de los scripts

### Cargar las funciones

```r
source("gh_project_manager.R")
```

### Crear un proyecto completo con issues (repo personal)

```r
create_project_with_issues(
  csv_path      = "issues_template.csv",
  owner         = "mi-usuario",
  repo          = "mi-repositorio",
  project_title = "Cohort 2025"
)
```

### Crear un proyecto en una organización

```r
create_project_with_issues(
  csv_path      = "issues_template.csv",
  owner         = "mi-organizacion",
  repo          = "mi-repositorio",
  project_title = "Roadmap Q1",
  is_org        = TRUE
)
```

### Crear solo issues sin proyecto

```r
create_issues_only(
  csv_path = "issues_template.csv",
  owner    = "mi-usuario",
  repo     = "mi-repositorio"
)
```

### Descargar issues de un repositorio

```r
# Todas las issues (abiertas y cerradas)
download_issues(
  owner       = "mi-usuario",
  repo        = "mi-repositorio",
  output_path = "issues_backup.csv"
)

# Solo issues abiertas
download_issues(
  owner       = "mi-usuario",
  repo        = "mi-repositorio",
  output_path = "issues_abiertas.csv",
  state       = "open"
)

# Filtrar por labels
download_issues(
  owner         = "mi-usuario",
  repo          = "mi-repositorio",
  output_path   = "issues_bug.csv",
  labels_filter = c("bug", "priority:high")
)

# Vaciar assignees para reutilizar el CSV en otro repo
download_issues(
  owner           = "mi-usuario",
  repo            = "mi-repositorio",
  output_path     = "issues_template_nuevo_ciclo.csv",
  reset_assignees = TRUE
)
```

### Descargar issues de un GitHub Project específico

```r
# Proyecto de usuario personal
download_project_issues(
  owner          = "mi-usuario",
  project_number = 5,
  output_path    = "proyecto_issues.csv"
)

# Proyecto de organización con reset de assignees
download_project_issues(
  owner           = "mi-organizacion",
  project_number  = 3,
  output_path     = "proyecto_template.csv",
  is_org          = TRUE,
  reset_assignees = TRUE
)
```


## Champions 2026-2027

```
create_project_with_issues(
  csv_path      = "champion_program/issues-cp.csv",
  owner         = "rosadmin",
  repo          = "champions-program",
  project_title = "Champions Program 2026-2027 - Spanish"
)
```



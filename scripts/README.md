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

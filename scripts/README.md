# Scripts I use to manage Champions Program Task

This list of different script are used to manage several aspects of the Champions Program.

> TODO: create a package with this functions and scripts.

## GitHub Project Manager desde R

* gh_project_manager.R: R functions to manage GitHub projects and issues.  The Champions Programs has a series of repetitive task and milestones. We mange all the program using a GitHub project.  This script help to create the initual project with all the task as issues and labeled per milestone for an easy organization and tracking. This work with issues_template.csv and issues-cp.csv

* issues-template.csv: example of the format for the list of issue for a project. 

* issues-cp.csv: issues for the 2024-2025 cohort, base used to create the 2026-2027 cohort.  Every time we finished a cohort, we export all the issues to use as based of the next




## Ejemplo de uso

```
create_project_with_issues(
  csv_path      = "champion_program/issues-cp.csv",
  owner         = "rosadmin",
  repo          = "champions-program",
  project_title = "Champions Program 2026-2027 - Spanish"
)
```

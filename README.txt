Directory Overview:

1. Data/
    - Contains all raw data files for processing.
    - Place CSV, Excel, and other data files here.

    Note:
    - If this repository is used for a distributed team, the Data folder
      should be sparingly used.
    - Consider using a shared location for storing data that needs to be
      shared across groups.
    - The Data folder should mainly be used exclusively for data that only
      the user needs to access, such as temporary save files or save locations.

2. Code/
    - Houses all code for data processing and analysis.
    - Subdirectories can organize code by function or language.

    Conventions:
    - All initial code or scripts should be saved with the "dev_" prefix,
      denoting development.
    - Once code becomes more formalized or frequently used, it should be
      renamed with the "prdctn_" prefix, indicating production readiness.

3. SQL/
    - Stores SQL scripts for database operations.
    - Include scripts for database creation, queries, and maintenance.

4. R/
    - Holds custom R scripts with proper documentation.
    - Include Oxygen documentation for functions used in analysis.

5. Analysis/
    - Contains Markdown files and their HTML outputs.
    - Store reports, summaries, and visualizations in this folder.

6. Docs/
    - Holds documentation, manuals, and notes related to the project.
    - Include README files, project plans, and any other relevant documents.

7. Logs/
    - Houses log files generated during code execution.
    - Maintain logs for troubleshooting and auditing purposes.

8. .gitignore
    - Specifies files and directories to be ignored by version control.
    - Exclude sensitive files and temporary files from being tracked.

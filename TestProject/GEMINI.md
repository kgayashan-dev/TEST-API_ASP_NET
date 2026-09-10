# Project Guidelines & Rules

## Database Ground Truth Rule
- **CRITICAL**: Do **NOT** rely on SQL files in the project directory (`Scripts/`, `.sql` files, etc.), as those may be outdated or desynchronized from the actual database environment.
- **Read-Only Live Object Inspection**: Before making any decisions, writing code, creating models, or calling procedures, inspect the live database objects (tables, procedures, views, functions, parameters, and constraints) directly using read-only queries if needed.

## Strict Database Execution Policy (CRITICAL)
- **DO NOT EXECUTE ANYTHING IN THE DATABASE**: Never execute any write commands, DDL (`CREATE`, `ALTER`, `DROP`), DML (`INSERT`, `UPDATE`, `DELETE`), seeding, or modifying stored procedures directly in the database.
- **Provide SQL Scripts Only**: For any database changes, stored procedures, table alterations, or data scripts, generate the `.sql` script file in the `Scripts/` folder and present it to the user so that they can manually review and execute it.

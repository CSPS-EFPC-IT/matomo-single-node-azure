; <?php exit; ?> DO NOT REMOVE THIS LINE
;
; This common.config.ini.php file is read right before config.ini.php
[General]
; Always use SSL and redirect http->https in Matomo
force_ssl = 1

; Do not allow users to trigger the Matomo archiving process.
; Ensures that no unexpected data processing triggers from UI or API.
enable_browser_archiving_triggering = 0

; Uncomment to make sure that API requests with
; a &segment= parameter will not trigger archiving
; browser_archiving_disabled_enforce = 1

;Uncomment to disable historical archive processing
;when a new plugin is installed and may try process historical data
;rearchive_reports_in_past_last_n_months =
;rearchive_reports_in_past_exclude_segments = 1

; Disable OPTIMIZE TABLE statement which can create dead-locks
; and prevent MySQL backups
enable_sql_optimize_queries = 0

; Enable Matomo application logging to both file and screen
[log]
log_writers[] = "file"
log_writers[] = "screen"

; Matomo logs (WARN, ERROR) are written in matomo/tmp/logs/matomo.log
logger_file_path = tmp/logs/matomo.log

[CustomReports]
custom_reports_max_execution_time = 2700
custom_reports_disabled_dimensions = "CoreHome.VisitLastActionDate"

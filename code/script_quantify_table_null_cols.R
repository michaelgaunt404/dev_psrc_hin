#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
# This is script quantifies NYCDOT DB database tables
#
# By mike gaunt, michael.gaunt@wsp.com
#
# README [[insert brief readme here]]
#-------- [[insert brief readme here]]
#
# please use 80 character margins
#
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#library set-up=================================================================
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#content in this section should be removed if in production - ok for dev
library(gauntlet)

pkgs = c(tibble, tidyverse, lubridate, data.table, reactable
         ,here, DBI, odbc, RPostgres, RPostgreSQL, crosstalk)

package_load(pkgs)


#connection set up==============================================================
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
dbconn = DBIdbConnect(
  RPostgresPostgres(),
  dbname = nycdot_dbsd,
  host = '10.120.118.41',
  port = '5432',
  password = g9@S1Epy,
  user = nycdot_dbsd_user,
)

#tables=========================================================================
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
tables = DBIdbListTables(dbconn)  %%  
  sort() %% 
  .[!str_detect(., temp_)]

table_attributes = tables %%
  .[!str_detect(., yellow_streets)] %%
  # .[str_detect(., fataldmv_sanctionswc_accident_)] %%
  sort() %% 
  map_df(~{
    message(str_glue(Quering database for {.x} attributes))
    tryCatch({
      query = str_glue(Select  from {.x} limit 2;)
      info_item = dbSendQuery(dbconn, query)
      table_info = dbColumnInfo(info_item) %%
        mutate(table = .x
               ,record_count = DBIdbGetQuery(dbconn, str_glue(Select count() as count from {.x};))[[1]]) %%  
        select(name, everything())
    }, error = function(e) {
      # Handle specific error types
      if (inherits(e, zero_division_error)) {
        print(Error  issue)
      }
    }) 
  })

fuzzy_attribute_matching = table_attributes %%  
  mutate(present = T
         ,name = str_to_lower(name)) %% 
  filter(str_detect(table, fatal_) 
           str_detect(table, wc_accident)  
           table == dmv_sanctions 
           table == nypd_b_summons_historic 
           # table == lion 
           table == roster_decoder 
           table == v_street_name_aliases 
           table == vdata_camera_and_parking_violations 
           ) %% 
  select(name, table) %%
  arrange(table) %% 
  mutate(present = T) %% 
  # filter(name == accident_date_wid) %% 
  pivot_wider(names_from = table, values_from = present) %%
  rowwise() %%
  mutate(col_present_sum = sum(c_across(fatal_crashwc_accident_victim_f), na.rm = T)) %%
  ungroup() %%  
  filter(col_present_sum != 0) %% 
  arrange(desc(col_present_sum)) 

# fuzzy_attribute_matching %% 
#   filter(name == accident_date_wid)

fuzzy_attribute_matching_tbl = fuzzy_attribute_matching %% 
  reactable(columns = list(
    name = colDef(
      sticky = left,
      # Add a right border style to visually distinguish the sticky column
      style = list(borderRight = 1px solid #eee),
      headerStyle = list(borderRight = 1px solid #eee)
    )), defaultPageSize = 1000, filterable = TRUE, height = 700, width = 1500
    ,striped = T, highlight = T, bordered = F, fullWidth = T
    ,wrap = FALSE, resizable = TRUE, compact = T)

#quantifying nulls==============================================================
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
database_table_nulls = 
  tables[str_detect(tables, fatalwc_nypd_b_dmv_)] %%  
  sort() %% 
  map_df(~{
    message(str_glue(Querying for {.x}))
    query = str_glue(Select  from {.x} limit 2;)
    
    col_names = dbGetQuery(dbconn, query) %% 
      colnames()
    
    sql_cases = str_glue('Sum (CASE WHEN {col_names} IS NULL THEN 1 ELSE 0 END) AS {str_replace_all(col_names,  , _)}_null_tally') 
    
    query_null_counts = paste0(Select count() as count_row, , paste0(sql_cases, collapse = ,),  from , .x)
    
    temp = dbGetQuery(dbconn, query_null_counts) %% 
      mutate(table = .x)
    
    temp %% 
      pivot_longer(cols = !c(table, count_row), names_to = cols, values_to = null_count) %% 
      mutate(null_pct = 100dgt1(null_countcount_row)) %% 
      select(table, cols, starts_with(null), everything()) %%  
      arrange(desc(null_pct))
  }) %% 
  mutate(cols = str_remove_all(cols, _null_tally))

database_table_nulls_sh = SharedData$new(database_table_nulls )

crsstlk_tble_1 = bscols(
  widths = c(3, 6, 12)
  ,filter_select(id_table, Table Select , database_table_nulls_sh, ~table, multiple = T)
  ,filter_slider(id_null_pct, Col Null Pct , database_table_nulls_sh, ~null_pct, step = 10)
  ,database_table_nulls_sh %%  
    reactable(defaultPageSize = 1000, filterable = TRUE, heigh = 700
               ,striped = T, highlight = T, bordered = F, fullWidth = T
               ,wrap = FALSE, resizable = TRUE, compact = T)
)

###by_year======================================================================
items = list(
  c(fatal_crash, AC_Date)
  ,c(fatal_vehicle, AC_Date)
  ,c(fatal_victim, AC_Date)
  ,c(wc_accident_f, ACCIDENT_DT)
  ,c(wc_accident_vehicle_f, ACCIDENT_DT)
  ,c(wc_accident_victim_f, ACCIDENT_DT)
) %% 
  map(function(x) {
    message(str_glue(Querying for {x[1]}))
    query = str_glue(Select  from {x[1]} limit 2;)
    
    col_names = dbGetQuery(dbconn, query) %% 
      colnames()
    
    sql_cases = str_glue('Sum (CASE WHEN {col_names} IS NULL THEN 1 ELSE 0 END) AS {str_replace_all(col_names,  , _)}_null_tally') %% 
      paste0(collapse = ,)
    query_null_counts = str_glue('Select {x[2]} as date_att, count() as count_row, {sql_cases} from {x[1]} group by {x[2]}')
    temp = dbGetQuery(dbconn, query_null_counts) %% 
      mutate(table = x[1])
  })

processed_year_nulls = items %% 
  map(~{
    .x %%  
      mutate(year = date_att %% 
               as.character() %% 
               parse_date_time(orders = c(%Y, %Y-%d-%m, %Y-%m-%d)) %%  
               as_date() %% 
               year()) %% 
      select(!c(date_att)) %% 
      group_by(table, year) %% 
      mutate(across(everything(), as.numeric)) %% 
      summarise(across(everything(), sum)) %% 
      ungroup() %% 
      pivot_longer(cols = !c(table, count_row, year), names_to = cols, values_to = null_count) %%
      mutate(null_pct = 100dgt1(null_countcount_row)) %%
      mutate(cols = str_remove_all(cols, _null_tally)) %% 
      select(table, cols, starts_with(null), everything()) %%
      arrange(desc(null_pct)) %%
      group_by(cols) %%
      mutate(sum_null = sum(null_pct, na.rm = T)) %%
      ungroup() %% 
      # filter(sum_null != 0) %% #change if you do not want to see all
      arrange(sum_null) %% 
      mutate(cols = fct_inorder(cols)) %% 
      mutate(cols = fct_reorder(cols, sum_null,  .fun = sum))
  }) 

processed_year_nulls_plots = processed_year_nulls %% 
  map(~{
    tmp_plot = .x%% 
      filter(year  1980 & year  2023 ) %% 
      ggplot() + 
      geom_tile(aes(year, cols, fill = null_pct)) + 
      labs(y = )
    
    plotlyggplotly(tmp_plot)
  })


###end_special_case=================================================================

# database_table_booleans = c(fatal_vehicle, fatal_victim) %%  
#   sort() %% 
#   map_df(~{
#     query = str_glue(Select  from {.x} limit 2;)
#     info_item = dbSendQuery(dbconn, query) 
#     table_info = dbColumnInfo(info_item)
#     
#     col_names = table_info %% 
#       filter(type == logical) %%  
#       pull(name) 
#     
#     #might want to throw in a group by FID in here because we probably 
#     ####want number of say out of total accidents the number of which had a DWI invoolved
#     sql_cases = 
#       c(str_glue('Sum (CASE WHEN {col_names} IS TRUE THEN 1 ELSE 0 END) AS {str_replace_all(col_names,  , _)}_isTrue')
#         ,str_glue('Sum (CASE WHEN {col_names} IS FALSE THEN 1 ELSE 0 END) AS {str_replace_all(col_names,  , _)}_isFalse')
#         ,str_glue('Sum (CASE WHEN {col_names} IS NULL THEN 1 ELSE 0 END) AS {str_replace_all(col_names,  , _)}_isNull')) %% 
#       paste0(., collapse = ,)
#     
#     query_bool_counts = paste0(Select FID, count() as count_row, 
#                                ,sql_cases
#                                , into temp_yolo_5,  from , .x,  group by FID)
#     
#     dbSendQuery(dbconn, query_bool_counts) 
#     
#     temp = dbGetQuery(dbconn, Select  from temp_yolo_5) %% 
#       mutate(table = .x)
#     
#     temp %% 
#       pivot_longer(cols = !c(table, count_row), names_to = cols, values_to = count) %% 
#       separate(col = cols, into = c(cols, bool_value), sep = _is) %% 
#       pivot_wider(names_from = bool_value, values_from = count, names_prefix = bool_value) %% 
#       mutate(leakage_rate = 100((bool_valuetrue + bool_valuefalse + bool_valuenull)count_row-1)) %%  
#       select(table, cols, starts_with(bool), everything())
#   })


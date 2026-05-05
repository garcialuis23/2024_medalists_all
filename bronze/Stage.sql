CREATE OR REPLACE STAGE BRONZE_DB.PUBLIC.NATO_RAW_STAGE
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' 
SKIP_HEADER = 1 NULL_IF = ('', 'NULL', '-'));


-- ============================================================
-- BRONZE_DB.PUBLIC.NATO_COUNTRY_STATS
-- Fuente: NATO_1_Country_Stats.csv
-- ============================================================
CREATE OR REPLACE TABLE BRONZE_DB.PUBLIC.NATO_COUNTRY_STATS (
    Record_ID                   VARCHAR,
    Country                     VARCHAR,
    ISO_Code                    VARCHAR,
    Join_Year                   VARCHAR,
    Years_In_NATO               VARCHAR,
    Founding_Member             VARCHAR,
    Nuclear_Sharing             VARCHAR,
    Region                      VARCHAR,
    Capital                     VARCHAR,
    Area_km2                    VARCHAR,
    Government_Type             VARCHAR,
    Alliance_Role               VARCHAR,
    Year                        VARCHAR,
    Population_M                VARCHAR,
    GDP_Billion_USD             VARCHAR,
    GDP_Per_Capita_USD          VARCHAR,
    Inflation_Rate_Pct          VARCHAR,
    Unemployment_Rate_Pct       VARCHAR,
    Defense_Budget_Billion_USD  VARCHAR,
    Defense_GDP_Percent         VARCHAR,
    Meets_2_Percent_Target      VARCHAR,
    Active_Military_Personnel   VARCHAR,
    Reserve_Personnel           VARCHAR,
    Total_Military_Personnel    VARCHAR,
    NATO_Contribution_Rank      VARCHAR,
    Interoperability_Score      VARCHAR,
    Training_Exercises_Per_Year VARCHAR,
    _source_file                VARCHAR,
    _loaded_at                  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================
-- BRONZE_DB.PUBLIC.NATO_EQUIPMENT_INVENTORY
-- Fuente: NATO_2_Equipment_Inventory.csv
-- ============================================================
CREATE OR REPLACE TABLE BRONZE_DB.PUBLIC.NATO_EQUIPMENT_INVENTORY (
    Record_ID               VARCHAR,
    Country                 VARCHAR,
    ISO_Code                VARCHAR,
    Join_Year               VARCHAR,
    Founding_Member         VARCHAR,
    Nuclear_Sharing         VARCHAR,
    Region                  VARCHAR,
    Capital                 VARCHAR,
    Equipment_Type          VARCHAR,
    Equipment_Category      VARCHAR,
    Domain                  VARCHAR,
    Notable_Models          VARCHAR,
    Units_Count             VARCHAR,
    Operational_Status      VARCHAR,
    Condition               VARCHAR,
    Year_Acquired           VARCHAR,
    Equipment_Age_Years     VARCHAR,
    Unit_Cost_M_USD         VARCHAR,
    Total_Value_M_USD       VARCHAR,
    Country_of_Origin       VARCHAR,
    NATO_Standardized       VARCHAR,
    Interoperable           VARCHAR,
    Last_Maintenance_Year   VARCHAR,
    Next_Upgrade_Due        VARCHAR,
    Combat_Ready_Pct        VARCHAR,
    _source_file            VARCHAR,
    _loaded_at              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================
-- BRONZE_DB.PUBLIC.NATO_OPERATIONS_MISSIONS
-- Fuente: NATO_3_Operations_Missions.csv
-- ============================================================
CREATE OR REPLACE TABLE BRONZE_DB.PUBLIC.NATO_OPERATIONS_MISSIONS (
    Record_ID                   VARCHAR,
    Mission_Name                VARCHAR,
    Mission_Type                VARCHAR,
    Lead_Country                VARCHAR,
    Lead_ISO_Code               VARCHAR,
    Lead_Country_Region         VARCHAR,
    Operation_Location          VARCHAR,
    Operation_Region            VARCHAR,
    Threat_Level                VARCHAR,
    Command_HQ                  VARCHAR,
    Operation_Start_Year        VARCHAR,
    Operation_End_Year          VARCHAR,
    Duration_Years              VARCHAR,
    Mission_Phase               VARCHAR,
    Troops_Deployed             VARCHAR,
    Air_Assets_Deployed         VARCHAR,
    Naval_Assets_Deployed       VARCHAR,
    Casualties                  VARCHAR,
    Casualties_Rate_Pct         VARCHAR,
    Mission_Cost_M_USD          VARCHAR,
    Cost_Per_Soldier_USD        VARCHAR,
    Contributing_Countries_Count VARCHAR,
    NATO_Led                    VARCHAR,
    UN_Mandate                  VARCHAR,
    Mission_Outcome             VARCHAR,
    Mission_Status              VARCHAR,
    Classification              VARCHAR,
    Media_Coverage              VARCHAR,
    Public_Support_Pct          VARCHAR,
    After_Action_Report         VARCHAR,
    _source_file                VARCHAR,
    _loaded_at                  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================
-- BRONZE_DB.PUBLIC.NATO_MISSION_PARTICIPANTS
-- Fuente: NATO_4_Mission_Participants.csv
-- ============================================================
CREATE OR REPLACE TABLE BRONZE_DB.PUBLIC.NATO_MISSION_PARTICIPANTS (
    Participant_ID              VARCHAR,
    Mission_Record_ID           VARCHAR,
    Mission_Name                VARCHAR,
    Country                     VARCHAR,
    ISO_Code                    VARCHAR,
    Participation_Role          VARCHAR,
    Troops_Contributed          VARCHAR,
    Air_Assets_Contributed      VARCHAR,
    Naval_Assets_Contributed    VARCHAR,
    Contribution_Pct            VARCHAR,
    _source_file                VARCHAR,
    _loaded_at                  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);
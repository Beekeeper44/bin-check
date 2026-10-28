WITH bin_items AS (
    -- Cards
    SELECT
        c.ID                                          AS ITEM_ID,
        'Card'                                        AS CATEGORY,
        c.STORAGE_BIN_ID                              AS BIN_ID,
        c.STORAGE_BIN_SLOT                            AS SLOT,
        TO_VARCHAR(c.NUMBER)                          AS AC_NUMBER,
        c.STATUS                                      AS ITEM_STATUS,
        c.PLAYER_NAME                                 AS TITLE,
        c.SET_NAME                                    AS SUBTITLE,
        c.GRADING_COMPANY,
        TO_VARCHAR(c.OVERALL)                         AS GRADE,
        c.FRONT_SLAB_PICTURE_URL                      AS FRONT_IMAGE,
        'https://admin.arenaclub.com/cards/' || c.ID  AS ITEM_URL
    FROM APP_PROD.ADMIN.CARDS c
    WHERE NOT COALESCE(c._SNOWFLAKE_DELETED, FALSE)
      AND c.STORAGE_BIN_ID IS NOT NULL

    UNION ALL

    -- Watches
    SELECT
        wo.ITEM_ID, 'Watch', wo.BIN_ID, NULL, NULL, wo.STATUS,
        NULL, NULL, NULL, NULL, NULL, NULL
    FROM APP_PROD.ADMIN.WATCH_OPERATIONS wo
    WHERE NOT COALESCE(wo._SNOWFLAKE_DELETED, FALSE)
      AND wo.BIN_ID IS NOT NULL
      AND wo.STATUS = 'vaulted'
),
final AS (
    SELECT
        b.ID                                                        AS BIN_NUMBER,
        b.NAME                                                      AS BIN_NAME,
        bi.CATEGORY,
        bi.SLOT,
        COALESCE(bi.AC_NUMBER, TO_VARCHAR(i.NUMBER))                AS ITEM_NUMBER,
        TRIM(COALESCE(u.FIRST_NAME, '') || ' ' || COALESCE(u.LAST_NAME, '')) AS OWNER_NAME,
        COALESCE(TRIM(COALESCE(u.FIRST_NAME, '') || ' ' || COALESCE(u.LAST_NAME, '')) ILIKE '%arena%club%', FALSE) AS IS_ARENA_CLUB,
        bi.ITEM_STATUS,
        COALESCE(bi.TITLE, bi.CATEGORY)                             AS TITLE,
        bi.SUBTITLE,
        bi.GRADING_COMPANY,
        bi.GRADE,
        bi.FRONT_IMAGE,
        bi.ITEM_URL
    FROM bin_items bi
    JOIN APP_PROD.ADMIN.BINS b
      ON b.ID = bi.BIN_ID
     AND NOT COALESCE(b._SNOWFLAKE_DELETED, FALSE)
    LEFT JOIN APP_PROD.PUBLIC.ITEMS i
      ON i.ID = bi.ITEM_ID
     AND NOT COALESCE(i._SNOWFLAKE_DELETED, FALSE)
    LEFT JOIN APP_PROD.PUBLIC.USERS u
      ON u.ID = i.USER_ID
     AND NOT COALESCE(u._SNOWFLAKE_DELETED, FALSE)
)
SELECT *
FROM final
WHERE 1 = 1
  [[ AND BIN_NUMBER BETWEEN
         TRY_TO_NUMBER(SPLIT_PART(REPLACE({{bins}}, ' ', ''), '-', 1))
     AND COALESCE(
         TRY_TO_NUMBER(NULLIF(SPLIT_PART(REPLACE({{bins}}, ' ', ''), '-', 2), '')),
         TRY_TO_NUMBER(SPLIT_PART(REPLACE({{bins}}, ' ', ''), '-', 1))) ]]
  [[ AND IS_ARENA_CLUB = (LOWER({{arena_club}}) = 'true') ]]
  [[ AND CATEGORY = {{category}} ]]
ORDER BY BIN_NUMBER, CATEGORY, SLOT

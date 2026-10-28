WITH bin_items AS (
    -- Cards: everything admin has in a bin
    SELECT c.ID AS ITEM_ID, 'Card' AS CATEGORY, c.STORAGE_BIN_ID AS BIN_ID,
           c.STORAGE_BIN_SLOT AS SLOT,
           c.STATUS = 'pending_external_checkout' AS IS_PENDING_CHECKOUT
    FROM APP_PROD.ADMIN.CARDS c
    WHERE NOT COALESCE(c._SNOWFLAKE_DELETED, FALSE)
      AND c.STORAGE_BIN_ID IS NOT NULL

    UNION ALL

    -- Watches
    SELECT wo.ITEM_ID, 'Watch', wo.BIN_ID, NULL, FALSE
    FROM APP_PROD.ADMIN.WATCH_OPERATIONS wo
    WHERE NOT COALESCE(wo._SNOWFLAKE_DELETED, FALSE)
      AND wo.BIN_ID IS NOT NULL
      AND wo.STATUS = 'vaulted'
),
owned AS (
    SELECT
        bi.CATEGORY,
        bi.BIN_ID,
        bi.SLOT,
        bi.IS_PENDING_CHECKOUT,
        COALESCE(TRIM(COALESCE(u.FIRST_NAME, '') || ' ' || COALESCE(u.LAST_NAME, '')) ILIKE '%arena%club%', FALSE) AS IS_AC
    FROM bin_items bi
    LEFT JOIN APP_PROD.PUBLIC.ITEMS i
      ON i.ID = bi.ITEM_ID
     AND NOT COALESCE(i._SNOWFLAKE_DELETED, FALSE)
    LEFT JOIN APP_PROD.PUBLIC.USERS u
      ON u.ID = i.USER_ID
     AND NOT COALESCE(u._SNOWFLAKE_DELETED, FALSE)
),
final AS (
    SELECT
        b.ID                                                  AS BIN_NUMBER,
        'https://admin.arenaclub.com/i/' || b.ID              AS BIN_URL,
        b.NAME                                                AS BIN_NAME,
        COUNT_IF(o.IS_AC     AND o.CATEGORY = 'Card')         AS ARENA_CLUB_CARDS,
        LISTAGG(IFF(o.IS_AC AND o.CATEGORY = 'Card', TO_VARCHAR(o.SLOT), NULL), ', ')
            WITHIN GROUP (ORDER BY o.SLOT)                    AS ARENA_CLUB_SLOTS,
        COUNT_IF(o.IS_AC     AND o.CATEGORY = 'Watch')        AS ARENA_CLUB_WATCHES,
        COUNT_IF(NOT o.IS_AC AND o.CATEGORY = 'Card')         AS NON_ARENA_CLUB_CARDS,
        LISTAGG(IFF(NOT o.IS_AC AND o.CATEGORY = 'Card', TO_VARCHAR(o.SLOT), NULL), ', ')
            WITHIN GROUP (ORDER BY o.SLOT)                    AS NON_ARENA_CLUB_SLOTS,
        COUNT_IF(NOT o.IS_AC AND o.CATEGORY = 'Watch')        AS NON_ARENA_CLUB_WATCHES,
        COUNT_IF(o.IS_PENDING_CHECKOUT)                       AS PENDING_CHECKOUT_CARDS,
        COUNT(*)                                              AS TOTAL_ITEMS_IN_BIN
    FROM owned o
    JOIN APP_PROD.ADMIN.BINS b
      ON b.ID = o.BIN_ID
     AND NOT COALESCE(b._SNOWFLAKE_DELETED, FALSE)
    GROUP BY b.ID, b.NAME
)
SELECT *
FROM final
WHERE 1 = 1
  [[ AND BIN_NUMBER BETWEEN
         TRY_TO_NUMBER(SPLIT_PART(REPLACE({{bins}}, ' ', ''), '-', 1))
     AND COALESCE(
         TRY_TO_NUMBER(NULLIF(SPLIT_PART(REPLACE({{bins}}, ' ', ''), '-', 2), '')),
         TRY_TO_NUMBER(SPLIT_PART(REPLACE({{bins}}, ' ', ''), '-', 1))) ]]
  [[ AND BIN_NAME ILIKE {{bin_name}} ]]
ORDER BY BIN_NUMBER

# Bin Check

Bin-by-bin view of what's in the vault: slot map per bin (Arena Club vs other owners), counts, and a card drawer with front images.

## Setup
1. In Metabase, save `sql/bins.sql` and `sql/items.sql` as two native questions (Snowflake APP_PROD).
   - bins: text variables `bins`, `bin_name` (not required)
   - items: text variables `bins`, `arena_club`, `category` (not required)
2. Vercel env vars:
   - `METABASE_HOST`  defaults to https://arena-club.metabaseapp.com
   - `METABASE_API_KEY`
   - `BINS_QUESTION_ID`   defaults to 46003
   - `ITEMS_QUESTION_ID`  defaults to 46004
3. Deploy. Open `public/index.html` locally (or add `?demo`) to see demo data.

The items view also reads the columns from Alan's own items question:
FRONT_IMAGE, BIN_NUMBER, SLOT, ITEM_ID, CATEGORY, OWNER ('Arena Club' / 'Customer'),
IS_PENDING_CHECKOUT, PLAYER_NAME, SET_NAME, GRADING_COMPANY, OVERALL, EST_VALUE.
The question needs a text variable `bins` so the app can load one bin at a time.

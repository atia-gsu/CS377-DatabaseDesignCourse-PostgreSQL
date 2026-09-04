--- Count all the pokemon cards in each set
SELECT set_name, COUNT(*) AS card_count 
FROM cards c 
JOIN sets s ON c.set_id = s.set_id 
GROUP BY set_name 
ORDER BY card_count DESC;

--- Returns all artists
SELECT artist FROM artists;

--- Returns 10 artists
SELECT artist FROM artists LIMIT 10;

--- Finds total card value by each artist
--- IMPLEMENTED VIEW to showcase
CREATE VIEW artist_total_value AS
SELECT artist, SUM(market_price) AS total_value 
FROM cards c
JOIN artists a ON c.artist_id = a.artist_id
JOIN variants v ON c.card_id = v.card_id
JOIN card_prices cp ON v.variant_id = cp.variant_id
GROUP BY a.artist
ORDER BY total_value DESC;

SELECT * FROM artist_total_value;

--- Get's total card value for each artist but return only those who have total values between $1000 and $5000
WITH artist_value AS(
SELECT artist, SUM(market_price) AS total_value FROM cards c
JOIN artists a ON c.artist_id = a.artist_id
JOIN sets s ON c.set_id = s.set_id
JOIN variants v ON c.card_id = v.card_id
JOIN card_prices cp ON v.variant_id = cp.variant_id
GROUP BY artist
)
SELECT artist, total_value FROM artist_value WHERE total_value >= 1000 AND total_value <= 5000 ORDER BY total_value;



--- Get total value of cards for each set
SELECT set_name, SUM(market_price) AS total_value FROM cards c 
JOIN sets s ON c.set_id = s.set_id 
JOIN variants v ON c.card_id = v.card_id
JOIN card_prices cp ON v.variant_id = cp.variant_id
GROUP BY set_name ORDER BY total_value DESC;

--- Same as code above but adds LIMIT 5 to get the 5 sets with the most total value
SELECT set_name, SUM(market_price) AS total_value FROM cards c 
JOIN sets s ON c.set_id = s.set_id 
JOIN variants v ON c.card_id = v.card_id
JOIN card_prices cp ON v.variant_id = cp.variant_id
GROUP BY set_name ORDER BY total_value DESC LIMIT 5;

--- Gets all names of different Pokemon done by a single artist
SELECT DISTINCT name FROM cards c 
JOIN artists a ON c.artist_id = a.artist_id 
WHERE artist = 'Yuka Morii';

--- Gets information for all Rayquaza cards
SELECT * FROM cards WHERE name LIKE 'Rayquaza%';

--- Returns all Rayquaza cards that have the VMAX variant
SELECT * FROM cards WHERE name LIKE 'Rayquaza_VMAX';

--- Function that returns all cards of a single Pokemon including the set, variant, and its price.
--- In this example, I wanted to get all Rayquaza cards in existence.
CREATE OR REPLACE FUNCTION search_pokemon(pokemon_name TEXT)
RETURNS TABLE (
    name TEXT,
    set_name TEXT,
    variant TEXT,
    market_price NUMERIC
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.name,
        s.set_name,
        v.variant,
        cp.market_price
    FROM cards c
    JOIN sets s ON c.set_id = s.set_id
    JOIN variants v ON c.card_id = v.card_id 
    JOIN card_prices cp ON v.variant_id = cp.variant_id
    WHERE c.name LIKE pokemon_name || '%';
END;
$$ LANGUAGE plpgsql;

SELECT * FROM search_pokemon('Rayquaza');

--- Gets the most expensive card for each set. Used a CTE to also include the name of the Pokemon.
WITH ranked AS (
    SELECT
        s.set_name,
        c.name,
        v.variant,
        cp.market_price,
        ROW_NUMBER() OVER (
            PARTITION BY s.set_name 
            ORDER BY cp.market_price DESC
        ) AS rank
    FROM cards c
    JOIN sets s ON c.set_id = s.set_id 
    JOIN variants v ON c.card_id = v.card_id
    JOIN card_prices cp ON v.variant_id = cp.variant_id
)
SELECT set_name, name, variant, market_price
FROM ranked
WHERE rank = 1
ORDER BY market_price DESC;


--- Check to see if there is an error with data
--- Looks like the set Paldea Evolved is incomplete as values for a lot of cards don't make sense
SELECT set_name, name, market_price 
FROM cards c
JOIN sets s ON c.set_id = s.set_id
JOIN variants v ON c.card_id = v.card_id
JOIN card_prices cp ON v.variant_id = cp.variant_id
WHERE set_name = 'Paldea Evolved';

--- Black Bolt data looks much more accurate
SELECT set_name, name, market_price 
FROM cards c
JOIN sets s ON c.set_id = s.set_id
JOIN variants v ON c.card_id = v.card_id
JOIN card_prices cp ON v.variant_id = cp.variant_id
WHERE set_name = 'Black Bolt';


--- Shows price difference between most and least expensive variants of a card
SELECT
name,
set_name,
MAX(market_price), MIN(market_price), MAX(market_price) - MIN(market_price) AS price_range
FROM cards c
JOIN sets s ON c.set_id = s.set_id
JOIN variants v ON c.card_id = v.card_id
JOIN card_prices cp ON v.variant_id = cp.variant_id
GROUP BY c.name, set_name
ORDER BY price_range DESC;

--- Gets card price average > 50
--- uses HAVING
SELECT
c.name,
AVG(market_price) AS avg_price
FROM cards c
JOIN variants v ON c.card_id = v.card_id
JOIN card_prices cp ON v.variant_id = cp.variant_id
GROUP BY c.name
HAVING AVG(cp.market_price) > 50;


--- INNER JOIN where it only gets cards with their set names
SELECT name, set_name FROM cards c INNER JOIN sets s ON c.set_id = s.set_id;

-- LEFT JOIN
-- SHOWS ALL CARDS EVEN IF THEY DON'T HAVE VARIANTS
SELECT name, variant FROM cards c LEFT JOIN variants v ON c.card_id = v.card_id;

-- RIGHT JOIN
-- SHOWS ALL VARIANTS EVEN IF CARD IS MISSING
SELECT name, variant FROM cards c RIGHT JOIN variants v ON c.card_id = v.card_id;

-- CROSS JOIN
-- PAIR EVERY CARD WITH THEIR RARITY
SELECT name, rarity FROM cards c CROSS JOIN rarities r;


--- CONCAT_WS to combine name, variant, and the price into a string separated by /
SELECT CONCAT_WS(' / ', name, variant, market_price) AS card_info
FROM cards c
JOIN variants v ON c.card_id = v.card_id
JOIN card_prices cp ON v.variant_id = cp.variant_id;

--- Returns info of all Pokemon cards that has 4 letters
SELECT * FROM cards WHERE LENGTH(name) = 4;

--- Returns name of Pokemon but reversed
SELECT name, REVERSE(name) AS name_reversed FROM cards;

--- Replaces reverseHolofoil to Reverse Holofoil for Pokemon with this variant
SELECT name, variant, REPLACE(variant, 'reverseHolofoil', 'Reverse Holofoil') AS new_variant 
FROM cards c 
JOIN variants v ON c.card_id = v.card_id; 

--- Procedure that actually updates reverseHolofoil to Reverse Holofoil to make the wording more clean
CREATE OR REPLACE PROCEDURE fix_reverse_holofoil()
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE variants
    SET variant = 'Reverse Holofoil'
    WHERE variant = 'reverseHolofoil';
END;
$$;

CALL fix_reverse_holofoil();
---NOTE: all the data variants that changed go to the back of table so run this below to see everything in order
SELECT * FROM variants ORDER BY variant_id;


--- Get's first two and last two letters of Pokemon card name
SELECT name, LEFT(name, 2) AS first_two, RIGHT(name, 2) AS last_two FROM cards;

--- Same thing as code above but adds - between the shortened names
SELECT name, CONCAT_WS('-', LEFT(name, 2), RIGHT(name, 2)) AS shortened_name FROM cards;

--- Another way to get the first two and last two letters of a Pokemon card name using SUBSTR instead of LEFT and RIGHT
SELECT name, CONCAT_WS('-', SUBSTR(name, 1, 2), SUBSTR(name, LENGTH(name) - 1)) AS shortened_name FROM cards;

--- Returns all pokemon with EX by using POSITION
SELECT name FROM cards WHERE POSITION('EX' IN name) > 0;


--- Function where user can type set and get the most expensive cards by entering a count of how many they want to see within a set
CREATE OR REPLACE FUNCTION get_top_cards_by_set(
    set_input VARCHAR(50),
    n INT
)
RETURNS TABLE (
name TEXT,
variant TEXT,
market_price NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
    c.name,
    v.variant,
    cp.market_price
    FROM cards c
    JOIN sets s ON c.set_id = s.set_id
    JOIN variants v ON c.card_id = v.card_id
    JOIN card_prices cp ON v.variant_id = cp.variant_id
    WHERE s.set_name = set_input
    ORDER BY cp.market_price DESC
    LIMIT n;
END;
$$;

SELECT * FROM get_top_cards_by_set('Destined Rivals', 7);


--- Gets most expensive card out of every other card
--- Can't use GROUP BY if I want one row only
SELECT name, set_name, variant, market_price AS most_expensive_price 
FROM cards c 
JOIN sets s ON c.set_id = s.set_id
JOIN variants v ON c.card_id = v.card_id
JOIN card_prices cp ON v.variant_id = cp.variant_id
ORDER BY cp.market_price DESC LIMIT 1;

--- Get's total sum of price of cards for a particular set (in this case Lost Origin)
--- Could have made this a function
SELECT set_name, SUM(market_price) as total_value
FROM cards c 
JOIN sets s ON c.set_id = s.set_id
JOIN variants v ON c.card_id = v.card_id
JOIN card_prices cp ON v.variant_id = cp.variant_id
WHERE set_name = 'Lost Origin' GROUP BY set_name;
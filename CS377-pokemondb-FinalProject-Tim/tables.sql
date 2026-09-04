--- QUERIES TO CREATE THE TABLES
CREATE TABLE cards (
	card_id TEXT PRIMARY KEY,
	name TEXT NOT NULL,
	supertype TEXT,
	subtypes TEXT,
	set_id TEXT REFERENCES sets(set_id),
	artist_id INT REFERENCES artists(artist_id),
	rarity_id INT REFERENCES rarities(rarity_id)
);

CREATE TABLE sets (
	set_id TEXT PRIMARY KEY,
	set_name TEXT NOT NULL,
	release_date DATE
);

CREATE TABLE artists (
	artist_id SERIAL PRIMARY KEY,
	artist TEXT UNIQUE NOT NULL
);

CREATE TABLE rarities (
	rarity_id SERIAL PRIMARY KEY,
	rarity TEXT UNIQUE NOT NULL
);

CREATE TABLE variants (
	variant_id SERIAL PRIMARY KEY,
	card_id TEXT REFERENCES cards(card_id),
	variant TEXT NOT NULL
);

CREATE TABLE card_prices (
	price_id SERIAL PRIMARY KEY,
	variant_id INT REFERENCES variants(variant_id),
	market_price NUMERIC(10,2) NOT NULL,
	date_observed DATE NOT NULL
);
-------------------------------


--- QUERIES TO INSERT SOME DATA INTO TABLES
--- NOTE: THIS ISN'T COMPLETE DATA AND I DELETED AFTERWARDS BECAUSE THIS WAS A TEST RUN
INSERT INTO sets(set_id, set_name, release_date)
VALUES
('hgss4', 'HS-Triumphant', '2010-11-03'),
('xy5', 'Primal Clash', '2015-02-04'),
('pl1', 'Platinum', '2009-02-11');

INSERT INTO artists (artist)
VALUES
('Kagermaru Himeno'),
('Midori Harada'),
('Atsuko Nishida');

INSERT INTO rarities (rarity)
VALUES
('Rare Holo'),
('Common');

INSERT INTO cards(card_id, name, supertype, subtypes, set_id, artist_id, rarity_id)
VALUES
('hgss4-1', 'Aggron', 'Pokémon', 'Stage 2', 'hgss4', 1, 1),
('xy5-1', 'Weedle', 'Pokémon', 'Basic', 'xy5', 2, 2),
('pl1-1', 'Ampharos', 'Pokémon', 'Stage 2', 'pl1', 3, 1);

INSERT INTO variants (card_id, variant)
VALUES
('hgss4-1', 'holofoil'),
('hgss4-1', 'reverseHolofoil'),
('xy5-1', 'normal'),
('xy5-1', 'reverseHolofoil'),
('pl1-1', 'holofoil');

INSERT INTO card_prices (variant_id, market_price, date_observed)
VALUES
(1, 5.99, '2026-01-25'),
(2, 4.73, '2026-01-25'),
(3, 0.12, '2026-01-25'),
(4, 0.49, '2026-01-25'),
(5, 31.16, '2026-01-25');
-------------------------------



--- Temporarily created table called `poke_data` to effectively import all dataset entries from `pokemon_data - Sheet1.csv` 
--- into this table so I could easily insert the right data into the other tables.
CREATE TABLE poke_data (
	card_id TEXT,
	name TEXT,
	variant TEXT,
	rarity TEXT,
	supertype TEXT,
	subtypes TEXT,
	set_id TEXT,
	set_name TEXT,
	release_date DATE,
	artist TEXT,
	market_price NUMERIC(10,2),
	date_observed DATE
);

--- REAL data I inserted from table poke_data to other tables
INSERT INTO sets(set_id, set_name, release_date)
SELECT DISTINCT set_id, set_name, release_date
FROM poke_data
ON CONFLICT (set_id) DO NOTHING;

INSERT INTO artists (artist)
SELECT DISTINCT artist FROM poke_data
WHERE artist IS NOT NULL;

INSERT INTO rarities (rarity)
SELECT DISTINCT rarity FROM poke_data
WHERE rarity is NOT NULL;

INSERT INTO cards ( card_id, name, supertype, subtypes, set_id, artist_id, rarity_id)
SELECT DISTINCT
    pd.card_id,
    pd.name,
    pd.supertype,
    pd.subtypes,
    pd.set_id,
    a.artist_id,
    r.rarity_id
FROM poke_data pd
LEFT JOIN artists a ON pd.artist = a.artist
LEFT JOIN rarities r ON pd.rarity = r.rarity;

INSERT INTO variants (card_id, variant)
SELECT DiSTINCT card_id, variant FROM poke_data;

INSERT INTO card_prices (variant_id, market_price, date_observed)
SELECT
    v.variant_id,
    pd.market_price,
    pd.date_observed
FROM poke_data pd
JOIN variants v ON pd.card_id = v.card_id AND pd.variant = v.variant;
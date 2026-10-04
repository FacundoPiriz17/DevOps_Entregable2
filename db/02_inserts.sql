BEGIN;

INSERT INTO usuario (email, nombre, pais, activo, fecha_registro) VALUES
('facundo@playhub.test',  'Facundo',  'Uruguay', TRUE, '2026-08-05'),
('santiago@playhub.test', 'Santiago', 'Uruguay', TRUE, '2026-08-06'),
('agostina@playhub.test', 'Agostina', 'Uruguay', TRUE, '2026-08-07'),
('agustin@playhub.test',  'Agustín',  'Uruguay', TRUE, '2026-08-08');

-- Todos los usuarios usan la contraseña: PlayHub123

INSERT INTO login (email, contrasenia) VALUES
('facundo@playhub.test',  '$2y$10$R3kU7pEExfg12gokXHAp8Oqni2RvjN.g48I7m.0P/r9WneXh.ZT86'),
('santiago@playhub.test', '$2y$10$R3kU7pEExfg12gokXHAp8Oqni2RvjN.g48I7m.0P/r9WneXh.ZT86'),
('agostina@playhub.test', '$2y$10$R3kU7pEExfg12gokXHAp8Oqni2RvjN.g48I7m.0P/r9WneXh.ZT86'),
('agustin@playhub.test',  '$2y$10$R3kU7pEExfg12gokXHAp8Oqni2RvjN.g48I7m.0P/r9WneXh.ZT86');

INSERT INTO administrador (email_administrador) VALUES
('facundo@playhub.test'),
('santiago@playhub.test');

INSERT INTO general (email_general) VALUES
('agostina@playhub.test'),
('agustin@playhub.test');

INSERT INTO categoria (nombre, tipo) VALUES
('Acción',          'genero'),
('RPG',             'genero'),
('JRPG',            'genero'),
('Aventura',        'genero'),
('Plataformas',     'genero'),
('Roguelike',       'genero'),
('Estrategia',      'genero'),
('Soulslike',       'etiqueta'),
('Mundo abierto',   'etiqueta'),
('Por turnos',      'etiqueta'),
('Indie',           'etiqueta'),
('Metroidvania',    'etiqueta'),
('Difícil',         'etiqueta'),
('Un jugador',      'etiqueta'),
('Familiar',        'etiqueta'),
('Narrativo',       'etiqueta'),
('Exploración',     'etiqueta');

INSERT INTO juego
    (nombre, descripcion, precio, fecha_lanzamiento, estudio, estado, admin_registra, fecha_registro)
VALUES
(
    'Dark Souls III',
    'RPG de acción ambientado en un mundo oscuro y desafiante, centrado en exploración y combates exigentes.',
    59.99,
    '2016-03-24',
    'FromSoftware',
    'publicado',
    'facundo@playhub.test',
    '2026-08-15'
),
(
    'Spyro Reignited Trilogy',
    'Colección que reúne las tres primeras aventuras de Spyro completamente recreadas.',
    39.99,
    '2018-11-13',
    'Toys for Bob',
    'publicado',
    'santiago@playhub.test',
    '2026-08-15'
),
(
    'Persona 5',
    'JRPG centrado en los Ladrones Fantasma, con exploración de mazmorras, combate por turnos y vida social.',
    49.99,
    '2016-09-15',
    'P-Studio',
    'publicado',
    'facundo@playhub.test',
    '2026-08-15'
),
(
    'Hades',
    'Roguelike de acción donde Zagreus intenta escapar del Inframundo mientras obtiene poderes de los dioses.',
    24.99,
    '2020-09-17',
    'Supergiant Games',
    'publicado',
    'santiago@playhub.test',
    '2026-08-16'
),
(
    'Hollow Knight',
    'Aventura de acción y exploración en el reino subterráneo de Hallownest.',
    14.99,
    '2017-02-24',
    'Team Cherry',
    'publicado',
    'facundo@playhub.test',
    '2026-08-16'
),
(
    'The Legend of Zelda: Breath of the Wild',
    'Aventura de mundo abierto centrada en la exploración libre del reino de Hyrule.',
    59.99,
    '2017-03-03',
    'Nintendo EPD',
    'pausado',
    'santiago@playhub.test',
    '2026-08-17'
),
(
    'Super Mario Odyssey',
    'Juego de plataformas tridimensional protagonizado por Mario y Cappy en distintos reinos.',
    59.99,
    '2017-10-27',
    'Nintendo EPD',
    'publicado',
    'facundo@playhub.test',
    '2026-08-17'
),
(
    'Baldur''s Gate 3',
    'RPG basado en Dungeons & Dragons con decisiones narrativas, exploración y combate táctico por turnos.',
    59.99,
    '2023-08-03',
    'Larian Studios',
    'publicado',
    'santiago@playhub.test',
    '2026-08-18'
),
(
    'NieR: Automata',
    'RPG de acción protagonizado por androides en una guerra por recuperar la Tierra.',
    39.99,
    '2017-02-23',
    'PlatinumGames',
    'publicado',
    'facundo@playhub.test',
    '2026-08-18'
),
(
    'Celeste',
    'Juego de plataformas de precisión sobre el ascenso de Madeline a la montaña Celeste.',
    19.99,
    '2018-01-25',
    'Extremely OK Games',
    'publicado',
    'santiago@playhub.test',
    '2026-08-19'
),
(
    'Bloodborne',
    'RPG de acción gótico ambientado en la ciudad de Yharnam.',
    39.99,
    '2015-03-24',
    'FromSoftware',
    'retirado',
    'facundo@playhub.test',
    '2026-08-19'
),
(
    'Grand Theft Auto VI',
    'Juego de acción y mundo abierto ambientado en el estado de Leonida y Vice City.',
    79.99,
    '2026-11-19',
    'Rockstar Games',
    'preventa',
    'santiago@playhub.test',
    '2026-08-20'
);

INSERT INTO imagen (url, texto_alternativo) VALUES
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/374320/library_600x900_2x.jpg', 'Portada de Dark Souls III'),
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/374320/library_hero.jpg', 'Banner de Dark Souls III'),
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/996580/library_600x900_2x.jpg', 'Portada de Spyro Reignited Trilogy'),
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/996580/library_hero.jpg', 'Banner de Spyro Reignited Trilogy'),
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1687950/library_600x900_2x.jpg', 'Portada de Persona 5'),
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1687950/library_hero.jpg', 'Banner de Persona 5'),
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1145360/library_600x900_2x.jpg', 'Portada de Hades'),
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1145360/library_hero.jpg', 'Banner de Hades'),
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/367520/library_600x900_2x.jpg', 'Portada de Hollow Knight'),
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/367520/library_hero.jpg', 'Banner de Hollow Knight'),
('https://pisces.bbystatic.com/image2/BestBuy_US/images/products/5721/5721500_sd.jpg', 'Portada de The Legend of Zelda: Breath of the Wild'),
('https://assets.nintendo.com/image/upload/ar_16:9,c_lpad,w_1240/b_white/f_auto/q_auto/ncom/software/switch/70010000000025/7137262b5a64d921e193653f8aa0b722925abc5680380ca0e18a5cfd91697f58', 'Banner de The Legend of Zelda: Breath of the Wild'),
('https://images.launchbox-app.com/5bd97f0b-c784-4cf0-87e1-2b10f36637fa.jpg', 'Portada de Super Mario Odyssey'),
('https://assets.nintendo.com/image/upload/ar_16:9,c_lpad,w_1240/b_white/f_auto/q_auto/store/software/switch/70010000001130/c42553b4fd0312c31e70ec7468c6c9bccd739f340152925b9600631f2d29f8b5', 'Banner de Super Mario Odyssey'),
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1086940/library_600x900_2x.jpg', 'Portada de Baldur''s Gate 3'),
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1086940/library_hero.jpg', 'Banner de Baldur''s Gate 3'),
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/524220/library_600x900_2x.jpg', 'Portada de NieR: Automata'),
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/524220/library_hero.jpg', 'Banner de NieR: Automata'),
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/504230/library_600x900_2x.jpg', 'Portada de Celeste'),
('https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/504230/library_hero.jpg', 'Banner de Celeste'),
('https://cdn2.steamgriddb.com/grid/5445c5fc4461b6d81db6224a6c28be2b.png', 'Portada de Bloodborne'),
('https://wallpaperset.com/w/full/3/b/0/250799.jpg', 'Banner de Bloodborne'),
('https://media-rockstargames-com.akamaized.net/mfe6/prod/__common/img/090acda789de843d56780aa60c1f7056.jpg', 'Portada de Grand Theft Auto VI'),
('https://www.rockstargames.com/VI/-/opengraph-image.jpg?opengraph-image.0t8ty~nlmxq2s.jpg', 'Banner de Grand Theft Auto VI'),
('https://commons.wikimedia.org/wiki/Special:FilePath/Fromsoftware_logo.svg', 'Logo de FromSoftware');

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'portada'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/374320/library_600x900_2x.jpg'
WHERE j.nombre = 'Dark Souls III';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'banner'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/374320/library_hero.jpg'
WHERE j.nombre = 'Dark Souls III';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'portada'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/996580/library_600x900_2x.jpg'
WHERE j.nombre = 'Spyro Reignited Trilogy';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'banner'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/996580/library_hero.jpg'
WHERE j.nombre = 'Spyro Reignited Trilogy';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'portada'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1687950/library_600x900_2x.jpg'
WHERE j.nombre = 'Persona 5';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'banner'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1687950/library_hero.jpg'
WHERE j.nombre = 'Persona 5';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'portada'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1145360/library_600x900_2x.jpg'
WHERE j.nombre = 'Hades';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'banner'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1145360/library_hero.jpg'
WHERE j.nombre = 'Hades';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'portada'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/367520/library_600x900_2x.jpg'
WHERE j.nombre = 'Hollow Knight';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'banner'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/367520/library_hero.jpg'
WHERE j.nombre = 'Hollow Knight';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'portada'
FROM juego j
JOIN imagen i ON i.url = 'https://pisces.bbystatic.com/image2/BestBuy_US/images/products/5721/5721500_sd.jpg'
WHERE j.nombre = 'The Legend of Zelda: Breath of the Wild';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'banner'
FROM juego j
JOIN imagen i ON i.url = 'https://assets.nintendo.com/image/upload/ar_16:9,c_lpad,w_1240/b_white/f_auto/q_auto/ncom/software/switch/70010000000025/7137262b5a64d921e193653f8aa0b722925abc5680380ca0e18a5cfd91697f58'
WHERE j.nombre = 'The Legend of Zelda: Breath of the Wild';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'portada'
FROM juego j
JOIN imagen i ON i.url = 'https://images.launchbox-app.com/5bd97f0b-c784-4cf0-87e1-2b10f36637fa.jpg'
WHERE j.nombre = 'Super Mario Odyssey';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'banner'
FROM juego j
JOIN imagen i ON i.url = 'https://assets.nintendo.com/image/upload/ar_16:9,c_lpad,w_1240/b_white/f_auto/q_auto/store/software/switch/70010000001130/c42553b4fd0312c31e70ec7468c6c9bccd739f340152925b9600631f2d29f8b5'
WHERE j.nombre = 'Super Mario Odyssey';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'portada'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1086940/library_600x900_2x.jpg'
WHERE j.nombre = 'Baldur''s Gate 3';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'banner'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/1086940/library_hero.jpg'
WHERE j.nombre = 'Baldur''s Gate 3';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'portada'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/524220/library_600x900_2x.jpg'
WHERE j.nombre = 'NieR: Automata';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'banner'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/524220/library_hero.jpg'
WHERE j.nombre = 'NieR: Automata';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'portada'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/504230/library_600x900_2x.jpg'
WHERE j.nombre = 'Celeste';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'banner'
FROM juego j
JOIN imagen i ON i.url = 'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/504230/library_hero.jpg'
WHERE j.nombre = 'Celeste';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'portada'
FROM juego j
JOIN imagen i ON i.url = 'https://cdn2.steamgriddb.com/grid/5445c5fc4461b6d81db6224a6c28be2b.png'
WHERE j.nombre = 'Bloodborne';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'banner'
FROM juego j
JOIN imagen i ON i.url = 'https://wallpaperset.com/w/full/3/b/0/250799.jpg'
WHERE j.nombre = 'Bloodborne';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'portada'
FROM juego j
JOIN imagen i ON i.url = 'https://media-rockstargames-com.akamaized.net/mfe6/prod/__common/img/090acda789de843d56780aa60c1f7056.jpg'
WHERE j.nombre = 'Grand Theft Auto VI';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'banner'
FROM juego j
JOIN imagen i ON i.url = 'https://www.rockstargames.com/VI/-/opengraph-image.jpg?opengraph-image.0t8ty~nlmxq2s.jpg'
WHERE j.nombre = 'Grand Theft Auto VI';

INSERT INTO juego_imagen (identificador_juego, id_imagen, tipo)
SELECT j.identificador, i.id_imagen, 'galeria'
FROM juego j
JOIN imagen i ON i.url = 'https://commons.wikimedia.org/wiki/Special:FilePath/Fromsoftware_logo.svg'
WHERE j.nombre IN ('Dark Souls III', 'Bloodborne');

INSERT INTO juego_categoria (identificador_juego, identificador_categoria)
SELECT j.identificador, c.identificador
FROM juego j
CROSS JOIN categoria c
WHERE j.nombre = 'Dark Souls III'
  AND c.nombre IN ('Acción', 'RPG', 'Soulslike', 'Difícil', 'Un jugador');

INSERT INTO juego_categoria (identificador_juego, identificador_categoria)
SELECT j.identificador, c.identificador
FROM juego j
CROSS JOIN categoria c
WHERE j.nombre = 'Spyro Reignited Trilogy'
  AND c.nombre IN ('Aventura', 'Plataformas', 'Familiar', 'Exploración');

INSERT INTO juego_categoria (identificador_juego, identificador_categoria)
SELECT j.identificador, c.identificador
FROM juego j
CROSS JOIN categoria c
WHERE j.nombre = 'Persona 5'
  AND c.nombre IN ('RPG', 'JRPG', 'Por turnos', 'Narrativo', 'Un jugador');

INSERT INTO juego_categoria (identificador_juego, identificador_categoria)
SELECT j.identificador, c.identificador
FROM juego j
CROSS JOIN categoria c
WHERE j.nombre = 'Hades'
  AND c.nombre IN ('Acción', 'Roguelike', 'Indie', 'Difícil', 'Un jugador');

INSERT INTO juego_categoria (identificador_juego, identificador_categoria)
SELECT j.identificador, c.identificador
FROM juego j
CROSS JOIN categoria c
WHERE j.nombre = 'Hollow Knight'
  AND c.nombre IN ('Acción', 'Aventura', 'Indie', 'Metroidvania', 'Difícil', 'Exploración');

INSERT INTO juego_categoria (identificador_juego, identificador_categoria)
SELECT j.identificador, c.identificador
FROM juego j
CROSS JOIN categoria c
WHERE j.nombre = 'The Legend of Zelda: Breath of the Wild'
  AND c.nombre IN ('Acción', 'Aventura', 'Mundo abierto', 'Exploración', 'Un jugador');

INSERT INTO juego_categoria (identificador_juego, identificador_categoria)
SELECT j.identificador, c.identificador
FROM juego j
CROSS JOIN categoria c
WHERE j.nombre = 'Super Mario Odyssey'
  AND c.nombre IN ('Aventura', 'Plataformas', 'Familiar', 'Exploración');

INSERT INTO juego_categoria (identificador_juego, identificador_categoria)
SELECT j.identificador, c.identificador
FROM juego j
CROSS JOIN categoria c
WHERE j.nombre = 'Baldur''s Gate 3'
  AND c.nombre IN ('RPG', 'Estrategia', 'Por turnos', 'Narrativo');

INSERT INTO juego_categoria (identificador_juego, identificador_categoria)
SELECT j.identificador, c.identificador
FROM juego j
CROSS JOIN categoria c
WHERE j.nombre = 'NieR: Automata'
  AND c.nombre IN ('Acción', 'RPG', 'Narrativo', 'Un jugador');

INSERT INTO juego_categoria (identificador_juego, identificador_categoria)
SELECT j.identificador, c.identificador
FROM juego j
CROSS JOIN categoria c
WHERE j.nombre = 'Celeste'
  AND c.nombre IN ('Plataformas', 'Indie', 'Difícil', 'Un jugador');

INSERT INTO juego_categoria (identificador_juego, identificador_categoria)
SELECT j.identificador, c.identificador
FROM juego j
CROSS JOIN categoria c
WHERE j.nombre = 'Bloodborne'
  AND c.nombre IN ('Acción', 'RPG', 'Soulslike', 'Difícil', 'Un jugador');

INSERT INTO juego_categoria (identificador_juego, identificador_categoria)
SELECT j.identificador, c.identificador
FROM juego j
CROSS JOIN categoria c
WHERE j.nombre = 'Grand Theft Auto VI'
  AND c.nombre IN ('Acción', 'Aventura', 'Mundo abierto', 'Un jugador');

INSERT INTO biblioteca (identificador_juego, email_general, fecha_compra, es_favorito)
SELECT identificador, 'agostina@playhub.test', '2026-08-16', TRUE
FROM juego
WHERE nombre = 'Dark Souls III';

INSERT INTO biblioteca (identificador_juego, email_general, fecha_compra, es_favorito)
SELECT identificador, 'agostina@playhub.test', '2026-08-17', TRUE
FROM juego
WHERE nombre = 'Persona 5';

INSERT INTO biblioteca (identificador_juego, email_general, fecha_compra, es_favorito)
SELECT identificador, 'agostina@playhub.test', '2026-08-18', FALSE
FROM juego
WHERE nombre = 'Hades';

INSERT INTO biblioteca (identificador_juego, email_general, fecha_compra, es_favorito)
SELECT identificador, 'agustin@playhub.test', '2026-08-16', TRUE
FROM juego
WHERE nombre = 'Spyro Reignited Trilogy';

INSERT INTO biblioteca (identificador_juego, email_general, fecha_compra, es_favorito)
SELECT identificador, 'agustin@playhub.test', '2026-08-19', FALSE
FROM juego
WHERE nombre = 'Celeste';

INSERT INTO biblioteca (identificador_juego, email_general, fecha_compra, es_favorito)
SELECT identificador, 'agustin@playhub.test', '2026-08-20', TRUE
FROM juego
WHERE nombre = 'Baldur''s Gate 3';

INSERT INTO biblioteca (identificador_juego, email_general, fecha_compra, es_favorito)
SELECT identificador, 'agostina@playhub.test', '2026-08-01', TRUE
FROM juego
WHERE nombre = 'Bloodborne';

INSERT INTO deseados (identificador_juego, email_general, fecha_agregado)
SELECT identificador, 'agostina@playhub.test', '2026-08-22'
FROM juego
WHERE nombre = 'Spyro Reignited Trilogy';

INSERT INTO deseados (identificador_juego, email_general, fecha_agregado)
SELECT identificador, 'agostina@playhub.test', '2026-08-23'
FROM juego
WHERE nombre = 'Baldur''s Gate 3';

INSERT INTO deseados (identificador_juego, email_general, fecha_agregado)
SELECT identificador, 'agustin@playhub.test', '2026-08-23'
FROM juego
WHERE nombre = 'Persona 5';

INSERT INTO deseados (identificador_juego, email_general, fecha_agregado)
SELECT identificador, 'agustin@playhub.test', '2026-08-24'
FROM juego
WHERE nombre = 'Hollow Knight';

INSERT INTO deseados (identificador_juego, email_general, fecha_agregado)
SELECT identificador, 'agustin@playhub.test', '2026-08-25'
FROM juego
WHERE nombre = 'Grand Theft Auto VI';

INSERT INTO carrito (identificador_juego, email_general)
SELECT identificador, 'agostina@playhub.test'
FROM juego
WHERE nombre = 'Super Mario Odyssey';

INSERT INTO carrito (identificador_juego, email_general)
SELECT identificador, 'agostina@playhub.test'
FROM juego
WHERE nombre = 'Hades';

INSERT INTO carrito (identificador_juego, email_general)
SELECT identificador, 'agustin@playhub.test'
FROM juego
WHERE nombre = 'Dark Souls III';

INSERT INTO carrito (identificador_juego, email_general)
SELECT identificador, 'agustin@playhub.test'
FROM juego
WHERE nombre = 'Persona 5';

COMMIT;

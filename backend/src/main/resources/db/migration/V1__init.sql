CREATE TYPE estado_juego AS ENUM ('publicado', 'pausado', 'preventa', 'retirado');
CREATE TYPE tipo_imagen AS ENUM ('portada', 'banner', 'galeria');
CREATE TYPE tipo_categoria AS ENUM ('genero', 'etiqueta');

CREATE TABLE usuario (
    email TEXT PRIMARY KEY,
    nombre TEXT NOT NULL,
    pais TEXT NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_registro DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE login (
    email        TEXT PRIMARY KEY,
    contrasenia  TEXT NOT NULL,

    CONSTRAINT fk_login_usuario
        FOREIGN KEY (email)
        REFERENCES usuario(email)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);


CREATE TABLE general (
    email_general TEXT PRIMARY KEY,

    CONSTRAINT fk_general_usuario
        FOREIGN KEY (email_general)
        REFERENCES usuario(email)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE administrador (
    email_administrador TEXT PRIMARY KEY,

    CONSTRAINT fk_administrador_usuario
        FOREIGN KEY (email_administrador)
        REFERENCES usuario(email)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);


CREATE TABLE juego (
    identificador       BIGSERIAL PRIMARY KEY,
    nombre              TEXT NOT NULL,
    descripcion         TEXT NOT NULL,
    precio              NUMERIC(10, 2) NOT NULL,
    fecha_lanzamiento   DATE NOT NULL,
    estudio             TEXT NOT NULL,
    estado              estado_juego NOT NULL DEFAULT 'publicado',
    admin_registra      TEXT NOT NULL,
    fecha_registro      DATE NOT NULL DEFAULT CURRENT_DATE,

    CONSTRAINT fk_juego_administrador
        FOREIGN KEY (admin_registra)
        REFERENCES administrador(email_administrador)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT ck_juego_precio
        CHECK (precio >= 0)
);

CREATE TABLE Imagen (
    id_imagen           BIGSERIAL PRIMARY KEY,
    url                 TEXT NOT NULL,
    texto_alternativo   TEXT
);

CREATE TABLE juego_imagen (
    identificador_juego BIGINT NOT NULL,
    id_imagen           BIGINT NOT NULL,
    tipo                tipo_imagen NOT NULL DEFAULT 'galeria',

    CONSTRAINT pk_juego_imagen
        PRIMARY KEY (identificador_juego, id_imagen),

    CONSTRAINT fk_juego_imagen_juego
        FOREIGN KEY (identificador_juego)
        REFERENCES juego(identificador)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_juego_imagen_imagen
        FOREIGN KEY (id_imagen)
        REFERENCES imagen(id_imagen)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE Categoria (
    identificador BIGSERIAL PRIMARY KEY,
    nombre        TEXT NOT NULL,
    tipo          tipo_categoria NOT NULL,

    CONSTRAINT uq_categoria_nombre_tipo
        UNIQUE (nombre, tipo)
);

CREATE TABLE juego_categoria (
    identificador_juego     BIGINT NOT NULL,
    identificador_categoria BIGINT NOT NULL,

    CONSTRAINT pk_juego_categoria
        PRIMARY KEY (identificador_juego, identificador_categoria),

    CONSTRAINT fk_juego_categoria_juego
        FOREIGN KEY (identificador_juego)
        REFERENCES juego(identificador)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_juego_categoria_categoria
        FOREIGN KEY (identificador_categoria)
        REFERENCES categoria(identificador)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE biblioteca (
    identificador_juego BIGINT NOT NULL,
    email_general       TEXT NOT NULL,
    fecha_compra        DATE NOT NULL DEFAULT CURRENT_DATE,
    es_favorito         BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT pk_biblioteca
        PRIMARY KEY (identificador_juego, email_general),

    CONSTRAINT fk_biblioteca_juego
        FOREIGN KEY (identificador_juego)
        REFERENCES juego(identificador)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_biblioteca_general
        FOREIGN KEY (email_general)
        REFERENCES general(email_general)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE carrito (
    identificador_juego BIGINT NOT NULL,
    email_general       TEXT NOT NULL,

    CONSTRAINT pk_carrito
        PRIMARY KEY (identificador_juego, email_general),

    CONSTRAINT fk_carrito_juego
        FOREIGN KEY (identificador_juego)
        REFERENCES juego(identificador)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_carrito_general
        FOREIGN KEY (email_general)
        REFERENCES general(email_general)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

CREATE TABLE deseados (
    identificador_juego BIGINT NOT NULL,
    email_general       TEXT NOT NULL,
    fecha_agregado      DATE NOT NULL DEFAULT CURRENT_DATE,

    CONSTRAINT pk_deseados
        PRIMARY KEY (identificador_juego, email_general),

    CONSTRAINT fk_deseados_juego
        FOREIGN KEY (identificador_juego)
        REFERENCES juego(identificador)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_deseados_general
        FOREIGN KEY (email_general)
        REFERENCES general(email_general)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);

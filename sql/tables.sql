-- Создание последовательности для ID Категорий и Изделий.
-- Используем отдельную последовательность, ведь по примеру ID должен быть обще-инкрементным.
CREATE SEQUENCE public."Category_Product_id_seq";
ALTER SEQUENCE public."Category_Product_id_seq" OWNER TO postgres;


-- Создание таблицы "Единицы измерения".
CREATE TABLE public."Measure"
(
    id serial NOT NULL,
    name character varying(64) NOT NULL,        -- Название единицы измерения.
    name_short character varying(16) NOT NULL,  -- Сокращение единицы измерения.
    CONSTRAINT pk_measure_id PRIMARY KEY (id),
    CONSTRAINT uq_measure_name_short UNIQUE (name_short)
);
ALTER TABLE IF EXISTS public."Measure" OWNER to postgres;


-- Создание таблицы "Категории".
CREATE TABLE public."Category"
(
    id integer NOT NULL DEFAULT nextval('"Category_Product_id_seq"'::regclass),
    parent_id integer,                     -- ID родительской категории.
    is_enum boolean DEFAULT false,         -- Категория <>: 1 - перечисления, 0 - изделия.
    name character varying(128) NOT NULL,  -- Название категории.
    measure_id integer DEFAULT 1,          -- ID единицы измерения.
    CONSTRAINT pk_category_id PRIMARY KEY (id),
    CONSTRAINT uq_category_name UNIQUE (name),
    CONSTRAINT fk_category_measure_id FOREIGN KEY (measure_id)
        REFERENCES public."Measure" (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE SET DEFAULT,
    CONSTRAINT fk_category_parent_id FOREIGN KEY (parent_id)
        REFERENCES public."Category" (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);
ALTER TABLE IF EXISTS public."Category" OWNER to postgres;


-- Создание таблицы "Изделия".
CREATE TABLE public."Product"
(
    id integer NOT NULL DEFAULT nextval('"Category_Product_id_seq"'),
    category_id integer NOT NULL,         -- ID категории.
    name character varying(128) NOT NULL, -- Название изделия.
    amount integer DEFAULT 0,             -- Количество.
    price numeric(11, 2) DEFAULT 0,       -- Цена.
    CONSTRAINT pk_product_id PRIMARY KEY (id),
    CONSTRAINT fk_product_category_id FOREIGN KEY (category_id)
        REFERENCES public."Category" (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT uq_product_name_in_category UNIQUE (category_id, name)
);
ALTER TABLE IF EXISTS public."Product" OWNER to postgres;


-- Создание таблицы "Значения Перечисления".
CREATE TABLE public."EnumValue"
(
    id serial NOT NULL,
    category_id integer NOT NULL,       -- ID категории.
    code character varying(8) NOT NULL, -- Код (ключ) значения.
    priority smallint DEFAULT 0,        -- Приоритет для упорядочивания.
    value_str character varying(128),   -- Строковое значение.
    value_int integer,                  -- Целое значение.
    value_real real,                    -- Вещественное значение.
    value_path character varying(128),  -- Путь к файлу.
    CONSTRAINT pk_enum_value_id PRIMARY KEY (id),
    CONSTRAINT fk_enum_value_category_id FOREIGN KEY (category_id)
        REFERENCES public."Category" (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT uq_enum_value_category_code UNIQUE (category_id, code),
    CONSTRAINT ck_enum_value_value_filled CHECK (
        -- Одно и только одно поле значения должно быть заполнено.
        CASE WHEN value_str  IS NULL THEN 0 ELSE 1 END +
        CASE WHEN value_int  IS NULL THEN 0 ELSE 1 END +
        CASE WHEN value_real IS NULL THEN 0 ELSE 1 END +
        CASE WHEN value_path IS NULL THEN 0 ELSE 1 END = 1
    )
);
ALTER TABLE IF EXISTS public."EnumValue" OWNER to postgres;


-- Создание таблицы "Параметры".
CREATE TABLE public."Parameter" (
    id serial NOT NULL,
    measure_id integer,                        -- ID единицы измерения.
    data_type character varying(4) NOT NULL,   -- Тип параметра.
    enum_id integer,                           -- ID перечисления (если dtype=enum).
    name character varying(128) NOT NULL,      -- Название параметра.
    name_short character varying(8) NOT NULL,  -- Сокращение параметра.
    min_val integer,                           -- Минимальное значение (если dtype~numeric).
    max_val integer,                           -- Максимальное значение (если dtype~numeric).
    CONSTRAINT pk_param_id PRIMARY KEY (id),
    CONSTRAINT fk_param_unit_id FOREIGN KEY (measure_id)
        REFERENCES public."Measure" (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_param_enum_id FOREIGN KEY (enum_id)
        REFERENCES public."Category" (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT uq_param_code UNIQUE (name_short),
    CONSTRAINT ck_param_dtype CHECK (
        -- Типы параметров.
        data_type IN ('int', 'str', 'real', 'enum', 'path')
    ),
    CONSTRAINT ck_param_not_null_enum_if_selected CHECK (
        -- Если dtype=enum, то enum_id не может быть NULL.
        (data_type = 'enum' AND enum_id IS NOT NULL) OR
        (data_type != 'enum' AND enum_id IS NULL)
    )
);
ALTER TABLE IF EXISTS public."Parameter" OWNER to postgres;


-- Создание таблицы "Параметры Изделий".
CREATE TABLE public."ParameterValue"
(
    id serial NOT NULL,
    product_id integer,                -- ID изделия (если параметр изделия).
    category_id integer,               -- ID категории (если параметр категории).
    param_id integer NOT NULL,         -- ID параметра.
    value_enum integer,                -- ID значения перечисления (если dtype=enum).
    value_str character varying(128),  -- Строковое значение.
    value_int integer,                 -- Целое значение.
    value_real real,                   -- Вещественное значение.
    value_path character varying(128), -- Путь к файлу.
    CONSTRAINT pk_param_value_id PRIMARY KEY (id),
    CONSTRAINT fk_param_value_product_id FOREIGN KEY (product_id)
        REFERENCES public."Product" (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_param_value_category_id FOREIGN KEY (category_id)
        REFERENCES public."Category" (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_param_value_param_id FOREIGN KEY (param_id)
        REFERENCES public."Parameter" (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT fk_param_value_enum_value FOREIGN KEY (value_enum)
        REFERENCES public."EnumValue" (id) MATCH SIMPLE
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT uq_param_value_param_product UNIQUE (param_id, product_id),
    CONSTRAINT uq_param_value_param_category UNIQUE (param_id, category_id),
    CONSTRAINT ck_param_value_product_or_category CHECK (
        -- Одно и только одно поле родительского объекта должно быть заполнено.
        CASE WHEN product_id IS NULL THEN 0 ELSE 1 END +
        CASE WHEN category_id IS NULL THEN 0 ELSE 1 END = 1
    ),
    CONSTRAINT ck_param_value_value_filled CHECK (
        -- Одно и только одно поле значения должно быть заполнено.
        CASE WHEN value_enum IS NULL THEN 0 ELSE 1 END +
        CASE WHEN value_str  IS NULL THEN 0 ELSE 1 END +
        CASE WHEN value_int  IS NULL THEN 0 ELSE 1 END +
        CASE WHEN value_real IS NULL THEN 0 ELSE 1 END +
        CASE WHEN value_path IS NULL THEN 0 ELSE 1 END = 1
    )
    -- Проверка типов данных проводится в триггерах (есть под-запросы).
);
ALTER TABLE IF EXISTS public."ParameterValue" OWNER to postgres;


-- Создание таблицы "Агрегатор".
CREATE TABLE "ParameterAggregate" (
    parent_param_id INTEGER NOT NULL,
    param_id INTEGER NOT NULL,
    PRIMARY KEY (parent_param_id, param_id),
    FOREIGN KEY (parent_param_id) REFERENCES "Parameter"(id) ON DELETE CASCADE,
    FOREIGN KEY (param_id) REFERENCES "Parameter"(id) ON DELETE CASCADE,
    CONSTRAINT uq_param_aggregate_pair UNIQUE (parent_param_id, param_id)
);

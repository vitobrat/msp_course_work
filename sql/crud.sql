/* ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ */

-- Проверка наличия цикла в иерархии категории.
/* Проверяет наличие цикла в иерархии вставляемой категории.
    Вход:
        p_child_id (integer): ID вставляемой категории,
        p_parent_id (integer): ID родительской категории.
    Выход:
        void: Отсутствует.
    Эффекты:
        Вызывает ошибку при обнаружении цикла.
    Требования:
        Категории вставляемой и родительской категории должны быть различны.
*/
CREATE OR REPLACE FUNCTION check_category_cycle(
    p_child_id integer,
    p_parent_id integer
) RETURNS void AS
$$
DECLARE
    is_cycle boolean;
BEGIN
    IF p_child_id = p_parent_id THEN
        RAISE EXCEPTION 'Категория не может быть родителем самой себя';
    END IF;

    WITH RECURSIVE category_hierarchy AS (
        SELECT id, parent_id FROM "Category" WHERE id = p_parent_id
        UNION ALL
        SELECT c.id, c.parent_id
        FROM "Category" c
        JOIN category_hierarchy ch ON c.id = ch.parent_id
    )
    SELECT EXISTS (SELECT 1 FROM category_hierarchy WHERE id = p_child_id) INTO is_cycle;

    IF is_cycle THEN
        RAISE EXCEPTION 'Обнаружен цикл в иерархии категории';
    END IF;
END;
$$ LANGUAGE plpgsql;



/* ФУНКЦИИ СОЗДАНИЯ ЗАПИСЕЙ */

-- Создать новую запись в таблице Единицы измерения.
/* Добавляет новую запись в таблицу Единицы измерения, возвращает ID новой записи.
    Вход:
        p_name (character varying(64)): Название единицы измерения,
        p_name_short (character varying(16)): Сокращение единицы измерения.
    Выход:
        integer: ID новой записи.
    Эффекты:
        Добавление новой ЕИ в таблицу Единицы измерения,
        Вызов ошибки, если ЕИ с таким названием или сокращением уже существует,
        Возврат ID новой записи.
    Требования:
        ЕИ не должна ранее существовать.
*/
CREATE OR REPLACE FUNCTION create_measure(
    p_name character varying(64),
    p_name_short character varying(16)
) RETURNS integer AS
$$
DECLARE
    new_id integer;
BEGIN
    INSERT INTO "Measure" (name, name_short)
    VALUES (p_name, p_name_short)
    RETURNING id INTO new_id;

    RETURN new_id;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Единица измерения с таким названием или сокращением уже существует';
END;
$$ LANGUAGE plpgsql;

-- Создать новую запись в таблице Категории.
/* Добавляет новую запись в таблицу Категории, возвращает ID новой записи.
    Вход:
        p_name (character varying(128)): Название категории,
        p_parent_id (integer): ID родительской категории (необязательный),
        p_measure_id (integer): ID единицы измерения (по умолчанию 1 (штук)).
    Выход:
        integer: ID новой записи.
    Эффекты:
        Добавление новой Категории в таблицу Единицы измерения,
        Вызов ошибки, если родительской категории не существует,
        Вызов ошибки, если единицы измерения не существует,
        Вызов ошибки, если категория уже существует,
        Возврат ID новой записи.
    Требования:
        Родительская категория не должна ранее существовать,
        Единица измерения не должна ранее существовать,
        Категория не должна ранее существовать.
*/
CREATE OR REPLACE FUNCTION create_category(
    p_name character varying(128),
    p_parent_id integer DEFAULT NULL,
    p_measure_id integer DEFAULT 1,
    p_is_enum boolean DEFAULT false
) RETURNS integer AS
$$
DECLARE
    new_id integer;
    parent_is_enum boolean;
BEGIN
    -- Проверка родительской категории.
    IF p_parent_id IS NOT NULL THEN
        -- Должна существовать.
        IF NOT EXISTS (SELECT 1 FROM "Category" WHERE id = p_parent_id) THEN
            RAISE EXCEPTION 'Родительская категория с ID % не существует', p_parent_id;
        END IF;

        -- Статус "Перечисление?" должен совпадать.
        SELECT is_enum INTO parent_is_enum FROM "Category" WHERE id = p_parent_id;
        IF parent_is_enum != p_is_enum THEN
            RAISE EXCEPTION 'is_enum=(%) не совпадает с is_enum=(%) родителя', p_is_enum, parent_is_enum;
        END IF;
    END IF;

    -- Проверка существования единицы измерения.
    IF NOT EXISTS (SELECT 1 FROM "Measure" WHERE id = p_measure_id) THEN
        RAISE EXCEPTION 'Единица измерения с ID % не существует', p_measure_id;
    END IF;

    -- Вставка.
    INSERT INTO "Category" (parent_id, is_enum, name, measure_id)
    VALUES (p_parent_id, p_is_enum, p_name, p_measure_id)
    RETURNING id INTO new_id;

    RETURN new_id;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Категория с таким именем уже существует в данном родительском разделе';
END;
$$ LANGUAGE plpgsql;

-- Создать новую запись в таблице Изделия.
/* Добавляет новую запись в таблицу Изделия, возвращает ID новой записи.
    Вход:
        p_name (character varying(128)): Название изделия,
        p_category_id (integer): ID категории, в которую добавляется изделие.
    Выход:
        integer: ID новой записи.
    Эффекты:
        Добавление нового Изделия в таблицу Изделия,
        Вызов ошибки, если родительской категории не существует,
        Возврат ID новой записи.
    Требования:
        Родительская категория не должна ранее существовать,
*/
CREATE OR REPLACE FUNCTION create_product(
    p_name character varying(128),
    p_category_id integer,
    p_amount integer DEFAULT 0,
    p_price numeric(11, 2) DEFAULT 0
) RETURNS integer AS
$$
DECLARE
    new_id integer;
BEGIN
    -- Проверка существования категории.
    IF NOT EXISTS (SELECT 1 FROM "Category" WHERE id = p_category_id) THEN
        RAISE EXCEPTION 'Категория с ID % не существует', p_category_id;
    END IF;

    -- Вставка.
    INSERT INTO "Product" (name, category_id, amount, price)
    VALUES (p_name, p_category_id, p_amount, p_price)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ language plpgsql;

-- Создать новую запись в таблице Значения Перечисления.
/* Создаёт новую запись в таблице Значения Перечисления, возвращает ID новой записи.
    Вход:
        p_category_id (integer): ID категории, в которую добавляется параметр,
        p_code (character varying(128)): Код параметра,
        p_priority (integer): Приоритет (необязательный),
        value_<data_type> (тип): Значение параметра.
    Выход:
        integer: ID новой записи.
    Эффекты:
        Добавление нового значения Перечисления в таблицу,
        Вызов ошибки, если категория не существует,
        Вызов ошибки, если значение перечисления уже существует,
        Вызов ошибки, если неправильно указано значение,
        Возврат ID новой записи.
    Требования:
        Значение не должно ранее существовать,
        Категория Перечисления должна существовать,
        Категория Перечисления должна быть перечислением,
        Значение должно быть уникальным для данной категории,
        Значение должно быть валидным.
*/
CREATE OR REPLACE FUNCTION create_enum_value(
    p_category_id integer,
    p_code integer,
    p_priority integer DEFAULT 0,
    p_value_str character varying(128) DEFAULT NULL,
    p_value_int integer DEFAULT NULL,
    p_value_real real DEFAULT NULL,
    p_value_path character varying(128) DEFAULT NULL
) RETURNS integer AS
$$
DECLARE
    new_id integer;
    d_is_enum boolean;
BEGIN
    -- Проверка существования категории и её статуса перечисления.
    SELECT is_enum INTO d_is_enum FROM "Category" WHERE id = p_category_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Категория с ID % не существует', p_category_id;
    ELSIF NOT d_is_enum THEN
        RAISE EXCEPTION 'Категория с ID % не является категорией перечислений', p_category_id;
    END IF;

    -- Вставка.
    INSERT INTO "EnumValue" (category_id, code, priority,
                             value_str, value_int, value_real, value_path)
    VALUES (p_category_id, p_code, p_priority,
            p_value_str, p_value_int, p_value_real, p_value_path)
    RETURNING id INTO new_id;

    RETURN new_id;
EXCEPTION
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Код перечисления % уже существует в категории %', p_code, p_category_id;
END;
$$ LANGUAGE plpgsql;

-- Создать новую запись в таблице Параметры.
/* Добавляет новую запись в таблицу Параметров, возвращает ID новой записи.
    Вход:
        p_measure_id (integer): ID единицы измерения,
        p_data_type (character varying(4)): Тип данных параметра ('str', 'int', 'real', 'enum', 'path'),
        p_enum_id (integer, необязательно): ID категории-перечисления, если параметр типа "перечисление".
        p_name (character varying(128)): Полное название параметра,
        p_name_short (character varying(8)): Краткое название параметра,
        p_min_value (integer, необязательно): Минимальное значение числового параметра,
        p_max_value (integer, необязательно): Максимальное значение числового параметра,
    Выход:
        integer: ID новой записи.
    Эффекты:
        Добавление нового Параметра в таблицу Параметров,
        Вызов ошибки, если единица измерения или enum_id не существуют,
        Вызов ошибки, если нарушены условия типа данных,
        Возврат ID новой записи.
    Требования:
        Единица измерения должна существовать,
        Если тип данных 'enum', должен быть указан корректный enum_id.
*/
CREATE OR REPLACE FUNCTION create_parameter(
    p_measure_id integer,
    p_data_type character varying(4),
    p_name character varying(128),
    p_name_short character varying(8),
    p_enum_id integer DEFAULT NULL,
    p_min_value integer DEFAULT NULL,
    p_max_value integer DEFAULT NULL
) RETURNS integer AS
$$
DECLARE
    new_id integer;
BEGIN
    -- Проверка существования единицы измерения.
    IF NOT EXISTS (SELECT 1 FROM "Measure" WHERE id = p_measure_id) THEN
        RAISE EXCEPTION 'Единица измерения с ID % не существует', p_measure_id;
    END IF;

    -- Проверка корректности типа данных.
    IF p_data_type NOT IN ('str', 'int', 'real', 'enum', 'path') THEN
        RAISE EXCEPTION 'Некорректный тип данных параметра: %', p_data_type;
    END IF;

    -- Если тип данных enum, требуется наличие корректного enum_id.
    IF p_data_type = 'enum' THEN
        IF p_enum_id IS NULL THEN
            RAISE EXCEPTION 'Для параметра типа "enum" необходимо указать p_enum_id';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM "Category" WHERE id = p_enum_id AND is_enum = true) THEN
            RAISE EXCEPTION 'Категория с ID % не существует или не является перечислением', p_enum_id;
        END IF;
    END IF;

    -- Вставка.
    INSERT INTO "Parameter" (measure_id, data_type, enum_id,
                             name, name_short, min_val, max_val)
    VALUES (p_measure_id, p_data_type, p_enum_id,
            p_name, p_name_short, p_min_value, p_max_value)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- Создать новую запись в таблице Параметры Изделий.
/* Добавляет новую запись в таблицу Параметров Изделий (ParameterValue), возвращает ID новой записи.
    Вход:
        p_product_id (integer, необязательно): ID изделия,
        p_category_id (integer, необязательно): ID категории,
        p_param_id (integer): ID параметра,
        p_value_enum (integer, необязательно): Значение для типа "enum",
        p_value_str (character varying(128), необязательно): Строковое значение,
        p_value_int (integer, необязательно): Целочисленное значение,
        p_value_real (real, необязательно): Вещественное значение,
        p_value_path (character varying(128), необязательно): Путь к файлу.
    Выход:
        integer: ID новой записи.
    Эффекты:
        Добавление новой записи параметра,
        Проверка существования изделия/категории и параметра,
        Возврат ID новой записи.
    Требования:
        Должно быть заполнено ровно одно из полей product_id или category_id,
        Если тип данных 'enum', должен быть указан корректный enum_value,
        Должен быть заполнено значение соответствующего параметру типа данных.
*/
CREATE OR REPLACE FUNCTION create_parameter_value(
    p_param_id integer,
    p_product_id integer DEFAULT NULL,
    p_category_id integer DEFAULT NULL,
    p_value_enum integer DEFAULT NULL,
    p_value_str character varying(128) DEFAULT NULL,
    p_value_int integer DEFAULT NULL,
    p_value_real real DEFAULT NULL,
    p_value_path character varying(128) DEFAULT NULL
) RETURNS integer AS
$$
DECLARE
    new_id integer;
    param_dtype character varying(4);
BEGIN
    -- Проверка заполненности product_id или category_id.
    IF (p_product_id IS NULL AND p_category_id IS NULL) OR (p_product_id IS NOT NULL AND p_category_id IS NOT NULL) THEN
        RAISE EXCEPTION 'Должно быть указано ровно одно из product_id или category_id';
    END IF;

    -- Проверка существования параметра.
    SELECT data_type INTO param_dtype FROM "Parameter" WHERE id = p_param_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Параметр с ID % не существует', p_param_id;
    END IF;

    -- Проверка существования изделия или категории.
    IF p_product_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM "Product" WHERE id = p_product_id) THEN
        RAISE EXCEPTION 'Изделие с ID % не существует', p_product_id;
    END IF;
    IF p_category_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM "Category" WHERE id = p_category_id) THEN
        RAISE EXCEPTION 'Категория с ID % не существует', p_category_id;
    END IF;

    -- Вставка.
    INSERT INTO "ParameterValue" (param_id, product_id, category_id,
                                  value_enum, value_str, value_int, value_real, value_path)
    VALUES (p_param_id, p_product_id, p_category_id,
            p_value_enum::integer,
            p_value_str::character varying(128),
            p_value_int::integer,
            p_value_real::real,
            p_value_path::character varying(128))
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$ LANGUAGE plpgsql;



/* ФУНКЦИИ УДАЛЕНИЯ ЗАПИСЕЙ */

-- Удаление записи из таблицы Единицы измерения.
/* Удаляет существующую запись из таблицы Единицы измерения.
    Вход:
        p_id (integer): ID удаляемой записи.
    Выход:
        void: Отсутствует.
    Эффекты:
        Удаление записи из таблицы Единицы измерения,
        Вызов ошибки, если ЕИ не существует,
        Вызов ошибки, если ЕИ по умолчанию (id=1) не существует,
        Установка значения по умолчанию Категориям, использовавшим данную ЕИ.
    Требования:
        ЕИ должна существовать,
        ЕИ по умолчанию должна существовать,
*/
CREATE OR REPLACE FUNCTION delete_measure(
    p_id integer
) RETURNS void AS
$$
DECLARE
    is_used boolean;
BEGIN
    -- Проверка существования.
    IF NOT EXISTS (SELECT 1 FROM "Measure" WHERE id = p_id) THEN
        RAISE EXCEPTION 'Единица измерения с ID % не существует', p_id;
    END IF;

    -- Проверка существования ЕИ по умолчанию.
    IF NOT EXISTS (SELECT 1 FROM "Measure" WHERE id = 1) THEN
        RAISE EXCEPTION 'Единица измерения по умолчанию не существует';
    END IF;

    -- Используется ли ЕИ в категориях.
    SELECT EXISTS (
        SELECT 1 FROM "Category" WHERE measure_id = p_id
    ) INTO is_used;
    IF is_used THEN
        UPDATE "Category"
        SET measure_id = 1
        WHERE measure_id = p_id;
    END IF;

    -- Удаление
    DELETE FROM "Measure" WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Удаление записи из таблицы Категории.
/* Удаляет существующую запись из таблицы Категории.
    Вход:
        p_id (integer): ID удаляемой записи.
    Выход:
        void: Отсутствует.
    Эффекты:
        Удаление записи из таблицы Категории,
        Вызов ошибки, если Категория не существует,
        Вызов ошибки, если существуют дочерние Категории,
        Вызов ошибки, если существуют Изделия, принадлежащие данной Категории.
    Требования:
        Категория должна существовать,
        Категория не должна содержать дочерних,
        Категория не должна содержать изделий.
*/
CREATE OR REPLACE FUNCTION delete_category(
    p_id integer
) RETURNS void AS
$$
DECLARE
    has_children boolean;
    has_products boolean;
BEGIN
    -- Проверка существования.
    IF NOT EXISTS (SELECT 1 FROM "Category" WHERE id = p_id) THEN
        RAISE EXCEPTION 'Категория с ID % не найдена', p_id;
    END IF;

    -- Проверка на наличие дочерних категорий.
    SELECT EXISTS (
        SELECT 1 FROM "Category"
        WHERE parent_id = p_id
    ) INTO has_children;
    IF has_children THEN
        RAISE EXCEPTION 'Нельзя удалить категорию с ID %, так как она содержит подкатегории', p_id;
    END IF;

    -- Проверка на наличие изделий в категории.
    SELECT EXISTS (
        SELECT 1 FROM "Product"
        WHERE category_id = p_id
    ) INTO has_products;
    IF has_products THEN
        RAISE EXCEPTION 'Нельзя удалить категорию с ID %, так как она содержит изделия', p_id;
    END IF;

    -- Удаление.
    DELETE FROM "Category" WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Удаление записи из таблицы Изделия.
/* Удаляет существующую запись из таблицы Изделия.
    Вход:
        p_id (integer): ID удаляемой записи.
    Выход:
        void: Отсутствует.
    Эффекты:
        Удаление записи из таблицы Изделия,
        Вызов ошибки, если Изделия не существует,
    Требования:
        Изделие должно существовать,
*/
CREATE OR REPLACE FUNCTION delete_product(
    p_id integer
) RETURNS void AS
$$
BEGIN
    -- Проверка существования.
    IF NOT EXISTS (SELECT 1 FROM "Product" WHERE id = p_id) THEN
        RAISE EXCEPTION 'Продукт с ID % не найден', p_id;
    END IF;

    -- Удаление
    DELETE FROM "Product" WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Удаление записи из таблицы Значения перечисления.
/* Удаляет существующую запись из таблицы Значения перечисления.
    Вход:
        p_id (integer): ID удаляемой записи.
    Выход:
        void: Отсутствует.
    Эффекты:
        Удаление записи из таблицы EnumValue,
        Вызов ошибки, если значение перечисления не существует,
        Вызов ошибки, если значение используется в Параметрах Изделий (ParameterValue).
    Требования:
        Значение перечисления должно существовать,
        Значение не должно использоваться в ParameterValue.
*/
CREATE OR REPLACE FUNCTION delete_enum_value(
    p_id integer
) RETURNS void AS
$$
DECLARE
    is_used boolean;
BEGIN
    -- Проверка существования.
    IF NOT EXISTS (SELECT 1 FROM "EnumValue" WHERE id = p_id) THEN
        RAISE EXCEPTION 'Значение перечисления с ID % не найдено', p_id;
    END IF;

    -- Проверка использования в ParameterValue.
    SELECT EXISTS (
        SELECT 1 FROM "ParameterValue" WHERE value_enum = p_id
    ) INTO is_used;
    IF is_used THEN
        RAISE EXCEPTION 'Нельзя удалить значение перечисления с ID %, так как оно используется в параметрах изделий', p_id;
    END IF;

    -- Удаление.
    DELETE FROM "EnumValue" WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Удаление записи из таблицы Параметра.
/* Удаляет существующую запись из таблицы Параметра.
    Вход:
        p_id (integer): ID удаляемой записи.
    Выход:
        void: Отсутствует.
    Эффекты:
        Удаление записи из таблицы Parameter,
        Вызов ошибки, если параметр не существует,
        Вызов ошибки, если параметр используется в ParameterValue.
    Требования:
        Параметр должен существовать,
        Параметр не должен использоваться в ParameterValue.
*/
    CREATE OR REPLACE FUNCTION delete_parameter(
    p_id integer
) RETURNS void AS
$$
DECLARE
    is_used boolean;
BEGIN
    -- Проверка существования.
    IF NOT EXISTS (SELECT 1 FROM "Parameter" WHERE id = p_id) THEN
        RAISE EXCEPTION 'Параметр с ID % не найден', p_id;
    END IF;

    -- Проверка использования в ParameterValue.
    SELECT EXISTS (
        SELECT 1 FROM "ParameterValue" WHERE param_id = p_id
    ) INTO is_used;
    IF is_used THEN
        RAISE EXCEPTION 'Нельзя удалить параметр с ID %, так как он используется в параметрах изделий или категорий', p_id;
    END IF;

    -- Удаление.
    DELETE FROM "Parameter" WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Удаление записи из таблицы Параметра Изделия.
/* Удаляет существующую запись из таблицы Параметра Изделия.
    Вход:
        p_id (integer): ID удаляемой записи.
    Выход:
        void: Отсутствует.
    Эффекты:
        Удаление записи из таблицы ParameterValue,
        Вызов ошибки, если запись не существует.
    Требования:
        Запись должна существовать.
*/
CREATE OR REPLACE FUNCTION delete_parameter_value(
    p_id integer
) RETURNS void AS
$$
BEGIN
    -- Проверка существования.
    IF NOT EXISTS (SELECT 1 FROM "ParameterValue" WHERE id = p_id) THEN
        RAISE EXCEPTION 'Параметр значения с ID % не найден', p_id;
    END IF;

    -- Удаление.
    DELETE FROM "ParameterValue" WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;



/* ФУНКЦИИ ОБНОВЛЕНИЯ ЗАПИСЕЙ */

-- Обновление записи в таблице Единицы измерения.
/* Обновляет существующую запись в таблице Единицы измерения.
    Вход:
        p_id (integer): ID изменяемой записи,
        p_name (character varying(64)): Новое название,
        p_name_short (character varying(16)): Новое сокращение.
    Выход:
        void: Отсутствует.
    Эффекты:
        Обновление записи,
        Вызов ошибки, если запись не существует,
        Вызов ошибки, если запись с таким названием уже существует,
        Вызов ошибки, если запись с таким сокращением уже существует,
    Требования:
        Запись должна существовать,
        Обновленная запись не должна конфликтовать с существующими.
*/
CREATE OR REPLACE FUNCTION update_measure(
    p_id integer,
    p_name character varying(64) DEFAULT NULL,
    p_name_short character varying(16) DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    -- Проверка существования единицы измерения.
    IF NOT EXISTS (SELECT 1 FROM "Measure" WHERE id = p_id) THEN
        RAISE EXCEPTION 'Единица измерения с ID % не найдена', p_id;
    END IF;

    -- Проверка уникальности нового имени.
    IF p_name IS NOT NULL AND EXISTS (
        SELECT 1 FROM "Measure"
        WHERE name = p_name AND id != p_id
    ) THEN
        RAISE EXCEPTION 'Единица измерения с названием "%" уже существует', p_name;
    END IF;

    -- Проверка уникальности нового сокращения.
    IF p_name_short IS NOT NULL AND EXISTS (
        SELECT 1 FROM "Measure"
        WHERE name_short = p_name_short AND id != p_id
    ) THEN
        RAISE EXCEPTION 'Единица измерения с сокращением "%" уже существует', p_name_short;
    END IF;

    -- Обновление данных.
    UPDATE "Measure" SET
        name = COALESCE(p_name, name),
        name_short = COALESCE(p_name_short, name_short)
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Обновление записи в таблице Категории.
/* Обновляет существующую запись в таблице Категории.
    Вход:
        p_id (integer): ID изменяемой записи,
        p_name (character varying(128)): Новое название,
        p_parent_id (integer): ID новой родительской категории,
        p_measure_id (integer): ID новой единицы измерения.
    Выход:
        void: Отсутствует.
    Эффекты:
        Обновление записи,
        Вызов ошибки, если запись не существует,
        Вызов ошибки, если новой ЕИ не существует,
        Вызов ошибки, если новая родительская категория создает цикл,
        Вызов ошибки, если новая родительская и изменяемая категория одинаковы,
        Вызов ошибки, если новой родительской категории не существует,
    Требования:
        Запись должна существовать,
        Изменяемая ЕИ должна существовать,
        Изменяемая родительская категория должна существовать,
        Изменяемая родительская категория не должна быть родителем самой себе,
        Изменяемая родительская категория не должна создавать циклов.
*/
CREATE OR REPLACE FUNCTION update_category(
    p_id integer,
    p_name character varying(128) DEFAULT NULL,
    p_parent_id integer DEFAULT NULL,
    p_measure_id integer DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    -- Проверка существования категории.
    IF NOT EXISTS (SELECT 1 FROM "Category" WHERE id = p_id) THEN
        RAISE EXCEPTION 'Категория с ID % не найдена', p_id;
    END IF;

    -- Проверка существования новой единицы измерения
    IF p_measure_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM "Measure" WHERE id = p_measure_id) THEN
        RAISE EXCEPTION 'Единица измерения с ID % не существует', p_measure_id;
    END IF;

    -- Если меняется parent_id - проверка на циклы.
    IF p_parent_id IS NOT NULL THEN
        -- Категория не может быть родителем самой себя.
        IF p_id = p_parent_id THEN
            RAISE EXCEPTION 'Категория не может быть родителем самой себя';
        END IF;

        -- Проверка существования родительской категории.
        IF NOT EXISTS (SELECT 1 FROM "Category" WHERE id = p_parent_id) THEN
            RAISE EXCEPTION 'Родительская категория с ID % не существует', p_parent_id;
        END IF;

        -- Проверка циклов.
        PERFORM check_category_cycle(p_id, p_parent_id);
    END IF;

    -- Обновление данных.
    UPDATE "Category" SET
        name = COALESCE(p_name, name),
        parent_id = COALESCE(p_parent_id, parent_id),
        measure_id = COALESCE(p_measure_id, measure_id)
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Обновление записи в таблице Изделия.
/* Обновляет существующую запись в таблице Изделия.
    Вход:
        p_id (integer): ID изменяемой записи,
        p_name (character varying(128)): Новое название,
        p_category_id (integer): ID новой родительской категории,
    Выход:
        void: Отсутствует.
    Эффекты:
        Обновление записи,
        Вызов ошибки, если запись не существует,
        Вызов ошибки, если новой родительской категории не существует,
    Требования:
        Запись должна существовать,
        Родительская категория должна существовать
*/
CREATE OR REPLACE FUNCTION update_product(
    p_id integer,
    p_name character varying(128) DEFAULT NULL,
    p_category_id integer DEFAULT NULL,
    p_amount integer DEFAULT NULL,
    p_price numeric(11, 2) DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    -- Проверка существования изделия.
    IF NOT EXISTS (SELECT 1 FROM "Product" WHERE id = p_id) THEN
        RAISE EXCEPTION 'Изделие с ID % не найдено', p_id;
    END IF;

    -- Проверка существования категории.
    IF p_category_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM "Category" WHERE id = p_category_id) THEN
        RAISE EXCEPTION 'Категория с ID % не существует', p_category_id;
    END IF;

    -- Обновление данных.
    UPDATE "Product" SET
        name = COALESCE(p_name, name),
        category_id = COALESCE(p_category_id, category_id),
        amount = COALESCE(p_amount, amount),
        price = COALESCE(p_price, price)
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Обновление записи в таблице Значения Перечисления.
/* Обновляет существующую запись в таблице Значения Перечисления.
    Вход:
        p_id (integer): ID изменяемой записи,
        p_category_id (integer): Новый ID категории,
        p_code (character varying(8)): Новый код,
        p_priority (smallint): Новый приоритет,
        p_value_str (character varying(128)): Новое строковое значение,
        p_value_int (integer): Новое целочисленное значение,
        p_value_real (real): Новое вещественное значение,
        p_value_path (character varying(128)): Новый путь к файлу.
    Выход:
        void: Отсутствует.
    Эффекты:
        Обновление записи,
        Вызов ошибки при нарушении уникальности кода в категории,
        Вызов ошибки при нарушении условия заполненности только одного значения,
    Требования:
        Запись должна существовать,
        В категории не должно быть двух одинаковых кодов.
*/
CREATE OR REPLACE FUNCTION update_enum_value(
    p_id integer,
    p_category_id integer DEFAULT NULL,
    p_code character varying(8) DEFAULT NULL,
    p_priority smallint DEFAULT NULL,
    p_value_str character varying(128) DEFAULT NULL,
    p_value_int integer DEFAULT NULL,
    p_value_real real DEFAULT NULL,
    p_value_path character varying(128) DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    -- Проверка существования значения перечисления.
    IF NOT EXISTS (SELECT 1 FROM "EnumValue" WHERE id = p_id) THEN
        RAISE EXCEPTION 'Значение перечисления с ID % не найдено', p_id;
    END IF;

    -- Проверка уникальности кода в пределах категории.
    IF p_code IS NOT NULL AND p_category_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM "EnumValue"
        WHERE category_id = p_category_id AND code = p_code AND id != p_id
    ) THEN
        RAISE EXCEPTION 'Код "%" уже используется в категории ID %', p_code, p_category_id;
    END IF;

    -- Проверка заполненности ровно одного поля значения.
    IF (COALESCE(p_value_str IS NOT NULL, FALSE)::int +
        COALESCE(p_value_int IS NOT NULL, FALSE)::int +
        COALESCE(p_value_real IS NOT NULL, FALSE)::int +
        COALESCE(p_value_path IS NOT NULL, FALSE)::int) NOT IN (0,1) THEN
        RAISE EXCEPTION 'Должно быть заполнено ровно одно из полей значения';
    END IF;

    -- Обновление записи.
    UPDATE "EnumValue" SET
        category_id = COALESCE(p_category_id, category_id),
        code = COALESCE(p_code, code),
        priority = COALESCE(p_priority, priority),
        value_str = COALESCE(p_value_str, value_str),
        value_int = COALESCE(p_value_int, value_int),
        value_real = COALESCE(p_value_real, value_real),
        value_path = COALESCE(p_value_path, value_path)
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Удаление записи в таблице Значения Перечисления.
/* Обновляет существующую запись в таблице Параметры.
    Вход:
        p_id (integer): ID изменяемой записи,
        p_measure_id (integer): Новый ID единицы измерения,
        p_data_type (character varying(4)): Новый тип параметра,
        p_enum_id (integer): Новый ID перечисления (если тип = enum),
        p_name (character varying(128)): Новое название,
        p_name_short (character varying(8)): Новое сокращение,
        p_min_val (integer): Новое минимальное значение,
        p_max_val (integer): Новое максимальное значение.
    Выход:
        void: Отсутствует.
    Эффекты:
        Обновление записи,
        Проверка соответствия нового типа параметра и перечисления,
        Проверка уникальности сокращения.
    Требования:
        Запись должна существовать,
        Если тип enum — перечисление должно существовать,
        Сокращение должно быть уникальным.
*/
CREATE OR REPLACE FUNCTION update_parameter(
    p_id integer,
    p_measure_id integer DEFAULT NULL,
    p_data_type character varying(4) DEFAULT NULL,
    p_enum_id integer DEFAULT NULL,
    p_name character varying(128) DEFAULT NULL,
    p_name_short character varying(8) DEFAULT NULL,
    p_min_val integer DEFAULT NULL,
    p_max_val integer DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    -- Проверка существования параметра.
    IF NOT EXISTS (SELECT 1 FROM "Parameter" WHERE id = p_id) THEN
        RAISE EXCEPTION 'Параметр с ID % не найден', p_id;
    END IF;

    -- Проверка уникальности нового сокращения.
    IF p_name_short IS NOT NULL AND EXISTS (
        SELECT 1 FROM "Parameter"
        WHERE name_short = p_name_short AND id != p_id
    ) THEN
        RAISE EXCEPTION 'Параметр с сокращением "%" уже существует', p_name_short;
    END IF;

    -- Проверка валидности типа параметра.
    IF p_data_type IS NOT NULL AND p_data_type NOT IN ('int', 'str', 'real', 'enum', 'path') THEN
        RAISE EXCEPTION 'Недопустимый тип данных параметра: "%"', p_data_type;
    END IF;

    -- Проверка существования перечисления, если выбран тип enum.
    IF p_data_type = 'enum' AND (p_enum_id IS NULL OR NOT EXISTS (SELECT 1 FROM "Category" WHERE id = p_enum_id)) THEN
        RAISE EXCEPTION 'Перечисление с ID % не существует', p_enum_id;
    END IF;

    -- Обновление записи.
    UPDATE "Parameter" SET
        measure_id = COALESCE(p_measure_id, measure_id),
        data_type = COALESCE(p_data_type, data_type),
        enum_id = COALESCE(p_enum_id, enum_id),
        name = COALESCE(p_name, name),
        name_short = COALESCE(p_name_short, name_short),
        min_val = COALESCE(p_min_val, min_val),
        max_val = COALESCE(p_max_val, max_val)
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- Обновление записи в таблице Значения Перечисления.
/* Обновляет существующую запись в таблице Параметры Изделий.
    Вход:
        p_id (integer): ID изменяемой записи,
        p_product_id (integer): Новый ID изделия,
        p_category_id (integer): Новый ID категории,
        p_param_id (integer): Новый ID параметра,
        p_value_enum (integer): Новый ID значения перечисления,
        p_value_str (character varying(128)): Новое строковое значение,
        p_value_int (integer): Новое целое значение,
        p_value_real (real): Новое вещественное значение,
        p_value_path (character varying(128)): Новый путь к файлу.
    Выход:
        void: Отсутствует.
    Эффекты:
        Обновление записи,
        Проверка уникальности связки параметр-изделие/категория,
        Проверка заполненности ровно одного родителя (product или category),
    Требования:
        Запись должна существовать,
        Только один родитель должен быть заполнен.
*/
CREATE OR REPLACE FUNCTION update_parameter_value(
    p_id integer,
    p_product_id integer DEFAULT NULL,
    p_category_id integer DEFAULT NULL,
    p_param_id integer DEFAULT NULL,
    p_value_enum integer DEFAULT NULL,
    p_value_str character varying(128) DEFAULT NULL,
    p_value_int integer DEFAULT NULL,
    p_value_real real DEFAULT NULL,
    p_value_path character varying(128) DEFAULT NULL
) RETURNS void AS
$$
BEGIN
    -- Проверка существования значения параметра.
    IF NOT EXISTS (SELECT 1 FROM "ParameterValue" WHERE id = p_id) THEN
        RAISE EXCEPTION 'Значение параметра с ID % не найдено', p_id;
    END IF;

    -- Проверка заполненности только одного родителя.
    IF (COALESCE(p_product_id IS NOT NULL, FALSE)::int +
        COALESCE(p_category_id IS NOT NULL, FALSE)::int) NOT IN (0,1) THEN
        RAISE EXCEPTION 'Должен быть указан только один родитель: либо изделие, либо категория';
    END IF;

    -- Обновление записи.
    UPDATE "ParameterValue" SET
        product_id = COALESCE(p_product_id, product_id),
        category_id = COALESCE(p_category_id, category_id),
        param_id = COALESCE(p_param_id, param_id),
        value_enum = COALESCE(p_value_enum, value_enum),
        value_str = COALESCE(p_value_str, value_str),
        value_int = COALESCE(p_value_int, value_int),
        value_real = COALESCE(p_value_real, value_real),
        value_path = COALESCE(p_value_path, value_path)
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;



/* ФУНКЦИИ ПОИСКА ЗАПИСЕЙ */

-- Получение всех дочерних категорий.
/* Возвращает таблицу всех дочерних элементов (и категорий, и изделий) по идентификатору родительской.
    Вход:
        p_category_id (integer): ID родительской категории,
    Выход:
        TABLE: Таблица дочерних элементов.
*/
CREATE OR REPLACE FUNCTION get_all_descendants(
    p_category_id integer
) RETURNS TABLE(
    id integer,
    name character varying(128),
    is_category bool,
    parent_id integer,
    measure_id integer,
    depth integer
) AS
$$
BEGIN
    RETURN QUERY
    WITH RECURSIVE category_tree AS (
        -- Базовый случай: начальная категория.
        SELECT
            c.id,
            c.name,
            true AS is_category,
            c.parent_id,
            c.measure_id,
            0 AS depth
        FROM "Category" c
        WHERE c.id = p_category_id

        UNION ALL

        -- Рекурсивный случай: все дочерние категории.
        SELECT
            child.id,
            child.name,
            true AS is_category,
            child.parent_id,
            child.measure_id,
            parent.depth + 1
        FROM "Category" child
        JOIN category_tree parent ON child.parent_id = parent.id
    )
    -- Выбираем все дочерние категории (исключая исходную).
    SELECT
        ct.id,
        ct.name,
        ct.is_category,
        ct.parent_id,
        ct.measure_id,
        ct.depth
    FROM category_tree ct
    WHERE ct.depth > 0

    UNION ALL

    -- Добавляем все изделия для найденных категорий.
    SELECT
        p.id,
        p.name,
        false as is_category,
        p.category_id AS parent_id,
        NULL AS measure_id,
        ct.depth + 1 AS depth
    FROM "Product" p
    JOIN category_tree ct ON p.category_id = ct.id
    ORDER BY depth, is_category, name;
END;
$$ LANGUAGE plpgsql;

-- Получение всех родительских категорий.
/* Возвращает таблицу всех родительских категорий по идентификатору дочерней.
    Вход:
        p_category_id (integer): ID дочерней категории,
    Выход:
        TABLE: Таблица родительских категорий.
*/
CREATE OR REPLACE FUNCTION get_all_parents(
    p_category_id integer
)
RETURNS TABLE(
    parent_id integer,
    parent_name character varying(128),
    parent_parent_id integer,
    parent_measure_id integer,
    depth_level integer
) AS
$$
BEGIN
    RETURN QUERY
    WITH RECURSIVE category_path AS (
        -- Базовый случай: начальная категория.
        SELECT
            c.id,
            c.name,
            c.parent_id,
            c.measure_id,
            0 AS depth
        FROM "Category" c
        WHERE c.id = p_category_id

        UNION ALL

        -- Рекурсивный случай: все родительские категории.
        SELECT
            parent.id,
            parent.name,
            parent.parent_id,
            parent.measure_id,
            child.depth + 1
        FROM "Category" parent
        JOIN category_path child ON parent.id = child.parent_id
    )
    SELECT
        cp.id,
        cp.name,
        cp.parent_id,
        cp.measure_id,
        cp.depth
    FROM category_path cp
    WHERE cp.depth > 0
    ORDER BY cp.depth;
END;
$$ LANGUAGE plpgsql;

-- Поиск всех терминальных классов заданной категории.
/* Возвращает таблицу всех терминальных категорий по идентификатору родительской.
    Вход:
        p_category_id (integer): ID родительской категории,
    Выход:
        TABLE: Таблица терминальных категорий.
*/
CREATE OR REPLACE FUNCTION get_terminal_categories(
    p_category_id integer
)
RETURNS TABLE(
    term_id integer,
    term_name character varying(128),
    term_parent_id integer,
    term_measure_id integer,
    term_depth integer
) AS
$$
BEGIN
    RETURN QUERY
    WITH RECURSIVE category_tree AS (
        -- Базовый случай: начальная категория.
        SELECT
            c.id,
            c.name,
            c.parent_id,
            c.measure_id,
            0 AS depth
        FROM "Category" c
        WHERE c.id = p_category_id

        UNION ALL

        -- Рекурсивный случай: все дочерние категории.
        SELECT
            child.id,
            child.name,
            child.parent_id,
            child.measure_id,
            parent.depth + 1
        FROM "Category" child
        JOIN category_tree parent ON child.parent_id = parent.id
    )
    SELECT
        ct.id,
        ct.name,
        ct.parent_id,
        ct.measure_id,
        ct.depth
    FROM category_tree ct
    WHERE NOT EXISTS (
        SELECT 1 FROM "Category" c
        WHERE c.parent_id = ct.id
    ) AND ct.id != p_category_id
    ORDER BY ct.depth, ct.name;
END;
$$ LANGUAGE plpgsql;

-- Поиск изделий категории с отображением параметров.
/* Возвращает таблицу всех изделий и их параметры.
    Вход:
        p_category_id (integer): ID родительской категории,
    Выход:
        TABLE: Таблица изделий.
*/
CREATE OR REPLACE FUNCTION get_products_with_params_by_category(p_category_id integer)
RETURNS TABLE (
    category_id integer,
    category character varying(128),
    product_id integer,
    product character varying(128),
    amount integer,
    measure character varying(16),
    price numeric(11, 2),
    param_id integer,
    param_name character varying(8),
    param_type character varying(4),
    param_value character varying(128),
    param_measure character varying(16)
) AS
$$
BEGIN
    RETURN QUERY
    WITH RECURSIVE category_tree AS ( -- Дерево категорий.
        SELECT id, parent_id, name, measure_id
        FROM "Category"
        WHERE id = p_category_id
        UNION ALL
        SELECT c.id, c.parent_id, c.name, c.measure_id
        FROM "Category" c
        INNER JOIN category_tree ct ON c.parent_id = ct.id
    ),
    product_category_path AS ( -- Путь от изделия к его родительским категориям.
        SELECT p.id AS product_id, c.id AS category_id
        FROM "Product" p
        JOIN category_tree c ON p.category_id = c.id
        UNION ALL
        SELECT pcp.product_id, c.parent_id
        FROM product_category_path pcp
        JOIN "Category" c ON pcp.category_id = c.id
        WHERE c.parent_id IS NOT NULL
    ),
    all_params AS ( -- Все параметры.
        SELECT
            p.id AS product_id,
            pv.param_id,
            pv.value_int,
            pv.value_real,
            pv.value_str,
            pv.value_path,
            pv.value_enum
        FROM "Product" p
        LEFT JOIN "ParameterValue" pv ON pv.product_id = p.id
        UNION ALL
        SELECT
            pcp.product_id,
            pv.param_id,
            pv.value_int,
            pv.value_real,
            pv.value_str,
            pv.value_path,
            pv.value_enum
        FROM product_category_path pcp
        JOIN "ParameterValue" pv ON pv.category_id = pcp.category_id
        WHERE NOT EXISTS (  -- Если нет переопределения у изделия.
            SELECT 1
            FROM "ParameterValue" pv2
            WHERE pv2.product_id = pcp.product_id
              AND pv2.param_id = pv.param_id
        )
    )
    SELECT
        c.id AS category_id,
        c.name AS category,
        p.id AS product_id,
        p.name AS product,
        p.amount,
        m.name_short AS measure,
        p.price,
        param.id AS param_id,
        param.name_short AS param_name,
        param.data_type AS param_type,
        CASE
            WHEN param.data_type = 'int'  THEN ap.value_int::character varying(128)
            WHEN param.data_type = 'real' THEN ap.value_real::character varying(128)
            WHEN param.data_type = 'str'  THEN ap.value_str
            WHEN param.data_type = 'path' THEN ap.value_path
            WHEN param.data_type = 'enum' THEN
                CASE
                    WHEN ev.value_int  IS NOT NULL THEN ev.value_int::character varying(128)
                    WHEN ev.value_real IS NOT NULL THEN ev.value_real::character varying(128)
                    WHEN ev.value_str  IS NOT NULL THEN ev.value_str
                    WHEN ev.value_path IS NOT NULL THEN ev.value_path
                END
        END AS param_value,
        pm.name_short AS param_measure
    FROM "Product" p
    JOIN category_tree c ON p.category_id = c.id
    LEFT JOIN "Measure" m ON c.measure_id = m.id
    LEFT JOIN all_params ap ON p.id = ap.product_id
    LEFT JOIN "Parameter" param ON ap.param_id = param.id
    LEFT JOIN "Measure" pm ON param.measure_id = pm.id
    LEFT JOIN "EnumValue" ev ON ap.value_enum = ev.id
    WHERE param.id IS NOT NULL
    ORDER BY p.id, param.id;
END;
$$ LANGUAGE plpgsql;

-- Поиск всех изделий с их параметрами (все изделия корневой категории).
CREATE OR REPLACE FUNCTION get_all_products_with_params()
RETURNS TABLE (
    category_id integer,
    category character varying(128),
    product_id integer,
    product character varying(128),
    amount integer,
    measure character varying(16),
    price numeric(11, 2),
    param_id integer,
    param_name character varying(8),
    param_type character varying(4),
    param_value character varying(128),
    param_measure character varying(16)
) AS
$$
BEGIN
    RETURN QUERY
    SELECT * FROM get_products_with_params_by_category(1);
END;
$$ LANGUAGE plpgsql;

-- Вывод всех параметров отдельного изделия (с учётом параметров изделия и его категории).
CREATE OR REPLACE FUNCTION get_product_params(p_product_id integer)
RETURNS TABLE (
    param_id integer,
    param_name character varying(128),
    param_name_short character varying(8),
    param_data_type character varying(4),
    param_value character varying(128),
    param_measure character varying(16)
) AS
$$
BEGIN
    RETURN QUERY
    WITH RECURSIVE category_hierarchy AS (
        SELECT c.id, c.parent_id
        FROM "Category" c
        JOIN "Product" p ON p.category_id = c.id
        WHERE p.id = p_product_id
        UNION ALL
        SELECT c.id, c.parent_id
        FROM "Category" c
        JOIN category_hierarchy ch ON c.id = ch.parent_id
    )
    SELECT
        param.id AS param_id,
        param.name AS param_name,
        param.name_short AS param_name_short,
        param.data_type AS param_data_type,
        CASE
            WHEN param.data_type = 'int'  THEN pv.value_int::character varying(128)
            WHEN param.data_type = 'real' THEN pv.value_real::character varying(128)
            WHEN param.data_type = 'str'  THEN pv.value_str
            WHEN param.data_type = 'path' THEN pv.value_path
            WHEN param.data_type = 'enum' THEN
                CASE
                    WHEN ev.value_int  IS NOT NULL THEN ev.value_int::character varying(128)
                    WHEN ev.value_real IS NOT NULL THEN ev.value_real::character varying(128)
                    WHEN ev.value_str  IS NOT NULL THEN ev.value_str
                    WHEN ev.value_path IS NOT NULL THEN ev.value_path
                END
        END AS param_value,
        pm.name_short AS param_measure
    FROM "ParameterValue" pv
    LEFT JOIN "Parameter" param ON pv.param_id = param.id
    LEFT JOIN "Measure" pm ON param.measure_id = pm.id
    LEFT JOIN "EnumValue" ev ON pv.value_enum = ev.id
    WHERE
        (pv.product_id = p_product_id) -- Параметры изделий.
        OR (pv.category_id IN (SELECT id FROM category_hierarchy)) -- Параметры категории и родителей.
    ORDER BY param.id;
END;
$$ LANGUAGE plpgsql;

-- Получить все изделия с параметрами заданного агрегата.
CREATE OR REPLACE FUNCTION get_products_with_aggregate_params(p_parent_param_id integer)
RETURNS TABLE (
    category_id integer,
    category character varying(128),
    product_id integer,
    product character varying(128),
    amount integer,
    measure character varying(16),
    price numeric(11, 2),
    param_id integer,
    parent_param_name character varying(8),
    param_name character varying(8),
    param_type character varying(4),
    param_value character varying(128),
    param_measure character varying(16)
) AS
$$
BEGIN
    RETURN QUERY
    SELECT
        result.category_id,
        result.category,
        result.product_id,
        result.product,
        result.amount,
        result.measure,
        result.price,
        result.param_id,
        p_parent.name AS parent_param_name,
        result.param_name,
        result.param_type,
        result.param_value,
        result.param_measure
    FROM get_all_products_with_params() AS result
    JOIN "ParameterAggregate" pa ON pa.param_id = result.param_id
    JOIN "Parameter" p_parent ON pa.parent_param_id = p_parent.id
    WHERE pa.parent_param_id = p_parent_param_id;
END;
$$ LANGUAGE plpgsql;

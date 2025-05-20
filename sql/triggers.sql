-- Триггер EnumValue.
/* Проверяет, что категория для EnumValue действительно является перечислением.
    Эффекты:
        Вызов ошибки, если категория не является перечислением,
        Вызов ошибки, если категории не существует.
*/
CREATE OR REPLACE FUNCTION check_enum_value_category()
RETURNS trigger AS
$$
DECLARE
    is_enum_value boolean;
BEGIN
    -- Проверка, что категория для EnumValue действительно является перечислением
    SELECT is_enum INTO is_enum_value
    FROM "Category"
    WHERE id = NEW.category_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Категории с ID % не существует', NEW.category_id;
    END IF;

    IF NOT is_enum_value THEN
        RAISE EXCEPTION 'Категория ID % не является перечислением', NEW.category_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_enum_value_category ON "EnumValue";
CREATE TRIGGER trg_check_enum_value_category
BEFORE INSERT OR UPDATE ON "EnumValue"
FOR EACH ROW
EXECUTE FUNCTION check_enum_value_category();


-- Триггер ParamValue.
/* Проверяет правильность типа данных, правильность указания значения перечисления.
    Эффекты:
        Вызов ошибки, если тип параметра не соответствует заполненному полю,
        Вызов ошибки, если указанного параметра не существует,
        Вызов ошибки, если указано неверное значение перечисления.
 */
CREATE OR REPLACE FUNCTION check_param_value_consistency()
RETURNS trigger AS
$$
DECLARE
    param_type character varying(4);
    param_enum_id integer;
BEGIN
    -- Получаем тип параметра и enum_id
    SELECT data_type, enum_id INTO param_type, param_enum_id
    FROM "Parameter"
    WHERE id = NEW.param_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Параметра с ID % не существует', NEW.param_id;
    END IF;

    -- Проверка соответствия заполненного поля типу параметра
    CASE param_type
        WHEN 'int' THEN
            IF NEW.value_int IS NULL THEN
                RAISE EXCEPTION 'Ожидалось значение value_int для типа int';
            END IF;
        WHEN 'real' THEN
            IF NEW.value_real IS NULL THEN
                RAISE EXCEPTION 'Ожидалось значение value_real для типа real';
            END IF;
        WHEN 'str', 'path' THEN
            IF NEW.value_str IS NULL THEN
                RAISE EXCEPTION 'Ожидалось значение value_str для типа str';
            END IF;
        WHEN 'path' THEN
            IF NEW.value_path IS NULL THEN
                RAISE EXCEPTION 'Ожидалось значение value_path для типа path';
            END IF;
        WHEN 'enum' THEN
            IF NEW.value_enum IS NULL THEN
                RAISE EXCEPTION 'Ожидалось значение value_enum для типа enum';
            END IF;

            -- Дополнительная проверка для enum:
            -- значение value_enum должно ссылаться на правильную категорию
            IF NOT EXISTS (
                SELECT 1
                FROM "EnumValue"
                WHERE id = NEW.value_enum
                  AND category_id = param_enum_id
            ) THEN
                RAISE EXCEPTION 'Значение value_enum % не принадлежит категории перечислений %',
                    NEW.value_enum, param_enum_id;
            END IF;
        ELSE
            RAISE EXCEPTION 'Неизвестный тип параметра %', param_type;
    END CASE;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_param_value_consistency ON "ParameterValue";
CREATE TRIGGER trg_check_param_value_consistency
BEFORE INSERT OR UPDATE ON "ParameterValue"
FOR EACH ROW
EXECUTE FUNCTION check_param_value_consistency();

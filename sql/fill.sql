-- 1. Очистка таблиц.
TRUNCATE TABLE
    "Product", "Category", "Measure", "EnumValue", "Parameter", "ParameterValue"
RESTART IDENTITY CASCADE;
ALTER SEQUENCE "Category_Product_id_seq" RESTART WITH 1;

-- 2. Заполнение таблиц.
DO
$$
DECLARE
    root_id integer;
    anker_id integer;
    anker_metal_id integer;
    anker_clin_id integer;
    clinch_id integer;
    clinch_hammer_id integer;
    clinch_vent_id integer;
    material_id integer;
    picture_id integer;
    length_id integer;
    length_of_head_id integer;
    enum_mat1_id integer;
    enum_mat2_id integer;
    enum_mat3_id integer;
    enum_len1_id integer;
    enum_len2_id integer;
    tmp1_id integer;
    tmp2_id integer;
    tmp3_id integer;
    tmp4_id integer;
BEGIN
    RAISE NOTICE '=== ЗАПОЛНЕНИЕ ТАБЛИЦ ===';

    -- Заполнение таблицы единиц измерения.
    PERFORM create_measure('Штука', 'шт');  -- По умолчанию.
    PERFORM create_measure('Метр', 'м');
    PERFORM create_measure('Миллиметр', 'мм');
    PERFORM create_measure('Сантиметр', 'см');
    PERFORM create_measure('Килограмм', 'кг');
    PERFORM create_measure('Грамм', 'г');
    PERFORM create_measure('-', '-');

    -- Заполнение иерархии категорий и изделий.
    SELECT create_category('Крепёжные изделия', NULL, 1) INTO root_id;

    SELECT create_category('Анкеры', root_id, 1) INTO anker_id;
    SELECT create_category('Анкеры металлические', anker_id, 1) INTO anker_metal_id;
    PERFORM create_product('Анкер металлический Sormat S-CSA I', anker_metal_id, 100, 10);
    PERFORM create_product('Анкер металлический Sormat S_csa HEX', anker_metal_id, 228, 5);
    SELECT create_category('Анкеры клиновые', anker_id, 1) INTO anker_clin_id;
    PERFORM create_product('Анкер клиновой с гайкой Sormat S-KAH', anker_clin_id, 4, 1);
    PERFORM create_product('Анкер клиновой с гайкой Sormat S-KAH HCR', anker_clin_id, 150, 2);

    SELECT create_category('Заклёпки', root_id, 1) INTO clinch_id;
    SELECT create_category('Заклёпки под молоток', clinch_id, 1) INTO clinch_hammer_id;
    PERFORM create_product('DIN 660 Заклёпка под молоток с полукруглой головкой', clinch_hammer_id);
    PERFORM create_product('DIN 661 Заклёпка под молоток с потайной головкой', clinch_hammer_id);
    SELECT create_category('Заклёпки вытяжные', clinch_id, 1) INTO clinch_vent_id;
    PERFORM create_product('DIN 7377 Заклёпка вытяжная стальная, нержавеющая', clinch_vent_id);
    PERFORM create_product('Заклёпка вытяжная (тяговая) алюминиевая с потайным буртиком AL/AL', clinch_vent_id);

    -- Заполнение Категорий Перечислений.
    SELECT create_category('Перечисление', NULL, 1, true) INTO root_id;
    SELECT create_category('Схема', root_id, 1, true) INTO picture_id;
    SELECT create_category('Материал', root_id, 1, true) INTO material_id;
    SELECT create_category('Длина', root_id, 1, true) INTO length_id;
    SELECT create_category('Длина головки', length_id, 1, true) INTO length_of_head_id;

    -- Заполнение Значений Перечислений.
    PERFORM create_enum_value(picture_id, 1, 1, null, null, null, 'C:\picture1.png');
    PERFORM create_enum_value(picture_id, 2, 3, null, null, null, 'C:\picture2.png');
    PERFORM create_enum_value(picture_id, 3, 2, null, null, null, 'C:\picture3.png');
    SELECT create_enum_value(material_id, 1, 0, 'Металл', null, null, null) INTO enum_mat1_id;
    SELECT create_enum_value(material_id, 2, 1, 'Пластик', null, null, null) INTO enum_mat2_id;
    SELECT create_enum_value(material_id, 3, 2, 'Картон', null, null, null) INTO enum_mat3_id;
    SELECT create_enum_value(length_of_head_id, 1, 0, null, 100, null, null) INTO enum_len1_id;
    SELECT create_enum_value(length_of_head_id, 2, 1, null, 200, null, null) INTO enum_len2_id;

    -- Заполнение Параметров.
--     SELECT  create_parameter(7, 'enum', 'Материал изделия',      'Материал', material_id) INTO param_material_id;
--     PERFORM create_parameter(3, 'enum', 'Длина (тест)',          'L',        length_id);
--     SELECT  create_parameter(3, 'enum', 'Длина головки изделия', 'l',        length_of_head_id) INTO param_length_id;
--     SELECT  create_parameter(5, 'real', 'Объем изделия',         'V',        null, 1, 100) INTO param_volume_id;
--
    -- Заполнение значений Параметров.
--     PERFORM create_parameter_value(param_material_id, 4,    null, enum_mat2_id, null, null, null, null);
--     PERFORM create_parameter_value(param_material_id, 5,    null, enum_mat3_id, null, null, null, null);
--     PERFORM create_parameter_value(param_length_id,   null, 1,    enum_len1_id, null, null, null, null);
--     PERFORM create_parameter_value(param_volume_id,   null, 6,    null,         null, null, 1.5,  null);
--     PERFORM create_parameter_value(4,                 7,    null, null,         null, null, 2.5,  null);

    SELECT  create_parameter(3, 'int', 'Размеры', '-') INTO tmp1_id;
    SELECT  create_parameter(3, 'int', 'Длина', 'l') INTO tmp2_id;
    SELECT  create_parameter(3, 'int', 'Ширина', 'w') INTO tmp3_id;
    SELECT  create_parameter(3, 'int', 'Высота', 'h') INTO tmp4_id;

    INSERT INTO "ParameterAggregate" VALUES
        (tmp1_id, tmp2_id),
        (tmp1_id, tmp3_id),
        (tmp1_id, tmp4_id);

    PERFORM create_parameter_value(tmp2_id, 4, null, null, null, 50, null, null);
    PERFORM create_parameter_value(tmp3_id, 4, null, null, null, 75, null, null);
    PERFORM create_parameter_value(tmp4_id, 4, null, null, null, 64, null, null);
    PERFORM create_parameter_value(tmp2_id, 8, null, null, null, 14, null, null);
    PERFORM create_parameter_value(tmp3_id, 8, null, null, null, 43, null, null);
    PERFORM create_parameter_value(tmp4_id, 8, null, null, null, 39, null, null);

    RAISE NOTICE '=== ЗАПОЛНЕНИЕ ТАБЛИЦ ЗАВЕРШЕНО ===';
END
$$;
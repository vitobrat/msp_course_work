"""Использование.

Находясь в директории `/db_admin/`, выполните:
```bash
py manage.py shell
```

Откроется интерпретатор Python. В нём выполните:
```python
from django_db_app.utils.fill_test_data import fill_test_data
fill_test_data()
```
"""

from django.db import transaction
from django.db.utils import IntegrityError

from ..models import (
    Measure, Category, Product,
    EnumValue, Parameter, ParameterValue, ParameterAggregate
)


@transaction.atomic
def fill_test_data():
    try:
        # Единицы измерения.
        measure_data = [
            ("Штука", "шт"),
            ("Метр", "м"),
            ("Миллиметр", "мм"),
            ("Сантиметр", "см"),
            ("Килограмм", "кг"),
            ("Грамм", "г"),
            ("-", "-")
        ]
        measures = {name: Measure.objects.create(name=name, name_short=short)
                    for name, short in measure_data}

        # Категории.
        root_category = Category.objects.create(
            name="Крепёжные изделия",
            parent=None, measure=measures["Штука"]
        )
        anker_category = Category.objects.create(
            name="Анкеры",
            parent=root_category, measure=measures["Штука"]
        )
        anker_metal_category = Category.objects.create(
            name="Анкеры металлические",
            parent=anker_category, measure=measures["Штука"]
        )
        anker_clinch_category = Category.objects.create(
            name="Анкеры клиновые",
            parent=anker_category, measure=measures["Штука"]
        )
        clinch_category = Category.objects.create(
            name="Заклёпки",
            parent=root_category, measure=measures["Штука"]
        )
        clinch_hammer_category = Category.objects.create(
            name="Заклёпки под молоток",
            parent=clinch_category, measure=measures["Штука"])
        clinch_vent_category = Category.objects.create(
            name="Заклёпки вытяжные",
            parent=clinch_category, measure=measures["Штука"]
        )

        # Перечисления.
        picture_category = Category.objects.create(
            name="Схема",
            parent=root_category, measure=measures["Штука"],  is_enum=True
        )
        material_category = Category.objects.create(
            name="Материал",
            parent=root_category, measure=measures["Штука"], is_enum=True
        )
        length_category = Category.objects.create(
            name="Длина",
            parent=root_category, measure=measures["Штука"], is_enum=True
        )
        length_of_head_category = Category.objects.create(
            name="Длина головки",
            parent=length_category, measure=measures["Штука"], is_enum=True
        )

        # Продукты.
        products = [
            ("Анкер металлический Sormat S-CSA I",
             anker_metal_category, 100, 10),
            ("Анкер металлический Sormat S_csa HEX",
             anker_metal_category, 228, 5),
            ("Анкера клиновые с гайкой Sormat S-KAH",
             anker_clinch_category, 4, 1),
            ("Анкер клиновой с гайкой Sormat S-KAH HCR",
             anker_clinch_category, 150, 2),
            ("DIN 660 Заклёпка под молоток с полукруглой головкой",
             clinch_hammer_category, 0, 0),
            ("DIN 661 Заклёпка под молоток с потайной головкой",
             clinch_hammer_category, 0, 0),
            ("DIN 7377 Заклёпка вытяжная стальная, нержавеющая",
             clinch_vent_category, 0, 0),
            ("Заклёпка вытяжная алюминиевая с потайным буртиком AL/AL",
            clinch_vent_category, 0, 0),
        ]
        products_objs = [
            Product.objects.create(
                name=name, category=category, amount=amount, price=price
            ) for name, category, amount, price in products
        ]

        # Значения перечислений.
        enum_values_data = [
            (picture_category, "1", 1, r"C:\picture1.png"),
            (picture_category, "2", 3, r"C:\picture2.png"),
            (picture_category, "3", 2, r"C:\picture3.png"),
            (material_category, "1", 0, "Металл"),
            (material_category, "2", 1, "Пластик"),
            (material_category, "3", 2, "Картон"),
            (length_of_head_category, "1", 0, 100),
            (length_of_head_category, "2", 1, 200)
        ]
        enum_values_objs = [
            EnumValue.objects.create(
                category=category,
                code=code,
                priority=priority,
                value_str=value if isinstance(value, str) else None,
                value_int=value if isinstance(value, int) else None,
                value_real=value if isinstance(value, float) else None,
                value_path=value if isinstance(value, str)
                                    and value.endswith(".png") else None,
            )
            for category, code, priority, value in enum_values_data
        ]

        # Параметры.
        parameters = [
            ("Размеры", "int", "-", measures["Штука"]),
            ("Длина", "int", "l", measures["Штука"]),
            ("Ширина", "int", "w", measures["Штука"]),
            ("Высота", "int", "h", measures["Штука"]),
        ]
        params = {
            name: Parameter.objects.create(
                name=name, data_type=data_type,
                name_short=name_short, measure=measure)
            for name, data_type, name_short, measure in parameters
        }

        # Параметры агрегаты.
        ParameterAggregate.objects.create(parent_param=params["Размеры"],
                                          param=params["Длина"])
        ParameterAggregate.objects.create(parent_param=params["Размеры"],
                                          param=params["Ширина"])
        ParameterAggregate.objects.create(parent_param=params["Размеры"],
                                          param=params["Высота"])

        # Значения параметров.
        param_values = [
            (params["Длина"],  products_objs[3], 50),
            (params["Ширина"], products_objs[3], 75),
            (params["Высота"], products_objs[3], 64),
            (params["Длина"],  products_objs[7], 14),
            (params["Ширина"], products_objs[7], 43),
            (params["Высота"], products_objs[7], 39)
        ]
        for param, product, value in param_values:
            ParameterValue.objects.create(
                param=param, product=product, value_int=value
            )
        print("=== Заполнение таблиц завершено успешно ===")

    except IntegrityError as e:
        print(f"Error occurred during database filling: {e}")
        raise

    except Exception as e:
        print(f"Unexpected error: {e}")
        raise

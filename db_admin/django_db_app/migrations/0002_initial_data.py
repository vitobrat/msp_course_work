from django.db import migrations

def create_initial_data(apps, schema_editor):
    # Получаем модели
    Measure = apps.get_model('django_db_app', 'Measure')
    Category = apps.get_model('django_db_app', 'Category')
    EnumValue = apps.get_model('django_db_app', 'EnumValue')
    Parameter = apps.get_model('django_db_app', 'Parameter')
    Product = apps.get_model('django_db_app', 'Product')
    ParameterValue = apps.get_model('django_db_app', 'ParameterValue')

    # Создаем единицы измерения
    measure_kg, _ = Measure.objects.get_or_create(
        name_short='kg',
        defaults={'name': 'Kilogram'}
    )
    measure_pc, _ = Measure.objects.get_or_create(
        name_short='pc',
        defaults={'name': 'Piece'}
    )
    measure_cm, _ = Measure.objects.get_or_create(
        name_short='cm',
        defaults={'name': 'Centimeter'}
    )

    # Создаем корневые категории
    electronics, _ = Category.objects.get_or_create(
        name='Electronics',
        defaults={
            'is_enum': False,
            'measure': measure_pc
        }
    )
    
    smartphones, _ = Category.objects.get_or_create(
        name='Smartphones',
        parent=electronics,
        defaults={
            'is_enum': False,
            'measure': measure_pc
        }
    )

    # Создаем enum категорию для цветов
    colors, _ = Category.objects.get_or_create(
        name='Phone Colors',
        is_enum=True,
        defaults={
            'measure': measure_pc
        }
    )

    # Добавляем значения enum
    color_black, _ = EnumValue.objects.get_or_create(
        category=colors,
        code='BLACK',
        defaults={
            'value_str': 'Black',
            'priority': 1
        }
    )
    color_white, _ = EnumValue.objects.get_or_create(
        category=colors,
        code='WHITE',
        defaults={
            'value_str': 'White',
            'priority': 2
        }
    )

    # Создаем параметры
    weight_param, _ = Parameter.objects.get_or_create(
        name_short='weight',
        defaults={
            'name': 'Weight',
            'data_type': 'real',
            'measure': measure_kg
        }
    )
    
    color_param, _ = Parameter.objects.get_or_create(
        name_short='color',
        defaults={
            'name': 'Color',
            'data_type': 'enum',
            'enum': colors
        }
    )

    # Создаем продукты
    iphone, _ = Product.objects.get_or_create(
        category=smartphones,
        name='iPhone 15',
        defaults={
            'amount': 10,
            'price': 999.99
        }
    )

    # Добавляем параметры к продукту
    ParameterValue.objects.get_or_create(
        param=weight_param,
        product=iphone,
        defaults={'value_real': 0.171}
    )
    
    ParameterValue.objects.get_or_create(
        param=color_param,
        product=iphone,
        value_enum=color_black
    )

def reverse_initial_data(apps, schema_editor):
    # Удаляем все созданные данные
    Measure = apps.get_model('django_db_app', 'Measure')
    Category = apps.get_model('django_db_app', 'Category')
    Parameter = apps.get_model('django_db_app', 'Parameter')
    Product = apps.get_model('django_db_app', 'Product')
    
    Product.objects.filter(name='iPhone 15').delete()
    Parameter.objects.filter(name_short__in=['weight', 'color']).delete()
    Category.objects.filter(name__in=['Phone Colors', 'Smartphones', 'Electronics']).delete()
    Measure.objects.filter(name_short__in=['kg', 'pc', 'cm']).delete()

class Migration(migrations.Migration):
    dependencies = [
        ('django_db_app', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(
            create_initial_data,
            reverse_code=reverse_initial_data
        ),
    ]
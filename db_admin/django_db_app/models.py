from django.db import models
from django.core.exceptions import ValidationError


class Measure(models.Model):
    name = models.CharField(max_length=64)
    name_short = models.CharField(max_length=16, unique=True)

    def __str(self):
        return self.name


class Category(models.Model):
    parent = models.ForeignKey('self',
                               on_delete=models.CASCADE,
                               null=True,
                               blank=True,
                               related_name='subcategories')
    is_enum = models.BooleanField(default=False)
    name = models.CharField(max_length=128, unique=True)
    measure = models.ForeignKey(Measure,
                                on_delete=models.SET_DEFAULT,
                                default=1)

    def __str__(self):
        return self.name


class Product(models.Model):
    category = models.ForeignKey(Category, on_delete=models.RESTRICT)
    name = models.CharField(max_length=128)
    amount = models.IntegerField(default=0)
    price = models.DecimalField(max_digits=11, decimal_places=2, default=0.00)

    class Meta:
        unique_together = ('category', 'name')

    def __str__(self):
        return self.name


class EnumValue(models.Model):
    category = models.ForeignKey(Category, on_delete=models.RESTRICT)
    code = models.CharField(max_length=8)
    priority = models.SmallIntegerField(default=0)
    value_str = models.CharField(max_length=128, null=True, blank=True)
    value_int = models.IntegerField(null=True, blank=True)
    value_real = models.FloatField(null=True, blank=True)
    value_path = models.CharField(max_length=128, null=True, blank=True)

    class Meta:
        unique_together = ('category', 'code')

    def clean(self):
        # Проверка, что одно и только одно поле значения должно быть заполнено.
        value_count = sum([
            bool(self.value_str),
            bool(self.value_int),
            bool(self.value_real),
            bool(self.value_path)
        ])
        if value_count != 1:
            raise ValidationError(
                'Только одно поле значения должно быть заполнено.'
            )

    def __str__(self):
        return f'self.category.name - {self.code}'


class Parameter(models.Model):
    DATA_TYPES = [
        ('int', 'Integer'),
        ('str', 'String'),
        ('real', 'Real'),
        ('enum', 'Enum'),
        ('path', 'Path')
    ]

    measure = models.ForeignKey(Measure,
                                on_delete=models.RESTRICT,
                                null=True, blank=True)
    data_type = models.CharField(max_length=4, choices=DATA_TYPES)
    enum = models.ForeignKey(Category,
                             on_delete=models.RESTRICT,
                             null=True, blank=True)
    name = models.CharField(max_length=128)
    name_short = models.CharField(max_length=8, unique=True)
    min_val = models.IntegerField(null=True, blank=True)
    max_val = models.IntegerField(null=True, blank=True)

    def clean(self):
        # Проверка, что если data_type = 'enum', то enum_id не может быть NULL.
        if self.data_type == 'enum' and not self.enum:
            raise ValidationError(
                "Если тип данных 'enum', то enum_id не может быть NULL."
            )
        if self.data_type != 'enum' and self.enum:
            raise ValidationError(
                "Если тип данных не 'enum', то enum_id должно быть NULL."
            )

    def __str__(self):
        return self.name


class ParameterValue(models.Model):
    product = models.ForeignKey(Product,
                                on_delete=models.CASCADE,
                                null=True, blank=True)
    category = models.ForeignKey(Category,
                                 on_delete=models.CASCADE,
                                 null=True, blank=True)
    param = models.ForeignKey(Parameter, on_delete=models.CASCADE)
    value_enum = models.ForeignKey(EnumValue,
                                   on_delete=models.RESTRICT,
                                   null=True, blank=True)
    value_str = models.CharField(max_length=128, null=True, blank=True)
    value_int = models.IntegerField(null=True, blank=True)
    value_real = models.FloatField(null=True, blank=True)
    value_path = models.CharField(max_length=128, null=True, blank=True)

    class Meta:
        unique_together = [
            ('param', 'product'),
            ('param', 'category'),
        ]

    def clean(self):
        # Проверка, что только одно поле
        # родительского объекта должно быть заполнено.
        if bool(self.product) + bool(self.category) != 1:
            raise ValidationError(
                "Одно и только одно поле родительского объекта"
                " должно быть заполнено."
            )
        # Проверка, что только одно значение параметра должно быть заполнено.
        value_count = sum([
            bool(self.value_enum),
            bool(self.value_str),
            bool(self.value_int),
            bool(self.value_real),
            bool(self.value_path)
        ])
        if value_count != 1:
            raise ValidationError(
                "Только одно значение параметра должно быть заполнено."
            )

    def __str__(self):
        value = f"{self.value_str or self.value_int or self.value_real}"
        return f"{self.param.name} - {value}"


class ParameterAggregate(models.Model):
    parent_param = models.ForeignKey(Parameter,
                                     related_name='aggregates',
                                     on_delete=models.CASCADE)
    param = models.ForeignKey(Parameter,
                              related_name='aggregated',
                              on_delete=models.CASCADE)

    class Meta:
        unique_together = ('parent_param', 'param')

    def __str__(self):
        return f"{self.parent_param.name} -> {self.param.name}"

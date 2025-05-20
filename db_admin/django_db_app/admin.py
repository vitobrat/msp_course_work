from django.contrib import admin
from django import forms
from .models import Measure, Category, Product, EnumValue, Parameter, ParameterValue, ParameterAggregate


@admin.register(Measure)
class MeasureAdmin(admin.ModelAdmin):
    list_display = ('name', 'name_short')
    search_fields = ('name', 'name_short')
    ordering = ('name',)


class CategoryForm(forms.ModelForm):
    class Meta:
        model = Category
        fields = '__all__'

    def clean(self):
        cleaned_data = super().clean()
        is_enum = cleaned_data.get('is_enum')
        parent = cleaned_data.get('parent')

        if is_enum and parent and parent.is_enum:
            raise forms.ValidationError(
                "Категория-перечисление не может быть подкатегорией "
                "другой категории-перечисления."
            )

        return cleaned_data


@admin.register(Category)
class CategoryAdmin(admin.ModelAdmin):
    form = CategoryForm
    list_display = ('name', 'parent', 'is_enum', 'measure')
    list_filter = ('is_enum', 'parent')
    search_fields = ('name',)
    ordering = ('name',)
    raw_id_fields = ('parent',)

    def get_form(self, request, obj=None, **kwargs):
        form = super().get_form(request, obj, **kwargs)
        form.base_fields['parent'].queryset = Category.objects.filter(
            is_enum=False
        )
        return form


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ('name', 'category', 'amount', 'price')
    list_filter = ('category',)
    search_fields = ('name',)
    ordering = ('category', 'name')
    raw_id_fields = ('category',)


class EnumValueForm(forms.ModelForm):
    class Meta:
        model = EnumValue
        fields = '__all__'

    def clean(self):
        cleaned_data = super().clean()
        category = cleaned_data.get('category')

        if category and not category.is_enum:
            raise forms.ValidationError(
                "Можно добавлять значения только для категорий-перечислений."
            )

        return cleaned_data


@admin.register(EnumValue)
class EnumValueAdmin(admin.ModelAdmin):
    form = EnumValueForm
    list_display = ('category', 'code', 'priority', 'get_value')
    list_filter = ('category',)
    search_fields = ('code', 'value_str')
    ordering = ('category', 'priority', 'code')

    def get_value(self, obj):
        return (obj.value_str or obj.value_int or
                obj.value_real or obj.value_path)

    get_value.short_description = 'Значение'


class ParameterForm(forms.ModelForm):
    class Meta:
        model = Parameter
        fields = '__all__'

    def clean(self):
        cleaned_data = super().clean()
        data_type = cleaned_data.get('data_type')
        enum = cleaned_data.get('enum')

        if data_type == 'enum' and not enum:
            raise forms.ValidationError(
                "Для типа 'enum' необходимо указать категорию-перечисление."
            )
        if data_type != 'enum' and enum:
            raise forms.ValidationError(
                "Категория-перечисление может быть указана "
                "только для типа 'enum'."
            )

        return cleaned_data


@admin.register(Parameter)
class ParameterAdmin(admin.ModelAdmin):
    form = ParameterForm
    list_display = ('name', 'name_short', 'data_type', 'measure', 'enum')
    list_filter = ('data_type',)
    search_fields = ('name', 'name_short')
    ordering = ('name',)

    def get_form(self, request, obj=None, **kwargs):
        form = super().get_form(request, obj, **kwargs)
        form.base_fields['enum'].queryset = Category.objects.filter(
            is_enum=True
        )
        return form


class ParameterValueForm(forms.ModelForm):
    class Meta:
        model = ParameterValue
        fields = '__all__'

    def clean(self):
        cleaned_data = super().clean()
        param = cleaned_data.get('param')
        value_enum = cleaned_data.get('value_enum')

        if param and param.data_type == 'enum' and not value_enum:
            raise forms.ValidationError(
                "Для параметра типа 'enum' необходимо указать "
                "значение перечисления."
            )
        if param and param.data_type != 'enum' and value_enum:
            raise forms.ValidationError(
                "Значение перечисления можно указывать только"
                " для параметров типа 'enum'."
            )

        return cleaned_data


@admin.register(ParameterValue)
class ParameterValueAdmin(admin.ModelAdmin):
    form = ParameterValueForm
    list_display = ('param', 'get_parent', 'get_value')
    list_filter = ('param',)
    search_fields = ('param__name', 'value_str')
    raw_id_fields = ('product', 'category', 'param', 'value_enum')

    def get_parent(self, obj):
        return obj.product or obj.category

    get_parent.short_description = 'Объект'

    def get_value(self, obj):
        return (obj.value_str or obj.value_int or
                obj.value_real or obj.value_path or
                (obj.value_enum.code if obj.value_enum else None))

    get_value.short_description = 'Значение'

    def get_form(self, request, obj=None, **kwargs):
        form = super().get_form(request, obj, **kwargs)
        if obj and obj.param and obj.param.data_type == 'enum':
            form.base_fields['value_enum'].queryset = EnumValue.objects.filter(
                category=obj.param.enum
            )
        return form


@admin.register(ParameterAggregate)
class ParameterAggregateAdmin(admin.ModelAdmin):
    list_display = ('parent_param', 'param')
    list_filter = ('parent_param',)
    search_fields = ('parent_param__name', 'param__name')
    raw_id_fields = ('parent_param', 'param')

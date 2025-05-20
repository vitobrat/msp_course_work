# forms.py
from django import forms
from .models import Category, Product, Parameter  # предполагаем, что у тебя есть модель Category


class CategorySelectForm(forms.Form):
    category = forms.ModelChoiceField(
        queryset=Category.objects.all(),
        label='Выберите категорию',
        required=True,  # Добавлено для явного указания, что поле обязательно.
        empty_label="Не выбрано"  # Это добавляет опцию "Не выбрано" в список.
    )


class ProductSelectForm(forms.Form):
    product = forms.ModelChoiceField(
        queryset=Product.objects.all(),
        label='Выберите продукт',
        required=True,
        empty_label="Не выбрано",
    )


class ParentParamForm(forms.Form):
    parent_param_id = forms.IntegerField(
        label='Идентификатор родительского параметра',
        required=True,
        widget=forms.NumberInput(
            attrs={'placeholder': 'Введите идентификатор параметра'}
        )
    )

    def clean_parent_param_id(self):
        parent_param_id = self.cleaned_data.get('parent_param_id')

        # Можно добавить дополнительные проверки,
        # например, на существование такого параметра в базе.
        if not Parameter.objects.filter(id=parent_param_id).exists():
            raise forms.ValidationError(
                "Родительский параметр с таким ID не существует."
            )

        return parent_param_id

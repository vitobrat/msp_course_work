from django.contrib.auth.mixins import LoginRequiredMixin, PermissionRequiredMixin
from .models import Category, Product, ParameterValue, ParameterAggregate
from django.views.generic.edit import FormView
from django.views.generic import TemplateView
from django.shortcuts import render, get_object_or_404
from .forms import CategorySelectForm, ProductSelectForm, ParentParamForm


class IndexView(TemplateView):
    template_name = 'pages/index.html'


class ClassifierView(LoginRequiredMixin, PermissionRequiredMixin, TemplateView):
    permission_required = 'django_db_app.view_category'
    template_name = 'pages/classifier.html'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)

        categories = Category.objects.filter(is_enum=False)
        products = Product.objects.all()

        category_map = {}
        for cat in categories:
            category_map.setdefault(cat.parent_id, []).append(cat)

        product_map = {}
        for prod in products:
            product_map.setdefault(prod.category_id, []).append(prod)

        def build_lines(counter, parent_id=None, level=0):
            children = category_map.get(parent_id, [])
            for category in sorted(children, key=lambda c: c.name):
                counter += 1
                lines.append({
                    'id': counter,
                    'name': category.name,
                    'level': level,
                    'is_product': False
                })
                for product in sorted(product_map.get(category.id, []),
                                      key=lambda p: p.name):
                    counter += 1
                    lines.append({
                        'id': counter,
                        'name': product.name,
                        'level': level + 1,
                        'is_product': True
                    })
                counter = build_lines(counter, category.id, level + 1)
            return counter

        lines = []
        build_lines(counter=0)
        context['results'] = lines
        return context


class DescendantsByCategoryView(LoginRequiredMixin, PermissionRequiredMixin,
                                FormView):
    permission_required = 'django_db_app.view_category'
    raise_exception = True
    template_name = 'pages/descendants_by_category.html'
    form_class = CategorySelectForm

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['results'] = False  # До отправки формы не показываем таблицы.
        return context

    def form_valid(self, form):
        category = form.cleaned_data['category']
        all_categories = Category.objects.all().values('id', 'parent_id')

        def get_descendants_ids(parent_id):
            result = []
            for cat in all_categories:
                if cat['parent_id'] == parent_id:
                    result.append(cat['id'])
                    result.extend(get_descendants_ids(cat['id']))
            return result

        descendant_ids = get_descendants_ids(category.id)
        descendant_categories = Category.objects.filter(
            id__in=descendant_ids
        )
        descendant_products = Product.objects.filter(
            category_id__in=descendant_ids
        )

        return render(self.request, self.template_name, {
            'form': form,
            'descendant_categories': descendant_categories,
            'descendant_products': descendant_products,
            'selected_category': category,
            'results': True,
        })


class ParentsByCategoryView(LoginRequiredMixin, PermissionRequiredMixin,
                            FormView):
    permission_required = 'django_db_app.view_category'
    raise_exception = True
    template_name = 'pages/parents_by_category.html'
    form_class = CategorySelectForm

    def form_valid(self, form):
        category = form.cleaned_data['category']
        parent_chain = []
        depth = 1
        current = category.parent

        while current:
            parent_chain.append({
                'id': current.id,
                'name': current.name,
                'parent_id': current.parent.id if current.parent else None,
                'measure_id': current.measure_id,
                'depth': depth,
            })
            current = current.parent
            depth += 1

        return render(self.request, self.template_name, {
            'form': form,
            'selected_category': category,
            'parent_categories': parent_chain[::-1],  # От корня к выбранной.
            'results': True,
        })


class TerminalCategoriesView(LoginRequiredMixin, PermissionRequiredMixin,
                             FormView):
    permission_required = 'django_db_app.view_category'
    raise_exception = True
    template_name = 'pages/terminal_categories.html'
    form_class = CategorySelectForm

    def form_valid(self, form):
        selected_category = form.cleaned_data['category']
        all_categories = list(Category.objects.all().values(
            'id', 'parent_id', 'name', 'measure_id')
        )

        # Построение карты родительства.
        children_map = {}
        for cat in all_categories:
            parent_id = cat['parent_id']
            children_map.setdefault(parent_id, []).append(cat)

        # Рекурсивная функция обхода.
        def get_terminal_categories(category_id, depth=0):
            terminals = []
            children = children_map.get(category_id, [])
            if not children:
                current = next(
                    c for c in all_categories if c['id'] == category_id
                )
                terminals.append({
                    'id': current['id'],
                    'name': current['name'],
                    'parent_id': current['parent_id'],
                    'measure_id': current['measure_id'],
                    'depth': depth,
                })
            else:
                for child in children:
                    terminals.extend(
                        get_terminal_categories(child['id'], depth + 1)
                    )
            return terminals

        terminal_categories = get_terminal_categories(selected_category.id)

        return render(self.request, self.template_name, {
            'form': form,
            'selected_category': selected_category,
            'terminal_categories': terminal_categories,
            'results': True,
        })


class ProductsWithParamsView(LoginRequiredMixin, PermissionRequiredMixin,
                             FormView):
    permission_required = 'django_db_app.view_product'
    template_name = 'pages/products_with_params.html'
    form_class = CategorySelectForm

    def form_valid(self, form):
        selected_category = form.cleaned_data['category']

        # Получаем все категории, включая потомков.
        all_categories = Category.objects.all()
        category_ids = [selected_category.id]

        # Используем рекурсивный запрос для получения всех подкатегорий.
        categories_to_check = [selected_category]
        while categories_to_check:
            category = categories_to_check.pop()
            category_ids.append(category.id)
            categories_to_check.extend(category.subcategories.all())

        # Получаем все продукты в этих категориях.
        products = Product.objects.filter(
            category_id__in=category_ids
        ).select_related('category', 'category__measure')

        results = []

        for product in products:
            # Сначала получаем параметры самого продукта.
            param_values = ParameterValue.objects.filter(
                product=product
            ).select_related('param', 'param__measure', 'value_enum')

            # Затем параметры категории,
            # если не переопределены на уровне продукта.
            overridden_params = {pv.param_id for pv in param_values}

            inherited_param_values = ParameterValue.objects.filter(
                category=product.category
            ).exclude(
                param_id__in=overridden_params
            ).select_related('param', 'param__measure', 'value_enum')

            combined_params = list(param_values) + list(inherited_param_values)

            for pv in combined_params:
                param = pv.param
                value = None
                if param.data_type == 'int':
                    value = str(pv.value_int)
                elif param.data_type == 'real':
                    value = str(pv.value_real)
                elif param.data_type == 'str':
                    value = pv.value_str
                elif param.data_type == 'path':
                    value = pv.value_path
                elif param.data_type == 'enum' and pv.value_enum:
                    value = (pv.value_enum.value_str or
                             pv.value_enum.value_int or
                             pv.value_enum.value_real or
                             pv.value_enum.value_path)

                results.append({
                    'category_id': product.category.id,
                    'category': product.category.name,
                    'product_id': product.id,
                    'product': product.name,
                    'amount': product.amount,
                    'measure': (product.category.measure.name_short
                                if product.category.measure else ''),
                    'price': product.price,
                    'param_id': param.id,
                    'param_name': param.name_short,
                    'param_type': param.data_type,
                    'param_value': value,
                    'param_measure': (param.measure.name_short
                                      if param.measure else ''),
                })

        return render(self.request, self.template_name, {
            'form': form,
            'selected_category': selected_category,
            'products': results,
            'results': True,
        })


class AllProductsWithParamsView(LoginRequiredMixin, PermissionRequiredMixin,
                                TemplateView):
    permission_required = 'django_db_app.view_product'
    template_name = 'pages/all_products_with_params.html'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)

        # Получаем все продукты, которые принадлежат корневой категории.
        products = Product.objects.all().select_related(
            'category', 'category__measure'
        )

        results = []

        # Для каждого продукта получаем параметры.
        for product in products:
            # Параметры, заданные для продукта.
            param_values = ParameterValue.objects.filter(
                product=product
            ).select_related('param', 'param__measure', 'value_enum')

            # Параметры, заданные для категории,
            # если они не переопределены на уровне продукта.
            overridden_params = {pv.param_id for pv in param_values}
            inherited_param_values = ParameterValue.objects.filter(
                category=product.category
            ).exclude(
                param_id__in=overridden_params
            ).select_related('param', 'param__measure', 'value_enum')

            # Комбинируем параметры продукта и параметры категории.
            combined_params = list(param_values) + list(inherited_param_values)

            # Добавляем результат для каждого параметра.
            for pv in combined_params:
                param = pv.param
                value = None

                # Преобразуем значение в строку в зависимости от типа данных.
                if param.data_type == 'int':
                    value = str(pv.value_int) if pv.value_int else ''
                elif param.data_type == 'real':
                    value = str(pv.value_real) if pv.value_real else ''
                elif param.data_type == 'str':
                    value = pv.value_str if pv.value_str else ''
                elif param.data_type == 'path':
                    value = pv.value_path if pv.value_path else ''
                elif param.data_type == 'enum' and pv.value_enum:
                    value = (pv.value_enum.value_str or
                             pv.value_enum.value_int or
                             pv.value_enum.value_real or
                             pv.value_enum.value_path)
                else:
                    value = ''  # Если нет значений, оставляем пустую строку.

                # Добавляем информацию о продукте и параметре в результаты.
                try:
                    results.append({
                        'category_id': product.category.id,
                        'category': product.category.name,
                        'product_id': product.id,
                        'product': product.name,
                        'amount': product.amount,
                        'measure': (product.category.measure.name_short
                                    if product.category.measure else ''),
                        'price': product.price,
                        'param_id': param.id,
                        'param_name': param.name_short,
                        'param_type': param.data_type,
                        'param_value': value,
                        'param_measure': (param.measure.name_short
                                          if param.measure else ''),
                    })
                except Exception as e:
                    print(f"Error while processing {product.name}: {e}")
                    continue

        # Добавляем результаты в контекст.
        context['results'] = results
        return context


class ProductParamsView(LoginRequiredMixin, PermissionRequiredMixin,
                        TemplateView):
    permission_required = 'django_db_app.view_product'
    template_name = 'pages/product_params.html'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)

        if 'product' in self.request.GET:
            form = ProductSelectForm(self.request.GET)
            if form.is_valid():
                product = form.cleaned_data['product']
                params = ParameterValue.objects.filter(
                    product=product
                ).select_related('param', 'param__measure', 'value_enum')
            else:
                product = None
                params = []
        else:
            form = ProductSelectForm()
            product = None
            params = []

        context['form'] = form
        context['product'] = product
        context['params'] = params
        context['results'] = bool(product)

        if product and not params:
            context['no_params_message'] = (
                "Параметры для выбранного продукта не найдены."
            )

        return context


class ProductsWithAggregateParamsView(TemplateView):
    template_name = 'pages/products_with_aggregate_params.html'
    permission_required = 'django_db_app.view_product'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)

        if 'parent_param_id' in self.request.GET:
            form = ParentParamForm(self.request.GET)
            if form.is_valid():
                parent_param_id = form.cleaned_data['parent_param_id']
            else:
                parent_param_id = None
        else:
            form = ParentParamForm()  # пустая форма
            parent_param_id = None

        context['form'] = form

        products_with_params = self.get_products_with_params()

        aggregate_params = self.filter_params_by_aggregate(products_with_params,
                                                           parent_param_id) \
            if parent_param_id else []

        context['aggregate_params'] = aggregate_params
        context['results'] = bool(aggregate_params)

        return context

    def get_products_with_params(self):
        results = []

        # Получаем все продукты с оптимизированными запросами
        # для связанных объектов.
        products = Product.objects.select_related(
            'category', 'category__measure'
        ).all()

        for product in products:
            # Получаем параметры продукта.
            product_param_values = list(
                ParameterValue.objects.filter(product=product).select_related(
                    'param', 'param__measure', 'value_enum'
                )
            )

            used_param_ids = [pv.param_id for pv in product_param_values]

            # Получаем наследуемые параметры категории,
            # если они не переопределены на уровне продукта.
            inherited_param_values = ParameterValue.objects.filter(
                category=product.category
            ).exclude(
                param_id__in=used_param_ids
            ).select_related('param', 'param__measure', 'value_enum')

            # Объединяем параметры продукта и наследуемые параметры.
            combined_params = (product_param_values +
                               list(inherited_param_values))

            for pv in combined_params:
                param = pv.param
                value = None

                # Приведение значений к строкам в зависимости от типа данных.
                if param.data_type == 'int':
                    value = str(pv.value_int)
                elif param.data_type == 'real':
                    value = str(pv.value_real)
                elif param.data_type == 'str':
                    value = pv.value_str
                elif param.data_type == 'path':
                    value = pv.value_path
                elif param.data_type == 'enum' and pv.value_enum:
                    if pv.value_enum.value_str is not None:
                        value = pv.value_enum.value_str
                    elif pv.value_enum.value_int is not None:
                        value = str(pv.value_enum.value_int)
                    elif pv.value_enum.value_real is not None:
                        value = str(pv.value_enum.value_real)
                    elif pv.value_enum.value_path is not None:
                        value = pv.value_enum.value_path

                # Добавляем результат в список.
                results.append({
                    'category_id': product.category.id,
                    'category': product.category.name,
                    'product_id': product.id,
                    'product': product.name,
                    'amount': product.amount,
                    'measure': (product.category.measure.name_short
                                if product.category.measure else ''),
                    'price': product.price,
                    'param_id': param.id,
                    'param_name': param.name_short,
                    'param_type': param.data_type,
                    'param_value': value,
                    'param_measure': (param.measure.name_short
                                      if param.measure else '')
                })

        return results

    def filter_params_by_aggregate(self, products_with_params, parent_param_id):
        aggregate_params = []

        # Получаем все параметры, связанные с родительским параметром.
        parent_params = ParameterAggregate.objects.filter(
            parent_param_id=parent_param_id
        )
        parent_param_ids = set(pp.param_id for pp in parent_params)

        # Фильтруем параметры продуктов, связанные с родительским параметром.
        for product_param in products_with_params:
            if product_param['param_id'] in parent_param_ids:
                aggregate_params.append(product_param)

        return aggregate_params

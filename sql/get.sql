-- Функции поиска.
SELECT * FROM "Measure";
SELECT * FROM "Category";
SELECT * FROM "Product";
SELECT * FROM "EnumValue";
SELECT * FROM "Parameter";
SELECT * FROM "ParameterValue";
SELECT * FROM "ParameterAggregate";


SELECT * FROM get_products_with_params_by_category(6);
SELECT * FROM get_product_params(8);

SELECT * FROM get_products_with_aggregate_params(1);

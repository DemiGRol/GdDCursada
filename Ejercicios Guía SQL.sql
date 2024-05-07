--Recomendable ir probando de a poco para ver el efecto de aquello �ltimo que hice.
-- EJERCICIO 1
/* Mostrar el c�digo, raz�n social de todos los clientes cuyo l�mite de cr�dito sea mayor o
	igual a $ 1000 ordenado por c�digo de cliente. */

SELECT clie_codigo, clie_razon_social
	FROM Cliente -- Definir primero para que me vincule las columnas en el select.
	WHERE clie_limite_credito >= 1000
	ORDER BY clie_codigo

-- EJERCICIO 2 (CLASE)
/* Mostrar el c�digo, detalle de todos los art�culos vendidos en el a�o 2012 ordenados por
	cantidad vendida */

SELECT prod_codigo, prod_detalle
FROM Producto JOIN Item_Factura ON prod_codigo = item_producto
	JOIN Factura ON fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero --Utilizo el + como un & booleano
WHERE year(fact_fecha) = 2012
GROUP BY prod_codigo, prod_detalle
ORDER BY sum(item_cantidad) --puedo ordenar por criterios que no est�n en el SELECT

--EJERCICIO 3 (CLASE)
/* Realizar una consulta que muestre c�digo de producto, nombre de producto y el stock
	total, sin importar en que deposito se encuentre, los datos deben ser ordenados por
	nombre del art�culo de menor a mayor. */

select prod_codigo, prod_detalle, sum(stoc_cantidad)
from Producto left join STOCK ON prod_codigo = stoc_producto --Tengo 2200 filas. Una para cada producto.
GROUP BY prod_codigo, prod_detalle
order by prod_detalle

--EJERCICIO 7
/* Generar una consulta que muestre para cada art�culo c�digo, detalle, mayor precio
menor precio y % de la diferencia de precios (respecto del menor Ej.: menor precio =
10, mayor precio =12 => mostrar 20 %). Mostrar solo aquellos art�culos que posean
stock. */

select prod_codigo, prod_detalle, min(prod_precio) MenorPrecio, max(prod_precio) MayorPrecio, 100*(max(prod_precio) - min(prod_precio))/min(prod_precio) DiferenciaPrecios
from Producto join 


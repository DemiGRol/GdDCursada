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

--EJERCICIO 4
/* Realizar una consulta que muestre para todos los art�culos c�digo, detalle y cantidad de
	art�culos que lo componen. Mostrar solo aquellos art�culos para los cuales el stock
	promedio por dep�sito sea mayor a 100.	*/

	select count(distinct comp_producto)
	from Composicion

	--universo mayor
	select prod_codigo,	prod_detalle, count(comp_componente)
	from Producto left Join Composicion on prod_codigo = comp_producto 
	group by prod_codigo, prod_detalle

	--universo menor
	select stoc_producto
	from STOCK   
	group by stoc_producto
	having avg(stoc_cantidad) > 100

	select prod_codigo, prod_detalle, count(comp_componente) as cantidadComponentes
	from Producto	
		left join Composicion on prod_codigo = comp_producto 
		where prod_codigo in (select stoc_producto --Si quiero filtrar por prod_codigo y realizo una consulta de m�ltiples columnas,
								from STOCK			-- c�mo sabe el motor con cu�l columna comparar?
								group by stoc_producto
								having avg(stoc_cantidad)>100)
	group by prod_codigo, prod_detalle

--EJERCICIO 5
/*
Realizar una consulta que muestre c�digo de art�culo, detalle y cantidad de egresos de
stock que se realizaron para ese art�culo en el a�o 2012 (egresan los productos que
fueron vendidos). Mostrar solo aquellos que hayan tenido m�s egresos que en el 2011.
*/

--Producto, Item_Factura, Factura
	select *
	from Producto

	select *
	from Item_Factura

	select *
	from Factura

	select prod_codigo, prod_detalle, sum(item_cantidad) cantidadVendida
	from Producto 
		left join Item_Factura on item_producto = prod_codigo
		join Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
	where YEAR(fact_fecha) = 2012
	group by prod_codigo, prod_detalle
	having sum(item_cantidad) > (select sum(item_cantidad)
								from Item_Factura
									join Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
								where YEAR(fact_fecha) = 2011 and prod_codigo = item_producto )

--EJERCICIO 6
/*
Mostrar para todos los rubros de art�culos c�digo, detalle, cantidad de art�culos de ese
rubro y stock total de ese rubro de art�culos. Solo tener en cuenta aquellos art�culos que
tengan un stock mayor al del art�culo �00000000� en el dep�sito �00�
*/

--UNIVERSO MAYOR -> todos los rubros y stocks de productos
--UNIVERSO MENOR -> aquellos productos con stock mayor al del 0 en el deposito 0

select *
from Rubro

--stock y cantidad de productos por rubro
select rubr_id, rubr_detalle, count(prod_rubro) cantidadRubro, sum(stoc_cantidad) stockRubro
from Rubro 
	join Producto on prod_rubro = rubr_id
	join STOCK on stoc_producto = prod_codigo
group by rubr_id, rubr_detalle
order by rubr_id

--stock mayor al del producto 0 en el deposito 0
select rubr_id, rubr_detalle, count(distinct prod_codigo) cantidadProductos, sum(stoc_cantidad) stockRubro
from Rubro 
	left join Producto on prod_rubro = rubr_id --left por si hay rubros sin productos
	left join STOCK on stoc_producto = prod_codigo --stoc_producto no es la PK completa, agrego un left porque me cambia la atomicidad.
where stoc_producto in (select stoc_producto
						from STOCK
						group by stoc_producto
						having sum(stoc_cantidad) > (select stoc_cantidad
														from STOCK		--no estoy filtrando los productos, falta 
														where stoc_producto like '00000000' and stoc_deposito like '00'))
group by rubr_id, rubr_detalle
order by rubr_id

--EJERCICIO 7
/* Generar una consulta que muestre para cada art�culo c�digo, detalle, mayor precio
menor precio y % de la diferencia de precios (respecto del menor Ej.: menor precio =
10, mayor precio =12 => mostrar 20 %). Mostrar solo aquellos art�culos que posean
stock. */

select *
from STOCK

--Todos los productos
select prod_codigo, prod_detalle, max(item_precio) precioMax, min(item_precio) precioMin, ((max(item_precio)/min(item_precio)-1)*100) as diferenciaPrecios
from Producto
	join Item_Factura on prod_codigo = item_producto
group by prod_codigo, prod_detalle

--Solo aquellos que tengan stock
select prod_codigo, prod_detalle, max(item_precio) precioMax, min(item_precio) precioMin, ((max(item_precio)/min(item_precio)-1)*100) as diferenciaPrecios
from Producto
	join Item_Factura on prod_codigo = item_producto
where prod_codigo in (select stoc_producto
					  from STOCK
					  where stoc_cantidad > 0) --NO CONTEMPLO LA SUMA DE LOS STOCKS ENTRE LOS DEP�SITOS
group by prod_codigo, prod_detalle

--BIEN HECHO
select prod_codigo, prod_detalle, max(item_precio) precioMax, min(item_precio) precioMin, ((max(item_precio)/min(item_precio)-1)*100) as diferenciaPrecios
from Producto
	join Item_Factura on prod_codigo = item_producto
where prod_codigo in (select stoc_producto
					  from STOCK
					  group by stoc_producto
					  having sum(stoc_cantidad) > 0) 
group by prod_codigo, prod_detalle

--EJERCICIO 8
/*
Mostrar para el o los art�culos que tengan stock en todos los dep�sitos, nombre del
art�culo, stock del dep�sito que m�s stock tiene.
*/
select *
from STOCK

--todos los productos
select prod_codigo, prod_detalle, max(stoc_cantidad)
from Producto
	join STOCK on prod_codigo = stoc_producto
group by prod_codigo, prod_detalle

--aquellos con stock en todos los dep�sitos
select prod_codigo, prod_detalle, max(stoc_cantidad)
from Producto
	join STOCK on prod_codigo = stoc_producto
where prod_codigo in (select stoc_producto
					  from STOCK
					  group by stoc_producto
					  having min(stoc_cantidad) > 0)
group by prod_codigo, prod_detalle
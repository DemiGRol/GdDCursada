/*
1. Mostrar el código, razón social de todos los clientes cuyo límite de crédito sea mayor o
igual a $ 1000 ordenado por código de cliente
*/

SELECT clie_codigo, clie_razon_social 
FROM Cliente
WHERE clie_limite_credito >= 1000
ORDER BY clie_codigo

/*
2. Mostrar el código, detalle de todos los artículos vendidos en el año 2012 ordenados por
cantidad vendida.
*/

SELECT prod_codigo, prod_detalle /*, sum(item_cantidad)*/ FROM 
/*Acá joineo los items con sus respectivas facturas*/
Item_factura JOIN Factura ON 
fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
/*Acá joineo lo anterior con el producto*/
JOIN Producto ON prod_codigo = item_producto
/*Dejo solo los items + factura + producto de 2012*/
WHERE year(fact_fecha) = 2012
/*agrupo los que corresponden al mismo producto*/
GROUP BY prod_codigo, prod_detalle
/*ordeno sumando la cantidad vendida de cada fila (función de grupo)*/
ORDER BY sum(item_cantidad)

/*
3. Realizar una consulta que muestre código de producto, nombre de producto y el stock
total, sin importar en que deposito se encuentre, los datos deben ser ordenados por
nombre del artículo de menor a mayor.

- Cada registro en STOCK es de un producto en un deposito particular
- necesito la tabla producto para tener el detalle
- necesito la tabla stock para tener el stock total

Haciendo
SELECT prod_codigo, prod_detalle FROM Producto JOIN stock ON prod_codigo = stoc_producto
Me va a traer repetidas veces el mismo producto según en la cantidad de depósitos que se 
encuentre. Además, NO VA A TRAER LOS PRODUCTOS QUE NO TIENEN STOCK
*/

SELECT prod_codigo, prod_detalle, sum(stoc_cantidad) 'Stock total'
FROM Producto 
JOIN stock ON prod_codigo = stoc_producto
GROUP BY prod_codigo, prod_detalle
ORDER BY prod_detalle

/*
4. Realizar una consulta que muestre para todos los artículos código, detalle 
y cantidad de artículos que lo componen. Mostrar solo aquellos artículos 
para los cuales el stock promedio por depósito sea mayor a 100.

Uso la subconsulta cuando si, el hecho de no usarla, me cambiase la atomicidad del query
- CONSULTA ESTÁTICA

LEFT JOIN porque tengo que traer los productos aunque no matcheen con una composicion
*/

SELECT prod_codigo, prod_detalle, count(comp_componente)
FROM Producto LEFT JOIN Composicion on prod_codigo = comp_producto
WHERE prod_codigo in 
(SELECT stoc_producto FROM stock GROUP BY stoc_producto HAVING avg(stoc_cantidad) > 100)
GROUP BY prod_codigo, prod_detalle
ORDER BY count(comp_componente) DESC

/*
5. Realizar una consulta que muestre código de artículo, detalle y cantidad de 
egresos de stock que se realizaron para ese artículo en el año 2012 
(egresan los productos que fueron vendidos). Mostrar solo aquellos que 
hayan tenido más egresos que en el 2011.

-- SUBCONSULTA DINÁMICA: no puedo hacerlo de otra forma, no puedo traer a la vez productos de 2011 y 2012
*/

select prod_codigo, prod_detalle, sum(item_cantidad) cant_egresos	
from Producto 
join Item_Factura on item_producto = prod_codigo
--al agregar la factura por la PK completa, nunca va a cambiar la atomicidad
--porque por cadad match, matchea una sola vez.
join Factura on fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
where year(fact_fecha) = 2012 
group by prod_codigo, prod_detalle
--agregar producto en el subquery multiplicaría x2000 las iteraciones :(
having sum(item_cantidad) > (select sum(item_cantidad)
							from Item_Factura 
							join Factura on fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
							--- como prod_codigo no está en el FROM (Producto), lo busca afuera
							where year(fact_fecha) = 2011 and item_producto = prod_codigo)

/*
6. Mostrar para todos los rubros de artículos: código, detalle, cantidad 
de artículos de ese rubro y stock total de ese rubro de artículos. 
Solo tener en cuenta aquellos artículos que tengan un stock mayor al del 
artículo ‘00000000’ en el depósito ‘00’.
*/
-- al tener un left, es relevante qué pongo en el count:
-- si hago count(*) y hay un rubro sin productos, va a devolver 1 por tener null pero cuenta la fila
-- si hago count(prod_codigo) va a devolver 0 si hay null en producto, es lo que quiero

--MAL: en el having, estaría sumando stock del rubro, me piden stock de los articulos
select rubr_id, rubr_detalle, count(distinct prod_codigo) cant_productos, sum(stoc_cantidad) stock_total
from Rubro
--por las dudas un left, por si hay rubros sin productos
left join Producto on prod_rubro = rubr_id
-- stoc_producto no es la PK, entonces sé que esto me cambia la atomicidad
left join STOCK on stoc_producto = prod_codigo
group by rubr_id, rubr_detalle
having sum(stoc_cantidad) > (select stoc_cantidad
								from STOCK
								where stoc_producto = '00000000' and stoc_deposito = '00')

--BIEN
select rubr_id, rubr_detalle, count(distinct prod_codigo) cant_productos, sum(stoc_cantidad) stock_total
from Rubro
--deja de tener sentido el left porque al igualar con stock por codigo de producto,
--si el producto es null me lo vuela al rubro, que es lo que queria intentar que no pasara con el left
join Producto on prod_rubro = rubr_id
--ahora, si trae nulls, igual no va a ser mayor que el stock del producto 00000000, no hace falta el left
join STOCK on stoc_producto = prod_codigo
--select estático
where stoc_producto in (select stoc_producto 
						from STOCK
						group by stoc_producto
						having sum(stoc_cantidad) > (select stoc_cantidad
													from STOCK
													where stoc_producto = '00000000' and stoc_deposito = '00'))
group by rubr_id, rubr_detalle

/*
7. Generar una consulta que muestre para cada artículo código, detalle, mayor 
precio menor precio y % de la diferencia de precios (respecto del menor Ej.: 
menor precio = 10, mayor precio =12 => mostrar 20 %). Mostrar solo aquellos 
artículos que posean stock.
*/

--MAL: no contemplo los stocks negativos, que quizá le prestaron a otro deposito etc, tendría que calcular la suma
select prod_codigo, prod_detalle, max(item_precio), min(item_precio), 
	max(item_precio) - min(item_precio) * 100 / min(item_precio)
from Producto 
join Item_Factura on item_producto = prod_codigo
--afecta la atomicidad pero no importa, el mínimo va a seguir siendo el mínimo, lo mismo con el máximo
join STOCK on stoc_producto = prod_codigo
where stoc_cantidad > 0
group by prod_codigo, prod_detalle

--BIEN - opción 1 - la más rápida

--for(2000) producto
-- for(20000) item
--  if()

select prod_codigo, prod_detalle, max(item_precio), min(item_precio), 
	(max(item_precio) - min(item_precio)) * 100 / min(item_precio)
from Producto 
join Item_Factura on item_producto = prod_codigo
where prod_codigo in (select stoc_producto
						from STOCK
						group by stoc_producto
						having sum(stoc_cantidad) > 0)
group by prod_codigo, prod_detalle

--BIEN - opción 2

--for(2000) producto
-- for(20000) item
--  for(5000) stock

select prod_codigo, prod_detalle, max(item_precio), min(item_precio), 
	max(item_precio) - min(item_precio) * 100 / min(item_precio)
from Producto 
join Item_Factura on item_producto = prod_codigo
join STOCK on stoc_producto = prod_codigo
group by prod_codigo, prod_detalle
having sum(stoc_cantidad) > 0

/*
8. Mostrar para el o los artículos que tengan stock en todos los depósitos, 
nombre del artículo, stock del depósito que más stock tiene.
*/

SELECT prod_detalle, max(stoc_cantidad)
FROM Producto JOIN STOCK on prod_codigo = stoc_producto
GROUP BY prod_detalle
-- Con esto TODO los productos y su mayor stock, yo quiero limitarlo
-- a los que tienen stock en todos los depositos
SELECT count(*) FROM deposito --cantidad de depositos que hay

SELECT prod_detalle, max(stoc_cantidad) mayor_stock
FROM Producto JOIN STOCK on prod_codigo = stoc_producto
WHERE stoc_cantidad > 0 
GROUP BY prod_detalle
HAVING count(*) = (SELECT count(*) FROM deposito)
-- no aparece ninguno porque ninguno está en todos

/*
9. Mostrar el código del jefe, código del empleado que lo tiene como jefe, 
nombre del mismo y la cantidad de depósitos que ambos tienen asignados.
*/

select empl_jefe, empl_codigo, rtrim(empl_nombre)+' '+rtrim(empl_apellido), 
	count(distinct d1.depo_codigo) depositos_empleado, count(distinct d2.depo_codigo) depositos_jefe
from Empleado
left join DEPOSITO d1 on empl_codigo = d1.depo_encargado
join DEPOSITO d2 on d2.depo_encargado = empl_jefe
group by empl_jefe, empl_codigo, rtrim(empl_nombre)+' '+rtrim(empl_apellido)

/*
10. Mostrar los 10 productos más vendidos en la historia y también los 10 
productos menos vendidos en la historia. Además mostrar de esos productos, 
quien fue el cliente que mayor compra realizo.

--no puedo usar union porque solo puedo tener un order by
*/	

select prod_detalle, (select top 1 fact_cliente
						from Factura
						join Item_Factura on item_numero+item_tipo+item_sucursal = fact_numero+fact_tipo+fact_sucursal
						where prod_codigo = item_producto
						group by fact_cliente
						order by sum(item_cantidad) DESC) mejor_cliente
from Producto
where prod_codigo in (select top 10 item_producto
						from Item_Factura
						group by item_producto
						order by sum(item_cantidad) DESC)
or prod_codigo in (select top 10 item_producto
					from Item_Factura 
					group by item_producto
					order by sum(item_cantidad) ASC)

/*
11. Realizar una consulta que retorne el detalle de la familia, la cantidad diferentes de
productos vendidos y el monto de dichas ventas sin impuestos. Los datos se deberán
ordenar de mayor a menor, por la familia que más productos diferentes vendidos tenga,
solo se deberán mostrar las familias que tengan una venta superior a 20000 pesos para
el año 2012.

- Si una familia no tiene productos, no se vendieron, entonces no tiene sentido un 
LEFT JOIN para que vengan todas las familias
- Uso el HAVING solo si filtro después de agrupar, entonces filtro por alguno de los 
campos que uso en el group by, no es nuestro caso.
- El where podría ser un having pero eso haría que agrupe resultados que después va a borrar
*/

SELECT fami_detalle, count(distinct item_producto), sum(item_precio*item_cantidad)
FROM Familia JOIN Producto on fami_id = prod_familia 
	JOIN Item_Factura on prod_codigo = item_producto
WHERE fami_id IN 
	(SELECT prod_familia 
	FROM Producto JOIN Item_Factura on prod_codigo = item_producto
	JOIN Factura on fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
	WHERE YEAR(fact_fecha) = 2012
	GROUP BY prod_familia
	HAVING sum(item_cantidad*item_precio) > 20000)
GROUP BY fami_id, fami_detalle
ORDER BY 2 DESC

/*
12. Mostrar nombre de producto, cantidad de clientes distintos que lo compraron, importe
promedio pagado por el producto, cantidad de depósitos en los cuales hay stock del
producto y stock actual del producto en todos los depósitos. Se deberán mostrar
aquellos productos que hayan tenido operaciones en el año 2012 y los datos deberán
ordenarse de mayor a menor por monto vendido del producto.

-- en vez de hacer 2 subconsultas para las últimas 2 columnas, puedo joiner con stock porque:
- el DISTINCT no se ve afectado con más filas
- el AVG tampoco, si tengo 1 2 3 y ahora tengo 1 1 2 2 3 3 es lo mismo

--no puedo calcular el sum normal porque no puedo filtrar el universo, tengo los depositos repetidas veces

-- si no agrupo afuera por prod_codigo, no puedo usarlo adentro, aparece este error:
Column 'Producto.prod_codigo' is invalid in the select list because it is not contained 
in either an aggregate function or the GROUP BY clause.

*/

-- esta estaba bien hasta que hubo que poner el order by, porque no itera por renglones, sino los renglones * stock
select prod_detalle, count(distinct fact_cliente) clientes, avg(item_precio) importe_promedio,
	count(distinct stoc_deposito) depositos, 
	(select SUM(stoc_cantidad) from STOCK where stoc_producto = prod_codigo) stock_total
from Producto
join Item_Factura on item_producto = prod_codigo
join Factura on fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
join STOCK on stoc_producto = prod_codigo
where stoc_cantidad > 0 and prod_codigo in 
	(select item_producto
	from Item_Factura
	join Factura on fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
	where year(fact_fecha) = 2012)
group by prod_codigo, prod_detalle
--order by sum(item_precio * item_cantidad) desc

--ademas esta es mucho más rápida
select prod_detalle, count(distinct fact_cliente) clientes, avg(item_precio) importe_promedio,
	(select count(*) from STOCK where stoc_cantidad > 0 and stoc_producto = prod_codigo) depositos, 
	(select SUM(stoc_cantidad) from STOCK where stoc_producto = prod_codigo) stock_total
from Producto
join Item_Factura on item_producto = prod_codigo
join Factura on fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
where prod_codigo in 
	(select item_producto
	from Item_Factura
	join Factura on fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
	where year(fact_fecha) = 2012)
group by prod_codigo, prod_detalle
order by sum(item_precio * item_cantidad) desc

/*13. Realizar una consulta que retorne para cada producto que posea composición nombre
del producto, precio del producto, precio de la sumatoria de los precios por la cantidad
de los productos que lo componen. Solo se deberán mostrar los productos que estén
compuestos por >= 2 productos y deben ser ordenados de mayor a menor por
cantidad de productos que lo componen.
*/

select p.prod_detalle, p.prod_precio, sum(comp_cantidad * pc.prod_precio) sumatoria_precios
from Composicion 
join Producto p on p.prod_codigo = comp_producto
join Producto pc on pc.prod_codigo = comp_componente
group by p.prod_detalle, p.prod_precio
having count(*) >= 2
order by count(*) desc

/*
14. Escriba una consulta que retorne una estadística de ventas por cliente. Los campos que
debe retornar son:
Código del cliente
Cantidad de veces que compro en el último año
Promedio por compra en el último año
Cantidad de productos diferentes que compro en el último año
Monto de la mayor compra que realizo en el último año
Se deberán retornar todos los clientes ordenados por la cantidad de veces que compro en
el último año.
No se deberán visualizar NULLs en ninguna columna
*/

--V1
select fact_cliente, count(distinct fact_tipo+fact_sucursal+fact_numero),
avg(fact_total), count(distinct item_producto), max(fact_total)
from Factura join Item_Factura on fact_tipo+fact_sucursal+fact_numero =
	item_tipo+item_sucursal+item_numero
--puedo filtrar porque todas las columnas son del ultimo año
where year(fact_fecha) = (select max(year(fact_fecha)) from Factura)
group by fact_cliente
order by 2

--V2
select f1.fact_cliente, count(distinct fact_tipo+fact_sucursal+fact_numero),
	(select avg(fact_total) 
	from Factura f2 
	where year(f2.fact_fecha) = year(f1.fact_fecha) and f2.fact_cliente = f1.fact_cliente), 
count(distinct item_producto), max(f1.fact_total)
from Factura f1 join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
--puedo filtrar porque todas las columnas son del ultimo año
where year(f1.fact_fecha) = (select max(year(fact_fecha)) from Factura)
group by fact_cliente, year(fact_fecha)
order by 2

--V3 (la mejor, itera menos veces)
select f1.fact_cliente,
	count(*) 'Veces que compró en el último año',
	avg(fact_total) 'Promedio por compra en el último año',
	(select count(distinct item_producto) from factura f2
	join item_factura on item_tipo+item_sucursal+item_numero = f2.fact_tipo+f2.fact_sucursal+f2.fact_numero
	where f1.fact_cliente = f2.fact_cliente) 'Productos diferente que compró el último año',
	max(fact_total) 'Monto de la mayor compra del último año'
from factura f1
where year(fact_fecha) = (select max(year(fact_fecha)) from factura)
group by fact_cliente
order by 2, fact_cliente

/* IMPORTANTE PARA EL PARCIAL
15. Escriba una consulta que retorne los pares de productos que hayan sido vendidos juntos
(en la misma factura) más de 500 veces. El resultado debe mostrar el código y
descripción de cada uno de los productos y la cantidad de veces que fueron vendidos
juntos. El resultado debe estar ordenado por la cantidad de veces que se vendieron
juntos dichos productos. Los distintos pares no deben retornarse más de una vez.

Ejemplo de lo que retornaría la consulta:
PROD1	DETALLE1			PROD2	DETALLE2			VECES
1731	MARLBORO KS			1718	PHILIPS MORRIS KS	507
1718	PHILIPS MORRIS KS	1705	PHILIPS MORRIS BOX	10562
*/
--si en el mismo renglon tengo que ver 2 productos necesito 2 iteraciones de la tabla

SELECT p1.prod_codigo, p1.prod_detalle, p2.prod_codigo, p2.prod_detalle, count(*)
from Item_Factura i1 join Producto p1 on p1.prod_codigo = i1.item_producto,
Item_Factura i2 join producto p2 on p2.prod_codigo = i2.item_producto 
where i1.item_tipo+i1.item_sucursal+i1.item_numero =
	i2.item_tipo+i2.item_sucursal+i2.item_numero and p1.prod_detalle < p2.prod_detalle
group by p1.prod_codigo, p1.prod_detalle, p2.prod_codigo, p2.prod_detalle
having count(*) > 500
order by 5

/*
16. Con el fin de lanzar una nueva campaña comercial para los clientes que menos compran
en la empresa, se pide una consulta SQL que retorne aquellos clientes cuyas compras
son inferiores a 1/3 del monto de ventas del producto que más se vendió en el 2012.
Además mostrar
1. Nombre del Cliente
2. Cantidad de unidades totales vendidas en el 2012 para ese cliente.
3. Código de producto que mayor venta tuvo en el 2012 (en caso de existir más de 1,
mostrar solamente el de menor código) para ese cliente.
*/

-- producto que más se vendió
select top 1 item_producto
from factura join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
where year(fact_fecha) = 2012
group by item_producto
order by sum(item_precio * item_cantidad)
--
-- monto de esas ventas
select sum(item_precio * item_cantidad) 
from factura join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
where year(fact_fecha) = 2012 and item_producto = 
	(select top 1 item_producto
	from factura join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
	where year(fact_fecha) = 2012
	group by item_producto
	order by sum(item_precio * item_cantidad) desc)
--
-- mi universo de clientes
select fact_cliente, sum(fact_total)
from factura
group by fact_cliente
having sum(fact_total) < 
	(select sum(item_precio * item_cantidad) / 3
	from factura join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
	where year(fact_fecha) = 2012 and item_producto = 
		(select top 1 item_producto
		from factura join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
		where year(fact_fecha) = 2012
		group by item_producto
		order by sum(item_precio * item_cantidad) desc))
--
--rta
--ahora cambió la atomicidad, no puedo sumar por fact_total, tengo que sumar renglones
-- los NULL son para los clientes que no compraron nada en el 2012
select fact_cliente, sum(item_cantidad), 
	(select top 1 item_producto
	from factura join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
	where year(fact_fecha) = 2012 and fact_cliente = f1.fact_cliente
	group by item_producto
	order by sum(item_precio * item_cantidad) desc, item_producto)
from factura f1 join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
group by fact_cliente
having sum(item_precio * item_cantidad) < 
	(select sum(item_precio * item_cantidad) / 3
	from factura join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
	where year(fact_fecha) = 2012 and item_producto = 
	--consulta estática
		(select top 1 item_producto
		from factura join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
		where year(fact_fecha) = 2012
		group by item_producto
		order by sum(item_cantidad) desc))
order by fact_cliente
	--

--mi rta 
select	clie_codigo,
		clie_razon_social,
		sum(item_cantidad),
		-- producto que mas venta tuvo para el cliente
		(select top 1 item_producto
			from Item_Factura
			join Factura on item_numero+item_tipo+item_sucursal = fact_numero+fact_tipo+fact_sucursal
			where fact_cliente = c.clie_codigo and year(fact_fecha) = 2012
			group by item_producto
			order by sum(item_cantidad * item_precio) desc)
from cliente c
join Factura on fact_cliente = clie_codigo
join Item_Factura on item_numero+item_tipo+item_sucursal = fact_numero+fact_tipo+fact_sucursal
where year(fact_fecha) = 2012
group by clie_codigo, clie_razon_social
having sum(item_cantidad * item_precio) < 0.3 * 
	-- monto de ventas del producto mas vendido en 2012
	(select top 1 sum(item_cantidad*item_precio)
	from Item_Factura
	join Factura on item_numero+item_tipo+item_sucursal = fact_numero+fact_tipo+fact_sucursal
	where year(fact_fecha) = 2012
	group by item_producto
	order by sum(item_cantidad*item_precio) desc)
order by clie_codigo

/*
17. Escriba una consulta que retorne una estadística de ventas por año y mes para cada
producto.
La consulta debe retornar:
PERIODO: Año y mes de la estadística con el formato YYYYMM
PROD: Código de producto
DETALLE: Detalle del producto
CANTIDAD_VENDIDA= Cantidad vendida del producto en el periodo
VENTAS_AÑO_ANT= Cantidad vendida del producto en el mismo mes del periodo
pero del año anterior
CANT_FACTURAS= Cantidad de facturas en las que se vendió el producto en el
periodo
La consulta no puede mostrar NULL en ninguna de sus columnas y debe estar ordenada
por periodo y código de producto.
*/

SELECT 
	rtrim(year(f1.fact_fecha))+RIGHT('0' + RTRIM(MONTH(f1.fact_fecha)), 2) 'Periodo',
	prod_codigo 'Codigo',
	prod_detalle 'Producto',
	SUM(item_cantidad) 'Cantidad vendida',
	(SELECT SUM(item_cantidad) 
	FROM Item_Factura
	JOIN Factura F2 ON item_numero + item_sucursal + item_tipo =
	F2.fact_numero + F2.fact_sucursal + F2.fact_tipo  
	WHERE item_producto = prod_codigo 
	AND YEAR(F2.fact_fecha) = YEAR(F1.fact_fecha) - 1
	AND MONTH(F2.fact_fecha) = MONTH(F1.fact_fecha)) 'Cantidad vendida anterior',
	count(distinct fact_tipo+fact_sucursal+fact_numero) 'Cantidad de facturas'
FROM Producto
JOIN Item_Factura ON prod_codigo = item_producto
JOIN Factura F1 ON item_numero + item_sucursal + item_tipo =
fact_numero + fact_sucursal + fact_tipo
GROUP BY YEAR(F1.fact_fecha), MONTH(F1.fact_fecha), prod_codigo, prod_detalle
ORDER BY 1,2

/*
18. Escriba una consulta que retorne una estadística de ventas para todos los rubros.
La consulta debe retornar:
DETALLE_RUBRO: Detalle del rubro
VENTAS: Suma de las ventas en pesos de productos vendidos de dicho rubro
PROD1: Código del producto más vendido de dicho rubro
PROD2: Código del segundo producto más vendido de dicho rubro
CLIENTE: Código del cliente que compro más productos del rubro en los últimos 30
días
La consulta no puede mostrar NULL en ninguna de sus col
*/

select	rubr_detalle 'DETALLE_RUBRO',
		isnull(sum(item_cantidad * item_precio),0) 'VENTAS',
		isnull((select top 1 item_producto
			from Item_Factura
			join Producto on prod_codigo = item_producto
			where prod_rubro = r1.rubr_id
			group by item_producto
			order by sum(item_cantidad) desc), '-') 'PROD1',
		isnull((select top 1 item_producto
			from Item_Factura
			join Producto on prod_codigo = item_producto
			where prod_rubro = r1.rubr_id
			group by item_producto
			order by sum(item_cantidad) asc), '-') 'PROD2',
		isnull((select top 1 fact_cliente
		from Factura
		join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
		join Producto on item_producto = prod_codigo
		--agarro la ultima fecha facturada
		where fact_fecha > (SELECT DATEADD(DAY, -30, MAX(fact_fecha)) FROM Factura)
		and prod_rubro = r1.rubr_id
		group by fact_cliente
		order by COUNT(*)),'-') 'CLIENTE'
from Rubro r1
left join Producto on prod_rubro = rubr_id
left join Item_Factura on item_producto = prod_codigo
group by rubr_detalle, rubr_id

/*
19. En virtud de una recategorizacion de productos referida a la familia de los mismos se
solicita que desarrolle una consulta sql que retorne para todos los productos:
 Codigo de producto
 Detalle del producto
 Codigo de la familia del producto
 Detalle de la familia actual del producto
 Codigo de la familia sugerido para el producto
 Detalla de la familia sugerido para el producto
La familia sugerida para un producto es la que poseen la mayoria de los productos cuyo
detalle coinciden en los primeros 5 caracteres.
En caso que 2 o mas familias pudieran ser sugeridas se debera seleccionar la de menor
codigo. Solo se deben mostrar los productos para los cuales la familia actual sea
diferente a la sugerida
Los resultados deben ser ordenados por detalle de producto de manera ascendente
*/
--acá entendimos mal el enunciado y pensamos que la familia era la que directamente el
--detalle era parecido al del producto
select prod_codigo, prod_detalle, prod_familia, fami_detalle, 
	(select top 1 fami_id 
	from Familia 
	where prod_familia <> fami_id and left(fami_detalle, 5)=LEFT(prod_detalle, 5)
	group by fami_id
	--ante igualdad de suma, que ordene en forma ascendente por id
	order by count(*) desc, fami_id),
	(select top 1 fami_detalle
	from Familia 
	where prod_familia <> fami_id and left(fami_detalle, 5)=LEFT(prod_detalle, 5)
	group by fami_detalle
	order by count(*) desc, fami_detalle)
from producto join familia on prod_familia = fami_id
order by prod_codigo

--rehecho
select p1.prod_codigo, p1.prod_detalle, p1.prod_familia, fami_detalle, 
	(select top 1 p2.prod_familia 
	from Producto p2 
	where p1.prod_familia <> p2.prod_familia 
	and left(p1.prod_detalle, 5)=LEFT(p2.prod_detalle, 5)
	group by p2.prod_familia
	order by count(*) desc, p2.prod_familia) nuevo_fami_id,
	(select top 1 fami_detalle
	from Producto p2 join familia on p2.prod_familia = fami_id
	where p1.prod_familia <> p2.prod_familia 
	and left(p1.prod_detalle, 5)=LEFT(p2.prod_detalle, 5)
	group by fami_detalle, p2.prod_familia
	order by count(*) desc, p2.prod_familia) nuevo_fami_detalle
from producto p1 join familia on p1.prod_familia = fami_id
order by p1.prod_detalle

--yo lo entendi distinto, muestro solo las filas con familias nuevas
select	prod_codigo,
		prod_detalle,
		fami_id,
		fami_detalle,
		(select top 1 prod_familia
		from Producto
		where left(prod_detalle,5) like left(p1.prod_detalle, 5)
		group by prod_familia
		order by  count(*) desc, prod_familia) 'codigo familia sugerida',
		(select top 1 fami_detalle
		from Producto
		join Familia on prod_familia = fami_id
		where left(prod_detalle,5) like left(p1.prod_detalle, 5)
		group by fami_detalle, prod_familia
		order by  count(*) desc) 'detalle familia sugerida'
from Producto p1
join Familia on prod_familia = fami_id
where fami_id <> (select top 1 prod_familia
					from Producto
					where left(prod_detalle,5) like left(p1.prod_detalle, 5)
					group by prod_familia
					order by  count(*) desc, prod_familia)
order by prod_detalle

/*
20. Escriba una consulta sql que retorne un ranking de los mejores 3 empleados del 2012
Se debera retornar legajo, nombre y apellido, anio de ingreso, puntaje 2011, puntaje
2012. El puntaje de cada empleado se calculara de la siguiente manera: para los que
hayan vendido al menos 50 facturas el puntaje se calculara como la cantidad de facturas
que superen los 100 pesos que haya vendido en el año, para los que tengan menos de 50
facturas en el año el calculo del puntaje sera el 50% de cantidad de facturas realizadas
por sus subordinados directos en dicho año.
*/

select top 3	empl_codigo,
				rtrim(empl_nombre)+' '+rtrim(empl_apellido) 'Nombre y apellido',
				year(empl_ingreso),
				 (select case 
					when COUNT(f.fact_numero + f.fact_sucursal + f.fact_tipo) >= 50 
						then (select count(*) from factura f1 
								where f1.fact_vendedor = e.empl_codigo AND year(F1.fact_fecha) = 2011 and f1.fact_total > 100 )
					ELSE (select count(*)/2 from factura f2 
							where f2.fact_vendedor in (select e1.empl_codigo from empleado e1 
														where e1.empl_jefe = e.empl_codigo) 
							and year(F2.fact_fecha) = 2011 )
				 end
				 from Factura f 
				 where f.fact_vendedor = e.empl_codigo AND year(F.fact_fecha) = 2011) 'Puntaje 2011',
				 (select case 
					when COUNT(f.fact_numero + f.fact_sucursal + f.fact_tipo) < 50 
						then (select count(*) from factura f1 
								where f1.fact_vendedor = e.empl_codigo AND year(F1.fact_fecha) = 2012 and f1.fact_total > 100 )
					ELSE (select count(*)/2 from factura f2 
							where f2.fact_vendedor in (select e1.empl_codigo from empleado e1 
														where e1.empl_jefe = e.empl_codigo) 
							and year(F2.fact_fecha) = 2012)
				 end
				 from Factura f 
				 where f.fact_vendedor = e.empl_codigo AND year(F.fact_fecha) = 2012) 'Puntaje 2012'
from Empleado e
order by 5 desc, 4 desc

-- versión profe
select top 3	empl_codigo,
				rtrim(empl_nombre)+' '+rtrim(empl_apellido) 'Nombre y apellido',
				year(empl_ingreso),
				 case 
					when (select COUNT(*) from factura where fact_vendedor = e.empl_codigo) >= 50 
						then (select count(*) from factura f1 
								where f1.fact_vendedor = e.empl_codigo AND year(F1.fact_fecha) = 2011 and f1.fact_total > 100 )
					ELSE (select count(*)/2 from factura f2 join empleado e2 on e2.empl_codigo = f2.fact_vendedor
							where e2.empl_jefe = e.empl_codigo and year(F2.fact_fecha) = 2011)
				 end 'Puntaje 2011',
				 case 
					when (select COUNT(*) from factura where fact_vendedor = e.empl_codigo) < 50 
						then (select count(*) from factura f1 
								where f1.fact_vendedor = e.empl_codigo AND year(F1.fact_fecha) = 2012 and f1.fact_total > 100 )
					ELSE (select count(*)/2 from factura f2 join empleado e2 on e2.empl_codigo = f2.fact_vendedor
							where e2.empl_jefe = e.empl_codigo and year(F2.fact_fecha) = 2012)
				 end 'Puntaje 2012'
from Empleado e
order by 5 desc, 4 desc

/*
21. Escriba una consulta sql que retorne para todos los años, en los cuales se haya hecho al
menos una factura, la cantidad de clientes a los que se les facturo de manera incorrecta
al menos una factura y que cantidad de facturas se realizaron de manera incorrecta. Se
considera que una factura es incorrecta cuando la diferencia entre el total de la factura
menos el total de impuesto tiene una diferencia mayor a $ 1 respecto a la sumatoria de
los costos de cada uno de los items de dicha factura. Las columnas que se deben mostrar
son:
 Año
 Clientes a los que se les facturo mal en ese año
 Facturas mal realizadas en ese año
*/

-- facturas que están mal
select *
from Factura
where abs(fact_total - fact_total_impuestos - (select sum(item_precio * item_cantidad)
												from Item_Factura
												where fact_tipo+fact_sucursal+fact_numero 
												= item_tipo+item_sucursal+item_numero)) > 1
--

select	year(fact_fecha) 'anio',
		count(distinct fact_cliente) 'cantidad de clientes',
		count(*) 'cantidad de facturas'
from Factura
where abs(fact_total - fact_total_impuestos - (select sum(item_precio * item_cantidad)
												from Item_Factura
												where fact_tipo+fact_sucursal+fact_numero 
												= item_tipo+item_sucursal+item_numero)) > 1
group by year(fact_fecha)

/*
22. Escriba una consulta sql que retorne una estadistica de venta para todos los rubros por
trimestre contabilizando todos los años. Se mostraran como maximo 4 filas por rubro (1
por cada trimestre).
Se deben mostrar 4 columnas:
 Detalle del rubro
 Numero de trimestre del año (1 a 4)
 Cantidad de facturas emitidas en el trimestre en las que se haya vendido al
menos un producto del rubro
 Cantidad de productos diferentes del rubro vendidos en el trimestre

El resultado debe ser ordenado alfabeticamente por el detalle del rubro y dentro de cada
rubro primero el trimestre en el que mas facturas se emitieron.
No se deberan mostrar aquellos rubros y trimestres para los cuales las facturas emitiadas
no superen las 100.
En ningun momento se tendran en cuenta los productos compuestos para esta estadistica.
*/

select rubr_detalle,
	datepart(quarter, fact_fecha) 'Trimestre',
	count(distinct fact_numero+fact_sucursal+fact_tipo) 'Facturas en las que se vendió al menos un producto del rubro',
	count(distinct prod_codigo) 'Productos diferentes vendidos'
from rubro
-- habia 2 left join pero la condicion del having te los mata
	join producto on prod_rubro = rubr_id
	join item_factura on item_producto = prod_codigo
	join factura on fact_numero+fact_sucursal+fact_tipo = item_numero+item_sucursal+item_tipo
group by rubr_detalle, datepart(quarter, fact_fecha)
having count(distinct fact_numero+fact_sucursal+fact_tipo) > 100
order by rubr_detalle, 3 desc

/*
23. Realizar una consulta SQL que para cada año muestre :
 Año
	 El producto con composición más vendido para ese año.
	 Cantidad de productos que componen directamente al producto más vendido
	 La cantidad de facturas en las cuales aparece ese producto.
	 El código de cliente que más compro ese producto.
	 El porcentaje que representa la venta de ese producto respecto al total de venta del año.
El resultado deberá ser ordenado por el total vendido por año en forma descendente
*/

select	year(fact_fecha) 'anio',
		item_producto 'producto mas vendido',
		(select count(comp_componente) from Composicion 
		where comp_producto = i.item_producto) 'cantidad de componentes',
		count(distinct fact_tipo + fact_sucursal + fact_numero) 'cantidad facturas',
		(select top 1 fact_cliente from Factura
		join Item_Factura on fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
		where item_producto = i.item_producto and year(fact_fecha) = year(f.fact_fecha)
		group by fact_cliente
		order by sum(item_cantidad) desc) 'mejor cliente',
		sum(item_cantidad * item_precio) / (select sum(item_cantidad * item_precio) 
											from Factura join Item_Factura on 
											fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
											where year(fact_fecha) = year(f.fact_fecha))*100 'porcentaje ventas'
from Factura f
join Item_Factura i on fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
where item_producto = 
	(select top 1 item_producto from Item_Factura
	join Factura on fact_tipo + fact_sucursal + fact_numero = item_tipo + item_sucursal + item_numero
	where year(fact_fecha) = year(f.fact_fecha) and item_producto in 
		(select distinct comp_producto from Composicion)	
	group by item_producto
	order by sum(item_cantidad * item_precio) desc)
group by year(fact_fecha), item_producto
order by sum(item_cantidad * item_precio) desc

/*
24. Escriba una consulta que considerando solamente las facturas correspondientes a los
dos vendedores con mayores comisiones, retorne los productos con composición
facturados al menos en cinco facturas,
La consulta debe retornar las siguientes columnas:
 Código de Producto
 Nombre del Producto
 Unidades facturadas
El resultado deberá ser ordenado por las unidades facturadas descendente.
*/

--vendedores con mayores comisiones
select top 2 empl_codigo from Empleado
order by empl_comision desc
--

select	prod_codigo,
		prod_detalle,
		sum(item_cantidad) 'unidades facturadas'
from Producto
join Item_Factura on item_producto = prod_codigo
join Factura on fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
where prod_codigo in 
	(select comp_producto from Composicion) 
and fact_vendedor in 
	(select top 2 empl_codigo from Empleado
	order by empl_comision desc)
group by prod_codigo, prod_detalle
having count(distinct fact_tipo+fact_sucursal+fact_numero) >= 5
order by 3 desc


/*
25. Realizar una consulta SQL que para cada año y familia muestre :
	a. Año
	b. El código de la familia más vendida en ese año.
	c. Cantidad de Rubros que componen esa familia.
	d. Cantidad de productos que componen directamente al producto más vendido de esa familia.
	e. La cantidad de facturas en las cuales aparecen productos pertenecientes a esa familia.
	f. El código de cliente que más compro productos de esa familia.
	g. El porcentaje que representa la venta de esa familia respecto al total de venta del año.
El resultado deberá ser ordenado por el total vendido por año y familia en forma
descendente
*/

select	year(fact_fecha) 'año',
		prod_familia 'familia',
		count(distinct prod_rubro) 'cant rubros',
		(select count(comp_componente) from Composicion
		join Producto on comp_producto = prod_codigo
		where prod_codigo = 
			(select top 1 prod_codigo
			from Item_Factura 
			join Producto on prod_codigo = item_producto
			where prod_familia = p.prod_familia
			group by prod_codigo
			order by sum(item_cantidad) desc)) 'cant componentes producto más vendido',
		count(distinct fact_tipo+fact_sucursal+fact_numero) 'cant facturas',
		(select top 1 fact_cliente
			from Factura
			join Item_Factura on fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
			join Producto on item_producto = prod_codigo
			where prod_familia = p.prod_familia and year(fact_fecha) = year(f.fact_fecha)
			group by fact_cliente
			order by sum(item_cantidad) desc) 'mejor cliente',
		sum(item_precio*item_cantidad) / 
		(select sum(item_precio*item_cantidad) from Item_Factura 
		join Factura on item_numero+item_sucursal+item_tipo = fact_numero+fact_sucursal+fact_tipo
		 where year(fact_fecha) = year(f.fact_fecha)) * 100 'porcentaje ventas del año'
from Factura f
join Item_Factura on fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
join Producto p on item_producto = prod_codigo
where prod_familia = 
	(select top 1 prod_familia
	from Producto
	join Item_Factura on item_producto = prod_codigo
	join Factura on fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
	where year(fact_fecha) = year(f.fact_fecha)
	group by prod_familia
	order by sum(item_cantidad) desc)
group by year(fact_fecha), prod_familia
order by sum(item_precio*item_cantidad) desc, prod_familia desc

--familia mas vendida del año
select top 1 prod_familia
from Producto
join Item_Factura on item_producto = prod_codigo
join Factura f2 on fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
where year(fact_fecha) = xxx
group by prod_familia
order by sum(item_cantidad) desc

--producto mas vendido de esa familia
select top 1 prod_codigo
from Item_Factura 
join Producto on prod_codigo = item_producto
where prod_familia = xxx
group by prod_codigo
order by sum(item_cantidad) desc

--cliente que más compro de esa familia en ese año
select top 1 fact_cliente
from Factura
join Item_Factura on fact_tipo+fact_sucursal+fact_numero=item_tipo+item_sucursal+item_numero
join Producto on item_producto = prod_codigo
where prod_familia = xxx and year(fact_fecha) = yyy
group by fact_cliente
order by sum(item_cantidad) desc


/*
26. Escriba una consulta sql que retorne un ranking de empleados devolviendo las
siguientes columnas:
 Empleado
 Depósitos que tiene a cargo
 Monto total facturado en el año corriente
 Codigo de Cliente al que mas le vendió
 Producto más vendido
 Porcentaje de la venta de ese empleado sobre el total vendido ese año.
Los datos deberan ser ordenados por venta del empleado de mayor a menor.
*/

select f1.fact_vendedor,
     (select count(*) from deposito where depo_encargado = f1.fact_vendedor),
     sum(fact_total),
     (select top 1 fact_cliente from factura where fact_vendedor = f1.fact_vendedor 
        group by fact_cliente order by sum(fact_total) desc),
    (select top 1 item_producto from factura join item_factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
        where fact_vendedor = f1.fact_vendedor 
        group by item_producto order by sum(item_cantidad) desc),
    sum(fact_total) / (select sum(fact_total) from factura where year(fact_fecha) = year(f1.fact_fecha))
from factura f1
where year(f1.fact_fecha) = 2012 -- hacer lo de max año de las facturas
group by fact_vendedor, year(fact_fecha)

/*
27. Escriba una consulta sql que retorne una estadística basada en la facturacion por año y
envase devolviendo las siguientes columnas:
 Año
 Codigo de envase
 Detalle del envase
 Cantidad de productos que tienen ese envase
 Cantidad de productos facturados de ese envase
 Producto mas vendido de ese envase
 Monto total de venta de ese envase en ese año
 Porcentaje de la venta de ese envase respecto al total vendido de ese año
Los datos deberan ser ordenados por año y dentro del año por el envase con más
facturación de mayor a menor
*/

select	year(fact_fecha) 'anio', 
		enva_codigo, 
		enva_detalle, 
		(select count(*)
		from Producto
		where prod_envase = enva_codigo) 'productos con ese envase',
		count(distinct prod_codigo) 'cantidad de productos facturados',
		(select top 1 item_producto
		from Item_Factura join Producto on item_producto = prod_codigo
		where prod_envase = enva_codigo
		group by item_producto
		order by count(*) desc) 'producto mas vendido',
		sum(item_precio * item_cantidad) 'monto total',
		sum(item_precio * item_cantidad)/(select sum(fact_total-fact_total_impuestos) from Factura
											where YEAR(fact_fecha) = year(f1.fact_fecha)) 'porcentaje de venta'
from Factura f1
join Item_Factura on f1.fact_tipo+f1.fact_sucursal+f1.fact_numero = item_tipo+item_sucursal+item_numero
join Producto on prod_codigo = item_producto
join Envases on prod_envase = enva_codigo
group by year(fact_fecha), enva_codigo, enva_detalle
order by year(fact_fecha), sum(item_precio * item_cantidad) desc

/*
28. Escriba una consulta sql que retorne una estadística por Año y Vendedor que retorne las
siguientes columnas:
	 Año.
	 Codigo de Vendedor
	 Detalle del Vendedor
	 Cantidad de facturas que realizó en ese año
	 Cantidad de clientes a los cuales les vendió en ese año.
	 Cantidad de productos facturados con composición en ese año
	 Cantidad de productos facturados sin composicion en ese año.
	 Monto total vendido por ese vendedor en ese año
Los datos deberan ser ordenados por año y dentro del año por el vendedor que haya
vendido mas productos diferentes de mayor a menor.
*/

select	year(fact_fecha) 'anio',
		empl_codigo,
		rtrim(empl_nombre)+' '+rtrim(empl_apellido) 'empl_detalle',
		count(distinct fact_tipo+fact_sucursal+fact_numero) 'facturas',
		count(distinct fact_cliente) 'clientes distintos',
		(select count(item_producto) from factura
		join Item_Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
		where f.fact_vendedor = fact_vendedor and year(fact_fecha) = year(f.fact_fecha)
		and item_producto in (select distinct comp_producto from Composicion)) 'productos con composicion',
		(select count(item_producto) from factura
		join Item_Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
		where f.fact_vendedor = fact_vendedor and year(fact_fecha) = year(f.fact_fecha)
		and item_producto not in (select distinct comp_producto from Composicion)) 'productos sin composicion',
		sum(item_cantidad*item_precio) 'monto total'
from Factura f
join Empleado on fact_vendedor = empl_codigo
join Item_Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
group by year(fact_fecha), empl_codigo, empl_nombre, empl_apellido, fact_vendedor
order by year(fact_fecha), count(distinct item_producto) desc

/*
29. Se solicita que realice una estadística de venta por producto para el año 2011, solo para
los productos que pertenezcan a las familias que tengan más de 20 productos asignados
	a ellas, la cual deberá devolver las siguientes columnas:
	a. Código de producto
	b. Descripción del producto
	c. Cantidad vendida
	d. Cantidad de facturas en la que esta ese producto
	e. Monto total facturado de ese producto
Solo se deberá mostrar un producto por fila en función a los considerandos establecidos
antes. El resultado deberá ser ordenado por el la cantidad vendida de mayor a menor.
*/


/*
30. Se desea obtener una estadistica de ventas del año 2012, para los empleados que sean
jefes, o sea, que tengan empleados a su cargo, para ello se requiere que realice la
consulta que retorne las siguientes columnas:
 Nombre del Jefe
 Cantidad de empleados a cargo
 Monto total vendido de los empleados a cargo
 Cantidad de facturas realizadas por los empleados a cargo
 Nombre del empleado con mejor ventas de ese jefe
Debido a la perfomance requerida, solo se permite el uso de una subconsulta si fuese
necesario.
Los datos deberan ser ordenados por de mayor a menor por el Total vendido y solo se
deben mostrarse los jefes cuyos subordinados hayan realizado más de 10 facturas.
*/

/*
31. Escriba una consulta sql que retorne una estadística por Año y Vendedor que retorne las
siguientes columnas:
 Año.
 Codigo de Vendedor
 Detalle del Vendedor
 Cantidad de facturas que realizó en ese año
 Cantidad de clientes a los cuales les vendió en ese año.
 Cantidad de productos facturados con composición en ese año
 Cantidad de productos facturados sin composicion en ese año.
 Monto total vendido por ese vendedor en ese año
Los datos deberan ser ordenados por año y dentro del año por el vendedor que haya
vendido mas productos diferentes de mayor a menor.
*/


/*
32. Se desea conocer las familias que sus productos se facturaron juntos en las mismas
facturas para ello se solicita que escriba una consulta sql que retorne los pares de
familias que tienen productos que se facturaron juntos. Para ellos deberá devolver las
siguientes columnas:
 Código de familia
 Detalle de familia
 Código de familia
 Detalle de familia
 Cantidad de facturas
 Total vendido
Los datos deberan ser ordenados por Total vendido y solo se deben mostrar las familias
que se vendieron juntas más de 10 veces.
*/


/*
33. Se requiere obtener una estadística de venta de productos que sean componentes. Para
ello se solicita que realiza la siguiente consulta que retorne la venta de los
componentes del producto más vendido del año 2012. Se deberá mostrar:
a. Código de producto
b. Nombre del producto
c. Cantidad de unidades vendidas
d. Cantidad de facturas en la cual se facturo
e. Precio promedio facturado de ese producto.
f. Total facturado para ese producto
El resultado deberá ser ordenado por el total vendido por producto para el año 2012.
*/

/*
34. Escriba una consulta sql que retorne para todos los rubros la cantidad de facturas mal
facturadas por cada mes del año 2011 Se considera que una factura es incorrecta cuando
en la misma factura se factutan productos de dos rubros diferentes. Si no hay facturas
mal hechas se debe retornar 0. Las columnas que se deben mostrar son:
1- Codigo de Rubro
2- Mes
3- Cantidad de facturas mal realizadas
*/

--lo entendimos mal, muestra solo si hubo facturas mal facturadas en vez de todos los meses
select	rubr_id, 
		month(fact_fecha)	'Mes', 
		count(*)			'Facturas mal realizadas'
from Factura
join Item_Factura on  fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
join Producto on item_producto = prod_codigo
join Rubro on rubr_id = prod_rubro
where year(fact_fecha) = 2011 and fact_tipo+fact_sucursal+fact_numero in 
	(select item_tipo+item_sucursal+item_numero
		from Item_Factura
		join Producto on item_producto = prod_codigo
		group by item_tipo+item_sucursal+item_numero
		having count(distinct prod_rubro) > 1)
group by rubr_id, month(fact_fecha)
order by month(fact_fecha)

--rehecho
select prod_rubro, month(fact_fecha), 
    (select count(distinct fact_tipo+fact_sucursal+fact_numero) from factura join item_factura
        on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
         join producto on prod_codigo = item_producto
    where month(f1.fact_fecha) = month(fact_fecha) and
        fact_tipo+fact_sucursal+fact_numero in 
        (select item_tipo+item_sucursal+item_numero from item_factura join producto on prod_codigo = item_producto
         group by item_tipo+item_sucursal+item_numero
         having count(distinct prod_rubro) > 1))
from  factura f1 join item_factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
join producto on prod_codigo = item_producto join rubro on rubr_id = prod_rubro
where year(fact_fecha) = 2011
group by prod_rubro, month(fact_fecha)
order by 3

/*
35. Se requiere realizar una estadística de ventas por año y producto, para ello se solicita
que escriba una consulta sql que retorne las siguientes columnas:
 Año
 Codigo de producto
 Detalle del producto
 Cantidad de facturas emitidas a ese producto ese año
 Cantidad de clientes diferentes que compraron ese producto ese año.
 Cantidad de productos a los cuales compone ese producto, si no compone a ninguno
se debera retornar 0.
 Porcentaje de la venta de ese producto respecto a la venta total de ese año.
Los datos deberan ser ordenados por año y por producto con mayor cantidad vendida.
*/

select	year(fact_fecha) 'anio',
		prod_codigo,
		prod_detalle,
		count(distinct fact_tipo+fact_sucursal+fact_numero) 'cant facturas',
		count(distinct fact_cliente) 'cant clientes distintos',
		(select count(comp_producto) from Composicion where comp_componente = p.prod_codigo) 'cant productos que compone',
		sum(item_cantidad * item_precio) / (select sum(item_cantidad*item_precio) from factura join 
											Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
											where year(fact_fecha) = year(f.fact_fecha)) * 100 'porcentaje ventas'
from Factura f
join Item_Factura on fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero
join Producto p on item_producto = prod_codigo
group by year(fact_fecha), prod_codigo, prod_detalle
order by year(fact_fecha), sum(item_cantidad * item_precio) desc

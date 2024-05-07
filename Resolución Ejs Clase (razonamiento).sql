-- EJERCICIO 2 (CLASE)
/* Mostrar el c�digo, detalle de todos los art�culos vendidos en el a�o 2012 ordenados por
	cantidad vendida */

SELECT prod_codigo, prod_detalle 
FROM Producto JOIN Item_Factura ON prod_codigo = item_producto --19500 filas, por qu�? 
ORDER BY item_cantidad

select count(*) from Item_Factura --19500 filas. Concluyo que solo matchean una vez, pues prod_codigo es PK. Ya s� que hay productos repetidos.

SELECT * --Este es todo mi universo, independientemente de lo que decida mostrar.
FROM Producto JOIN Item_Factura ON prod_codigo = item_producto --19500 filas, por qu�? 
	JOIN Factura ON fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero 
	--Establezco el vinculo a partir de la FK. Aquellos campos que tienen en comun.
	--La cantidad de filas no cambio, pues la PK est� vinculado con una �nica fila. Cambi� el universo.
WHERE year(fact_fecha) = 2012
GROUP BY prod_codigo, prod_detalle --A igualdad de producto, los junta. Ahora tengo 630 filas. No hay prodcutos repetidos.


SELECT prod_codigo, prod_detalle, sum(item_cantidad) --si quiero mostrar las cantidades vendidas de un producto.
FROM Producto JOIN Item_Factura ON prod_codigo = item_producto
	JOIN Factura ON fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero 
WHERE year(fact_fecha) = 2012
GROUP BY prod_codigo, prod_detalle


SELECT prod_codigo, prod_detalle
FROM Producto JOIN Item_Factura ON prod_codigo = item_producto
	JOIN Factura ON fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero 
WHERE year(fact_fecha) = 2012
GROUP BY prod_codigo, prod_detalle
ORDER BY sum(item_cantidad) --puedo ordenar por criterios que no est�n en el SELECT


SELECT prod_codigo, prod_detalle, sum(item_cantidad) --si quiero mostrar las cantidades vendidas de un producto y ordenarlas por ellas.
FROM Producto JOIN Item_Factura ON prod_codigo = item_producto
	JOIN Factura ON fact_tipo+fact_sucursal+fact_numero = item_tipo+item_sucursal+item_numero 
WHERE year(fact_fecha) = 2012
GROUP BY prod_codigo, prod_detalle
ORDER BY 3

--EJERCICIO 3
/* Realizar una consulta que muestre c�digo de producto, nombre de producto y el stock
	total, sin importar en que deposito se encuentre, los datos deben ser ordenados por
	nombre del art�culo de menor a mayor. */

select prod_codigo, prod_detalle, sum(stoc_cantidad)
from Producto join STOCK ON prod_codigo = stoc_producto --aumenta a 6500 filas, el producto se puede repetir.
GROUP BY prod_codigo, prod_detalle --los productos que no tienen stock no los recibo. Disminuye las filas a 1400. 
-- Deber�an aparecer igualmente indistitanmente. Entonces tiene sentido un LEFT. PENSAR LO QUE PODR�A NECESITAR EL CLIENTE.

select prod_codigo, prod_detalle, sum(stoc_cantidad)
from Producto left join STOCK ON prod_codigo = stoc_producto --Tengo 2200 filas. Una para cada producto.
GROUP BY prod_codigo, prod_detalle
order by prod_detalle

-- EJERCICIO 4 -> entender qu� pasa con el producto cartesiano, entre tablas.
/* Realizar una consulta [que muestre para todos los art�culos c�digo, detalle] y [cantidad de art�culos
	que lo componen]. Mostrar solo aquellos art�culos para los cuales el stock promedio por dep�sito
	sea mayor a 100.
*/

select prod_codigo, prod_detalle from producto --DEFINO MI UNIVERSO. Arts. c�digo y detalle.

--[1]
select prod_codigo, prod_detalle from producto join Composicion on prod_codigo = comp_producto
--Si un producto est� compuesto por n art�culos, aparece n veces. Reemplazo el join para asegurar que, desde
-- la izquierda, vengan todos los productos.

select prod_codigo, prod_detalle from producto left join Composicion on prod_codigo = comp_producto --HAY 6 FILAS REPETIDAS

select prod_codigo, prod_detalle from producto left join Composicion on prod_codigo = comp_producto
group by prod_codigo, prod_detalle
-- Al agrupar, los productos repetidos los junt�.

--[2]
select prod_codigo, prod_detalle, count(*) from producto left join Composicion on prod_codigo = comp_producto
group by prod_codigo, prod_detalle
order by count(*) DESC
-- Hay productos que no tienen componentes, y aparecen como si tuviera uno. Eso sucede porque el motor cuenta 
-- la fila ("Count(*)"), no la cantidad de componentes.

select prod_codigo, prod_detalle, count(comp_componente) from producto left join Composicion on prod_codigo = comp_producto
group by prod_codigo, prod_detalle
order by count(comp_componente) DESC

select prod_codigo, prod_detalle, count(comp_componente) from producto left join Composicion on prod_codigo = comp_producto
join STOCK on prod_codigo = stoc_detalle --Meter el stock ac� me va a cambiar la cantidad de filas. Debo hacer la l�gica en otra parte.
group by prod_codigo, prod_detalle
having avg(stoc_cantidad) > 100
order by count(comp_componente) DESC --Ahora me multiplic� la cantidad de componentes, qu� pas�?

/* No es gratis joinear tablas, pues me cambia el universo.
	Ac� matche� cada producto con cada dep�sito en el que estaba, multiplicando las iteraciones del mismo producto.

	Para evitar esto debo joinear por la PK completa, �...
*/

select prod_codigo, prod_detalle, count(comp_componente) from producto left join Composicion on prod_codigo = comp_producto
where prod_codigo in (select stoc_producto from STOCK 
						group by stoc_producto 
						having avg(stoc_cantidad) > 100)
group by prod_codigo, prod_detalle
order by count(comp_componente) DESC

-- Utilizo la subconsulta como si fuese una funci�n que me retorna los stocks que cumplen con la condici�n.
-- Normalmente se utiliza cuando no quiero que una condici�n modifique mi universo.
--Consultas est�ticas -> independientemente de la iteraci�n externa, el resultado del subselect no se modifica. Lo calcula una vez.
--							lo que no tiene, lo busca afuera.

select prod_codigo, prod_detalle, count(comp_componente) from producto left join Composicion on prod_codigo = comp_producto
where exists (select stoc_producto from STOCK 
						where prod_codigo = stoc_producto
						group by stoc_producto 
						having avg(stoc_cantidad) > 100)
group by prod_codigo, prod_detalle
order by count(comp_componente) DESC
-- No lo puede ejecutar, pues prod_codigo no existe en el universo que le marqu�.
--Consulta din�mica -> Para cada fila de afuera que cambie, recalcula el subselect. No podemos ejecutarlo en solitario.
-- Utilizo el EXISTS cuando hay posibilidad de que lo que est� adentro retorne NULL.

-- Consulta eset�tica > Consulta din�mica.

--EJERCICIO 5
/* Realizar una consulta que muestre [c�digo de art�culo, detalle] y cantidad de egresos de stock que se realizaron
	para ese art�uclo en el a�o 2012 (egresan los productos que fueron vendidos). Mostrar solo aquellos que hayan
	tenido m�s egresos que en el 2011. */

select prod_codigo, prod_detalle from Producto

select prod_codigo, prod_detalle, ISNULL(sum(item_cantidad),0) as Egresos from Producto
join item_factura on prod_codigo = item_producto
join Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
where year(fact_fecha) = 2012
group by prod_codigo, prod_detalle
order by sum(item_cantidad)

-- La l�gica de validar que haya tenido m�s egresos que en el 2011 debo hacerlo en otro lado, y me conviene que sea
-- despu�s de haber agrupado.

select prod_codigo, prod_detalle, ISNULL(sum(item_cantidad),0) as Egresos from Producto
join item_factura on prod_codigo = item_producto
join Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
where year(fact_fecha) = 2012
group by prod_codigo, prod_detalle
having sum(item_cantidad) > (select ISNULL(sum(item_cantidad),0) from Item_Factura
							join Factura on item_tipo+item_sucursal+item_numero = fact_tipo+fact_sucursal+fact_numero
							where year(fact_fecha) = 2011 and prod_codigo = item_producto)
order by sum(item_cantidad)

-- EJERCICIO 6
/* Mostrar para todos los rubros de art�culos c�digo, detalle, cantidad de art�culos de ese rubro y stock total de
	ese rubro de art�culos. Solo tener en cuenta aquellos art�culos que tengan un stock mayor al del art�culo '00000000'
	en el dep�sito '00' */

--Arranco por el universo: d�nde est� lo que me piden que muestre?
select rubr_id, rubr_detalle from Rubro --31 filas

select rubr_id, rubr_detalle from Rubro
join Producto on prod_rubro = rubr_id --2190 filas, pues trae todos los productos

select rubr_id, rubr_detalle, count(*) from Rubro
left join Producto on prod_rubro = rubr_id --deber�a ser left, pues quiero que priorice los rubros
group by rubr_id, rubr_detalle

select rubr_id, rubr_detalle, count(*) from Rubro
left join Producto on prod_rubro = rubr_id
join STOCK on prod_codigo = stoc_producto --la PK est� incompleta -> mi universo cambi� -> si un producto est�
									-- en tres dep�sitos distintos, matchea 3 veces; y si hay productos sin stock,
									-- no los trae. Debo agregar el stock en otra parte.
group by rubr_id, rubr_detalle
order by count(*) desc
 

select rubr_id, rubr_detalle, count(distinct prod_codigo) from Rubro
left join Producto on prod_rubro = rubr_id
join STOCK on prod_codigo = stoc_producto
group by rubr_id, rubr_detalle
order by count(distinct prod_codigo) desc

/*Puedo salvar la atomicidad cuando cuento, no cuando sumo. Otra forma equivalente, manteniedno el count(*) ser�a:*/

select rubr_id, rubr_detalle, count(*), 
(select sum(stoc_cantidad) from STOCK join Producto on stoc_producto = prod_codigo where prod_rubro = rubr_id)
from Rubro left join Producto on prod_rubro = rubr_id
group by rubr_id, rubr_detalle
order by count(*) desc

--Que el subselect sea la �ltima opci�n.

--El ejercicio me pide tomar solo los productos que cumplan con una condici�n, por tanto la opci�n del count(prod_codigo)
-- queda invalidada. 

select rubr_id, rubr_detalle, count(*), 
(select sum(stoc_cantidad) from STOCK join Producto on stoc_producto = prod_codigo where prod_rubro = rubr_id)
from Rubro left join Producto on prod_rubro = rubr_id
group by rubr_id, rubr_detalle
order by count(*) desc

--EJERCICIO 7
/* Generar una consulta que muestre para cada art�culo c�digo, detalle, mayor precio
menor precio y % de la diferencia de precios (respecto del menor Ej.: menor precio =
10, mayor precio =12 => mostrar 20 %). Mostrar solo aquellos art�culos que posean
stock. */

select prod_codigo, prod_detalle, min(prod_precio) MenorPrecio, max(prod_precio) MayorPrecio, 100*(max(prod_precio) - min(prod_precio))/min(prod_precio) DiferenciaPrecios
from Producto join Item_Factura on item_producto = prod_codigo
where (select stoc_cantidad from STOCK
			group by stoc_cantidad		
			having sum(stoc_cantidad)>0)
group by prod_codigo, prod_detalle

--Surgen complicaciones en las relaciones uno a muchos. Si joineo por la PK, salgo del problema. 

--EJERCICIO 8
/* Mostrar para el o los art�culos que tengan stock en todos los dep�sitos, nombre del
art�culo, stock del dep�sito que m�s stock tiene. */
--Utilizar la atomicidad delas tablas a favor nuestra

select prod_detalle, max(stoc_cantidad)
from Producto join STOCK on stoc_producto = prod_codigo --retorna un producto como tantas veces tenga stock en un dep�sito
group by prod_detalle

--C�mo s� que est� en todos los dep�sitos? La cantidad de veces que mostr� un producto en stock debe ser igual a la cantidad de dep�sitos.
select prod_detalle, max(stoc_cantidad)
from Producto join STOCK on stoc_producto = prod_codigo
where stoc_cantidad > 0
group by prod_detalle
having count(*) = (select count(*) from DEPOSITO)

--EJERCICIO 9
/* Mostrar el c�digo del jefe, c�digo del empleado que lo tiene como jefe, nombre del
mismo y la cantidad de dep�sitos que ambos tienen asignados. */

-- UNIVERSOS
select count(empl_codigo) from Empleado --9 empleados
select count(depo_encargado) from DEPOSITO --33 asignaciones

--HASTA AC�, MUESTRO LA CANTIDAD DE DEPOSITOS POR CADA EMPLEADO.
select empl_jefe, empl_codigo, empl_nombre, count(depo_encargado) DepositosAsignados
from Empleado left join DEPOSITO on empl_codigo = depo_encargado --SIN EL LEFT JOIN, LA CONSULTA RETORNA SOLO AQUELLOS CON UN DEPOSITO ASIGNADO.
group by empl_jefe, empl_codigo, empl_nombre						-- YO QUIERO MOSTRAR TODO EL UNIVERSO DE LOS EMPLEADOS.

-------------
select empl_jefe, empl_codigo, empl_nombre, count(depo_encargado) DepositosAsignadosEmpleadoMasJefe
from Empleado left join DEPOSITO on empl_codigo = depo_encargado or empl_jefe = depo_encargado	--PUEDO PONER CONDICIONES COMBINADAS PARA QUE ME TRAIGA AMBOS CASOS. 
group by empl_jefe, empl_codigo, empl_nombre													--SUPONE LA REPETICI�N DE FILAS.
order by empl_jefe

--EJERCICIO 10
/* Mostrar los 10 productos m�s vendidos en la historia y tambi�n los 10 productos menos
vendidos en la historia. Adem�s mostrar de esos productos, quien fue el cliente que
mayor compra realizo. */

--EL UNIVERSO FINAL NO QUEDA ORDENADO 

select top 10 prod_detalle	--top 10 mayores
from Producto join Item_Factura on prod_codigo = item_producto 
group by prod_detalle
order by sum(item_cantidad) desc

select top 10 prod_detalle	--top 10 menores
from Producto join Item_Factura on prod_codigo = item_producto 
group by prod_detalle
order by sum(item_cantidad) asc

select top 10 (select prod_detalle, sum(item_cantidad) UnidadesVendidas from Producto left join Item_Factura on prod_codigo = item_producto group by prod_detalle, sum(item_cantidad) order by sum(item_cantidad) asc), 
	(select prod_detalle from Producto left join Item_Factura on prod_codigo = item_producto order by item_cantidad desc)-- fact_cliente
from Producto join Factura on
--separo los producos m�s vendidos y menos vendidos del total. Una vez defino eso, comparo con el universo total.

select top 10 item_producto from Item_Factura group by item_producto order by sum(item_cantidad)

select prod_codigo, (select top 1 fact_cliente from Factura join Item_Factura on item_producto = prod_codigo group by cliente order by  ) 
from Producto 
where prod_codigo in (select top 10 item_producto 
							from Item_Factura 
							group by item_producto 
							order by sum(item_cantidad) asc) 


/* ENCONTRAR RESOLUCI�N */

--EJERCICIO 11
/* Realizar una consulta que retorne el detalle de la familia, la cantidad diferentes de
productos vendidos y el monto de dichas ventas sin impuestos. Los datos se deber�n
ordenar de mayor a menor, por la familia que m�s productos diferentes vendidos tenga,
solo se deber�n mostrar las familias que tengan una venta superior a 20000 pesos para
el a�o 2012. */

--cantidad productos perteneciente a la familia
select count(prod_codigo), fami_id 
from Producto join Familia on prod_familia = fami_id 
group by fami_id

--cantidad productos perteneciente a la familia que se vendieron
select count(prod_codigo), fami_id 
from Producto join Familia on prod_familia = fami_id join Item_Factura on prod_codigo = item_producto
group by fami_id

select fami_detalle, (select count(prod_codigo) from Producto 
from Familia join Producto on prod_familia = fami_id

---------------------------
select fami_detalle, count(distinct prod_codigo), sum(item_cantidad * item_precio) MontoVentas --en la factura figuran los montos sin impuestos.
from Familia join Producto on prod_familia = fami_id join Item_Factura on prod_codigo = item_producto
where fami_id in 
group by fami_detalle
order by 2 desc

/* Cuando usamos un valor como v�nculo con otro universo (ej. en Where), el motor va a demandar que lo agregue en el GROUP BY*/

select prod_familia
from Producto join  join
where year(fact_fecha) = 2012
group by prod_familia
having sum(item_cantidad * item_precio) > 20000